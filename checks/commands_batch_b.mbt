///|
fn append_commands_batch_b_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for
    description in [
      {
        code: 2139,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Alias values expand when defined, not when used.",
      },
      {
        code: 2142,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "Aliases can't use positional parameters.",
      },
      {
        code: 2213,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "getopts options should be handled by the matching case.",
      },
      {
        code: 2214,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "This case pattern is not specified by getopts.",
      },
      {
        code: 2219,
        severity: CheckSeverity::Style,
        category: "commands",
        summary: "Prefer (( expr )) over let expr.",
      },
      {
        code: 2220,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Handle invalid getopts flags with a *) case.",
      },
      {
        code: 2224,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "mv expects both source and destination.",
      },
      {
        code: 2225,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "cp expects both source and destination.",
      },
      {
        code: 2226,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "ln expects both source and destination.",
      },
      {
        code: 2253,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Use chmod -R to recurse, not -r.",
      },
      {
        code: 2267,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "GNU xargs -i is deprecated in favor of -I{}.",
      },
      {
        code: 2290,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "Remove spaces around = or += when assigning.",
      },
      {
        code: 2293,
        severity: CheckSeverity::Style,
        category: "commands",
        summary: "Use * rather than @ for eval with @Q-quoted arrays.",
      },
      {
        code: 2294,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "eval negates the benefit of arrays.",
      },
    ] {
    descriptions.push(description)
  }
}

///|
fn check_aliases_use_args(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_exact_name(command, "alias") {
      return
    }
    for argument in @semantics.effective_command_arguments(command) {
      guard alias_argument_is_definition(argument) else { continue }
      match @semantics.literal_text(argument) {
        Some(text) if alias_text_uses_positional_parameter(text) =>
          push_diagnostic(
            diagnostics,
            argument.span,
            CheckSeverity::Error,
            2142,
            "Aliases can't use positional parameters. Use a function.",
          )
        _ => ()
      }
    }
  })
}

///|
fn alias_argument_is_definition(argument : @parser.Word) -> Bool {
  match @semantics.leading_unquoted_text(argument) {
    Some(text) => text.contains("=")
    None =>
      match @semantics.literal_text(argument) {
        Some(text) => text.contains("=")
        None => false
      }
  }
}

///|
fn alias_text_uses_positional_parameter(text : String) -> Bool {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    if view[i] != '$' {
      i += 1
      continue
    }
    if i + 1 >= view.length() {
      return false
    }
    if view[i + 1] == '{' {
      if i + 2 < view.length() && alias_positional_parameter_char(view[i + 2]) {
        return true
      }
      i += 2
      continue
    }
    if alias_positional_parameter_char(view[i + 1]) {
      return true
    }
    i += 1
  }
  false
}

///|
fn alias_positional_parameter_char(ch : UInt16) -> Bool {
  let char_ = ch.unsafe_to_char()
  ('0' <= char_ && char_ <= '9') || char_ == '@' || char_ == '*'
}

///|
fn check_aliases_expand_early(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_exact_name(command, "alias") {
      return
    }
    for argument in @semantics.effective_command_arguments(command) {
      if alias_argument_is_definition(argument) &&
        !@semantics.is_constant_word(argument) {
        push_diagnostic(
          diagnostics,
          argument.span,
          CheckSeverity::Warning,
          2139,
          "This expands when defined, not when used. Consider escaping.",
        )
      }
    }
  })
}

///|
fn check_while_getopts_case(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::While(clause) =>
        maybe_check_while_getopts_clause(clause, diagnostics)
      _ => ()
    }
  })
}

