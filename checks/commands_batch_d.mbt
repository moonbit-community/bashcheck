///|
fn append_commands_batch_d_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for
    description in [
      {
        code: 2028,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "echo may not expand escape sequences. Use printf.",
      },
      {
        code: 2155,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Declare and assign separately to avoid masking return values.",
      },
      {
        code: 2172,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Prefer trap signal names over non-portable signal numbers.",
      },
      {
        code: 2173,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "SIGKILL and SIGSTOP can not be trapped.",
      },
    ] {
    descriptions.push(description)
  }
}

///|
fn run_commands_batch_d_checks(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_echo_escape_sequences(script, diagnostics)
  check_masked_declaration_returns(script, diagnostics)
  check_trap_signal_literals(script, diagnostics)
}

///|
fn check_echo_escape_sequences(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_basename(command, "echo") else { return }
    let arguments = @semantics.effective_command_arguments(command)
    guard !echo_flags_enable_escape_expansion(arguments) else { return }
    for argument in arguments {
      if echo_argument_has_escape_sequence(argument) {
        push_diagnostic(
          diagnostics,
          argument.span,
          CheckSeverity::Info,
          2028,
          "echo may not expand escape sequences. Use printf.",
        )
      }
    }
  })
}

///|
fn echo_flags_enable_escape_expansion(arguments : Array[@parser.Word]) -> Bool {
  for argument in arguments {
    match @semantics.literal_text(argument) {
      Some(text) if text == "--" => return false
      Some(text) if echo_flag_cluster_enables_escape_expansion(text) =>
        return true
      Some(text) if echo_flag_cluster_is_portable(text) => ()
      _ => return false
    }
  }
  false
}

///|
fn echo_flag_cluster_is_portable(text : String) -> Bool {
  if !text.has_prefix("-") || text == "-" || text.has_prefix("--") {
    return false
  }
  let view = text[:]
  let mut i = 1
  while i < view.length() {
    match view[i].unsafe_to_char() {
      'n' | 'e' | 'E' => ()
      _ => return false
    }
    i += 1
  }
  true
}

///|
fn echo_flag_cluster_enables_escape_expansion(text : String) -> Bool {
  if !echo_flag_cluster_is_portable(text) {
    return false
  }
  let view = text[:]
  let mut i = 1
  while i < view.length() {
    if view[i].unsafe_to_char() == 'e' {
      return true
    }
    i += 1
  }
  false
}

///|
fn echo_argument_has_escape_sequence(word : @parser.Word) -> Bool {
  for part in word.parts {
    if echo_word_part_has_escape_sequence(part, false) {
      return true
    }
  }
  false
}

///|
fn echo_word_part_has_escape_sequence(
  part : @parser.WordPart,
  quoted : Bool,
) -> Bool {
  match part {
    @parser.WordPart::SingleQuoted(text)
    | @parser.WordPart::DollarSingleQuoted(text) => text.contains("\\")
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) => {
      for nested in parts {
        if echo_word_part_has_escape_sequence(nested, true) {
          return true
        }
      }
      false
    }
    @parser.WordPart::Literal(text) if quoted =>
      double_quoted_literal_has_escape_sequence(text)
    _ => false
  }
}

///|
fn double_quoted_literal_has_escape_sequence(text : String) -> Bool {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    if view[i] != '\\' {
      i += 1
      continue
    }
    if i + 1 >= view.length() {
      return true
    }
    match view[i + 1].unsafe_to_char() {
      '$' | '"' | '`' => ()
      _ => return true
    }
    i += 2
  }
  false
}

///|
fn check_masked_declaration_returns(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    let command_name = match @semantics.effective_command_name(command) {
      Some(name) => name
      None => return
    }
    if !masked_return_declaration_names().contains(command_name) {
      return
    }
    for element in declaration_elements_in_command(command) {
      match element {
        DeclarationCommandElement::Assignment(assignment) =>
          if assignment_masks_return_value(assignment) {
            push_diagnostic(
              diagnostics,
              assignment_name_span(assignment),
              CheckSeverity::Warning,
              2155,
              "Declare and assign separately to avoid masking return values.",
            )
          }
        _ => ()
      }
    }
  })
}