///|
fn maybe_check_while_getopts_clause(
  clause : @parser.LoopClause,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let getopts_command = match first_getopts_command(clause.condition) {
    Some(command) => command
    None => return
  }
  let arguments = @semantics.effective_command_arguments(getopts_command)
  guard arguments.length() >= 2 else { return }
  let option_text = match @semantics.literal_text(arguments[0]) {
    Some(text) => text
    None => return
  }
  let variable_name = match @semantics.literal_text(arguments[1]) {
    Some(text) if is_identifier_name(text) => text
    _ => return
  }
  guard !script_assigns_name(clause.body, variable_name) else { return }
  let case_command = match
    find_getopts_case_command(clause.body, variable_name) {
    Some(command) => command
    None => return
  }
  let case_clause = match case_command.kind {
    @parser.CommandKind::Case(clause) => clause
    _ => return
  }
  let requested = getopts_requested_options(option_text)
  let handled : Array[String] = []
  let mut has_invalid_fallback = false
  let mut has_unanalyzable_pattern = false
  for item in case_clause.items {
    for pattern in item.patterns {
      match getopts_pattern_kind(pattern) {
        GetoptsPatternKind::Exact(text) =>
          if !handled.contains(text) {
            handled.push(text)
          }
        GetoptsPatternKind::Wildcard | GetoptsPatternKind::Question =>
          has_invalid_fallback = true
        GetoptsPatternKind::DigitClass | GetoptsPatternKind::Other =>
          has_unanalyzable_pattern = true
        GetoptsPatternKind::Colon => ()
      }
    }
  }
  if has_unanalyzable_pattern {
    return
  }
  for option in requested {
    if handled.contains(option) {
      continue
    }
    push_diagnostic(
      diagnostics,
      case_command.span,
      CheckSeverity::Warning,
      2213,
      "getopts specified -\{option}, but it's not handled by this 'case'.",
    )
  }
  for item in case_clause.items {
    for pattern in item.patterns {
      match getopts_pattern_kind(pattern) {
        GetoptsPatternKind::Exact(text) if !requested.contains(text) =>
          push_diagnostic(
            diagnostics,
            pattern.span,
            CheckSeverity::Warning,
            2214,
            "This case is not specified by getopts.",
          )
        _ => ()
      }
    }
  }
  if !has_invalid_fallback {
    push_diagnostic(
      diagnostics,
      case_command.span,
      CheckSeverity::Warning,
      2220,
      "Invalid flags are not handled. Add a *) case.",
    )
  }
}

///|
priv enum GetoptsPatternKind {
  Exact(String)
  Wildcard
  Question
  Colon
  DigitClass
  Other
}

///|
fn first_getopts_command(script : @parser.Script) -> @parser.Command? {
  let mut found : @parser.Command? = None
  visit_script_commands(script, fn(command) {
    if found is None && command_matches_exact_name(command, "getopts") {
      found = Some(command)
    }
  })
  found
}

///|
fn script_assigns_name(script : @parser.Script, name : String) -> Bool {
  let mut assigned = false
  visit_script_commands(script, fn(command) {
    if assigned {
      return
    }
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        if simple.assignments.any(fn(assignment) { assignment.name == name }) {
          assigned = true
        }
      _ => ()
    }
  })
  assigned
}

///|
fn find_getopts_case_command(
  script : @parser.Script,
  variable_name : String,
) -> @parser.Command? {
  let mut found : @parser.Command? = None
  visit_script_commands(script, fn(command) {
    if found is Some(_) {
      return
    }
    match command.kind {
      @parser.CommandKind::Case(clause) =>
        if read_expansion_target_name(clause.word) == Some(variable_name) {
          found = Some(command)
        }
      _ => ()
    }
  })
  found
}

///|
fn getopts_requested_options(text : String) -> Array[String] {
  let options : Array[String] = []
  for ch in text[:] {
    if ch == ':' {
      continue
    }
    let option = "\{ch}"
    if !options.contains(option) {
      options.push(option)
    }
  }
  options
}

///|
fn getopts_pattern_kind(pattern : @parser.Word) -> GetoptsPatternKind {
  if pattern.source == "*" {
    return GetoptsPatternKind::Wildcard
  }
  if pattern.source == "?" || pattern.source == "\\?" {
    return GetoptsPatternKind::Question
  }
  if pattern.source == "[0-9]" {
    return GetoptsPatternKind::DigitClass
  }
  match @semantics.literal_text(pattern) {
    Some("*") => GetoptsPatternKind::Wildcard
    Some("?") => GetoptsPatternKind::Question
    Some(":") => GetoptsPatternKind::Colon
    Some(text) if text[:].length() == 1 => GetoptsPatternKind::Exact(text)
    _ => GetoptsPatternKind::Other
  }
}

///|
fn check_let_usage(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell_is_one_of(shell, [
    @semantics.ShellDialect::Bash,
    @semantics.ShellDialect::Ksh,
  ]) else {
    return
  }
  visit_script_commands(script, fn(command) {
    if command_matches_exact_name(command, "let") {
      push_diagnostic(
        diagnostics,
        effective_command_span(command),
        CheckSeverity::Style,
        2219,
        "Instead of 'let expr', prefer (( expr )) .",
      )
    }
  })
}

///|
fn check_mv_arguments(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_missing_destination_command(
    script,
    diagnostics,
    "mv",
    2224,
    CheckSeverity::Error,
    "This mv has no destination. Check the arguments.",
  )
}

///|
fn check_cp_arguments(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_missing_destination_command(
    script,
    diagnostics,
    "cp",
    2225,
    CheckSeverity::Error,
    "This cp has no destination. Check the arguments.",
  )
}

///|
fn check_ln_arguments(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_missing_destination_command(
    script,
    diagnostics,
    "ln",
    2226,
    CheckSeverity::Warning,
    "This ln has no destination. Check the arguments, or specify '.' explicitly.",
  )
}

///|
fn check_missing_destination_command(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
  command_name : String,
  code : Int,
  severity : CheckSeverity,
  message : String,
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, command_name) {
      return
    }
    let (has_target_directory, positionals) = destination_command_arguments(
      command_name,
      @semantics.effective_command_arguments(command),
    )
    if has_target_directory || positionals.length() != 1 {
      return
    }
    if !word_may_expand_to_multiple(positionals[0]) {
      push_diagnostic(
        diagnostics,
        effective_command_span(command),
        severity,
        code,
        message,
      )
    }
  })
}

///|
fn destination_command_arguments(
  command_name : String,
  arguments : Array[@parser.Word],
) -> (Bool, Array[@parser.Word]) {
  let positionals : Array[@parser.Word] = []
  let mut has_target_directory = false
  let mut i = 0
  while i < arguments.length() {
    let text = match @semantics.literal_text(arguments[i]) {
      Some(text) => text
      None => {
        positionals.push(arguments[i])
        i += 1
        continue
      }
    }
    if text == "--" {
      i += 1
      while i < arguments.length() {
        positionals.push(arguments[i])
        i += 1
      }
      break
    }
    if !text.has_prefix("-") || text == "-" {
      positionals.push(arguments[i])
      i += 1
      continue
    }
    if text.has_prefix("--") {
      let (option_name, has_inline_value) = long_option_name(text)
      if destination_command_is_target_directory_option(option_name) {
        has_target_directory = true
      }
      if destination_command_long_option_takes_argument(
          command_name, option_name,
        ) &&
        !has_inline_value &&
        i + 1 < arguments.length() {
        i += 2
      } else {
        i += 1
      }
      continue
    }
    let (takes_value, has_attached_value, saw_target_directory) = destination_short_option_state(
      command_name, text,
    )
    if saw_target_directory {
      has_target_directory = true
    }
    if takes_value && !has_attached_value && i + 1 < arguments.length() {
      i += 2
    } else {
      i += 1
    }
  }
  (has_target_directory, positionals)
}

///|
fn long_option_name(text : String) -> (String, Bool) {
  let view = text[:]
  let mut i = 2
  while i < view.length() {
    if view[i] == '=' {
      return (text.view(start_offset=2, end_offset=i).to_string(), true)
    }
    i += 1
  }
  (text.view(start_offset=2).to_string(), false)
}

///|
fn destination_command_is_target_directory_option(option_name : String) -> Bool {
  option_name != "" && "target-directory".has_prefix(option_name)
}

///|
fn destination_command_long_option_takes_argument(
  command_name : String,
  option_name : String,
) -> Bool {
  if destination_command_is_target_directory_option(option_name) {
    return true
  }
  if option_name != "" && "suffix".has_prefix(option_name) {
    return true
  }
  if command_name == "cp" &&
    option_name != "" &&
    "context".has_prefix(option_name) {
    return true
  }
  false
}

///|
fn destination_short_option_state(
  command_name : String,
  text : String,
) -> (Bool, Bool, Bool) {
  let view = text[:]
  let mut j = 1
  let mut takes_value = false
  let mut has_attached_value = false
  let mut saw_target_directory = false
  while j < view.length() {
    let flag = view[j]
    if flag == 't' {
      saw_target_directory = true
    }
    if destination_command_short_option_takes_argument(command_name, flag) {
      takes_value = true
      has_attached_value = j + 1 < view.length()
      break
    }
    j += 1
  }
  (takes_value, has_attached_value, saw_target_directory)
}

///|
fn destination_command_short_option_takes_argument(
  command_name : String,
  flag : UInt16,
) -> Bool {
  if flag == 't' || flag == 'S' {
    return true
  }
  command_name == "cp" && flag == 'Z'
}

///|
fn check_chmod_dash_r(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "chmod") {
      return
    }
    for argument in @semantics.effective_command_arguments(command) {
      if @semantics.literal_text(argument) == Some("-r") {
        push_diagnostic(
          diagnostics,
          argument.span,
          CheckSeverity::Warning,
          2253,
          "Use -R to recurse, or explicitly a-r to remove read permissions.",
        )
      }
    }
  })
}