///|
fn masked_return_declaration_names() -> Array[String] {
  ["declare", "export", "local", "readonly", "typeset"]
}

///|
fn assignment_masks_return_value(assignment : @parser.Assignment) -> Bool {
  for index in assignment.indexes {
    if array_index_has_command_substitution(index) {
      return true
    }
  }
  assignment_value_has_masked_return(assignment.value)
}

///|
fn assignment_value_has_masked_return(value : @parser.AssignmentValue) -> Bool {
  match value {
    @parser.AssignmentValue::Empty => false
    @parser.AssignmentValue::Word(word) =>
      word_has_command_substitution_deep(word)
    @parser.AssignmentValue::ArrayLiteral(elements) => {
      for element in elements {
        for index in element.indexes {
          if array_index_has_command_substitution(index) {
            return true
          }
        }
        if assignment_value_has_masked_return(element.value) {
          return true
        }
      }
      false
    }
  }
}

///|
fn array_index_has_command_substitution(index : @parser.ArrayIndex) -> Bool {
  let mut found = false
  walk_word_parts_deep(index.parts, fn(part) {
    if found {
      return
    }
    match part {
      @parser.WordPart::CommandSubstitution(script)
      | @parser.WordPart::BraceCommandSubstitution(_, script)
      | @parser.WordPart::BackQuoted(script) =>
        if script.items.length() > 0 {
          found = true
        }
      _ => ()
    }
  })
  found
}

///|
fn word_has_command_substitution_deep(word : @parser.Word) -> Bool {
  let mut found = false
  walk_word_deep(word, fn(part) {
    if found {
      return
    }
    match part {
      @parser.WordPart::CommandSubstitution(script)
      | @parser.WordPart::BraceCommandSubstitution(_, script)
      | @parser.WordPart::BackQuoted(script) =>
        if script.items.length() > 0 {
          found = true
        }
      _ => ()
    }
  })
  found
}

///|
fn check_trap_signal_literals(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_exact_name(command, "trap") else { return }
    let arguments = @semantics.effective_command_arguments(command)
    let signal_start = match trap_signal_start_index(arguments) {
      Some(index) => index
      None => return
    }
    let mut i = signal_start
    while i < arguments.length() {
      match @semantics.literal_text(arguments[i]) {
        Some(text) if trap_signal_is_untrappable(text) =>
          push_diagnostic(
            diagnostics,
            arguments[i].span,
            CheckSeverity::Error,
            2173,
            "SIGKILL/SIGSTOP can not be trapped.",
          )
        Some(text) if trap_signal_is_nonportable_number(text) =>
          push_diagnostic(
            diagnostics,
            arguments[i].span,
            CheckSeverity::Warning,
            2172,
            "Trapping signals by number is not well defined. Prefer signal names.",
          )
        _ => ()
      }
      i += 1
    }
  })
}

///|
fn trap_signal_start_index(arguments : Array[@parser.Word]) -> Int? {
  guard arguments.length() > 1 else { return None }
  match @semantics.literal_text(arguments[0]) {
    Some("-") | Some("--") | Some("-l") | Some("-p") => None
    _ => Some(1)
  }
}

///|
fn trap_signal_is_untrappable(text : String) -> Bool {
  ["9", "KILL", "SIGKILL", "STOP", "SIGSTOP"].contains(text)
}

///|
fn trap_signal_is_nonportable_number(text : String) -> Bool {
  guard trap_signal_number(text) is Some(number) else { return false }
  !portable_trap_signal_numbers().contains(number)
}

///|
fn portable_trap_signal_numbers() -> Array[Int] {
  [0, 1, 2, 3, 6, 9, 14, 15]
}

///|
fn trap_signal_number(text : String) -> Int? {
  let view = text[:]
  guard view.length() > 0 else { return None }
  let mut value = 0
  for ch in view {
    let char_ = ch
    guard '0' <= char_ && char_ <= '9' else { return None }
    value = value * 10 + (char_.to_int() - '0'.to_int())
  }
  Some(value)
}