///|
fn check_xargs_dash_i(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "xargs") {
      return
    }
    match xargs_dash_i_word(@semantics.effective_command_arguments(command)) {
      Some(argument) =>
        push_diagnostic(
          diagnostics,
          argument.span,
          CheckSeverity::Info,
          2267,
          "GNU xargs -i is deprecated in favor of -I{}",
        )
      None => ()
    }
  })
}

///|
fn xargs_dash_i_word(arguments : Array[@parser.Word]) -> @parser.Word? {
  let mut i = 0
  while i < arguments.length() {
    let text = match @semantics.literal_text(arguments[i]) {
      Some(text) => text
      None => return None
    }
    if text == "--" {
      return None
    }
    if !text.has_prefix("-") || text == "-" {
      return None
    }
    if text.has_prefix("--") {
      if xargs_long_option_takes_argument(text) &&
        !text.contains("=") &&
        i + 1 < arguments.length() {
        i += 2
      } else {
        i += 1
      }
      continue
    }
    let view = text[:]
    let mut j = 1
    while j < view.length() {
      let flag = view[j]
      if flag == 'i' {
        return Some(arguments[i])
      }
      if xargs_short_option_takes_argument(flag) {
        if j + 1 < view.length() {
          break
        }
        if i + 1 < arguments.length() {
          i += 1
        }
        break
      }
      j += 1
    }
    i += 1
  }
  None
}

///|
fn xargs_short_option_takes_argument(flag : UInt16) -> Bool {
  match flag {
    'R' | 'S' | 'J' | 'L' | 'l' | 'n' | 'P' | 's' | 'e' | 'E' | 'i' | 'I' =>
      true
    _ => false
  }
}

///|
fn xargs_long_option_takes_argument(text : String) -> Bool {
  let (name, _) = long_option_name(text)
  [
    "eof", "eof-string", "replace", "max-lines", "max-args", "max-procs", "max-chars",
    "delimiter", "arg-file",
  ].any(fn(option) { option == name })
}

///|
fn check_argument_comparison_spacing(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    let command_name = match @semantics.effective_command_name(command) {
      Some(name) => name
      None => return
    }
    if !argument_comparison_command_names().contains(command_name) {
      return
    }
    for argument in @semantics.effective_command_arguments(command) {
      match @semantics.leading_unquoted_text(argument) {
        Some(text) if text.has_prefix("+=") =>
          push_diagnostic(
            diagnostics,
            argument.span,
            CheckSeverity::Error,
            2290,
            "Remove spaces around += to append.",
          )
        Some(text) if text.has_prefix("=") =>
          push_diagnostic(
            diagnostics,
            argument.span,
            CheckSeverity::Error,
            2290,
            "Remove spaces around = to assign.",
          )
        _ => ()
      }
    }
  })
}

///|
// CHECK THIS: THUNK
fn argument_comparison_command_names() -> Array[String] {
  ["alias", "declare", "export", "let", "local", "readonly", "typeset"]
}

///|
fn check_eval_array(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_exact_name(command, "eval") {
      return
    }
    for argument in @semantics.effective_command_arguments(command) {
      let mut saw_quoted_array = false
      let mut saw_array = false
      walk_word_deep(argument, fn(part) {
        if saw_quoted_array {
          return
        }
        if eval_part_is_q_quoted_array(part) {
          saw_quoted_array = true
          return
        }
        if eval_part_is_array_expansion(part) {
          saw_array = true
        }
      })
      if saw_quoted_array {
        push_diagnostic(
          diagnostics,
          argument.span,
          CheckSeverity::Style,
          2293,
          "When eval'ing @Q-quoted words, use * rather than @ as the index.",
        )
      } else if saw_array {
        push_diagnostic(
          diagnostics,
          argument.span,
          CheckSeverity::Warning,
          2294,
          "eval negates the benefit of arrays. Drop eval to preserve whitespace/symbols (or eval as string).",
        )
      }
    }
  })
}

///|
fn eval_part_is_array_expansion(part : @parser.WordPart) -> Bool {
  match part {
    @parser.WordPart::SpecialParameter("@") => true
    @parser.WordPart::BracedParameter(expansion) =>
      parameter_index_is(expansion, "@") || expansion.name == Some("@")
    _ => false
  }
}

///|
fn eval_part_is_q_quoted_array(part : @parser.WordPart) -> Bool {
  match part {
    @parser.WordPart::BracedParameter(expansion) =>
      (parameter_index_is(expansion, "@") || expansion.name == Some("@")) &&
      eval_part_has_q_modifier(expansion)
    _ => false
  }
}

///|
fn eval_part_has_q_modifier(expansion : @parser.ParameterExpansion) -> Bool {
  match expansion.operator {
    Some(@parser.ParameterOperator::Transform("Q")) => true
    _ => false
  }
}
