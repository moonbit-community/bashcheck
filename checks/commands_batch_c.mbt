///|
fn append_commands_batch_c_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for
    description in [
      {
        code: 2029,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "Unescaped ssh command strings expand locally on the client.",
      },
      {
        code: 2114,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Recursive rm on system directories is dangerous.",
      },
      {
        code: 2115,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Guard recursive rm paths with ${var:?}.",
      },
      {
        code: 2117,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "Use su -c or sudo instead of interactive su in scripts.",
      },
      {
        code: 2121,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Use plain var=value instead of set for assignments.",
      },
      {
        code: 2163,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "export takes variable names, not expansions.",
      },
      {
        code: 2168,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "'local' is only valid inside functions.",
      },
      {
        code: 2174,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "mkdir -p -m only applies the mode to the deepest directory.",
      },
      {
        code: 2176,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "POSIX time is undefined for pipelines.",
      },
      {
        code: 2177,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "POSIX time is undefined for compound commands.",
      },
      {
        code: 2184,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Quote unset arguments so the shell does not glob them.",
      },
      {
        code: 2291,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "Quote repeated spaces in echo arguments to preserve them.",
      },
      {
        code: 2316,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "Do not apply declaration commands to the literal name of another declaration command.",
      },
      {
        code: 2318,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Later declaration arguments do not see assignments from earlier ones in the same command.",
      },
    ] {
    descriptions.push(description)
  }
}

///|
fn run_commands_batch_c_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_mkdir_dash_pm(script, diagnostics)
  check_interactive_su(script, diagnostics)
  check_ssh_command_string(script, diagnostics)
  check_set_assignment(script, diagnostics)
  check_exported_expansions(script, diagnostics)
  check_unset_globs(script, diagnostics)
  check_timed_command(script, shell, diagnostics)
  check_local_scope(script, shell, diagnostics)
  check_catastrophic_rm(script, diagnostics)
  check_unquoted_echo_spaces(script, diagnostics)
  check_multiple_declaring(script, diagnostics)
  check_backreferencing_declaration(script, diagnostics)
}

///|
fn check_mkdir_dash_pm(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_basename(command, "mkdir") else { return }
    let arguments = @semantics.effective_command_arguments(command)
    let mut saw_parents = false
    let mut mode_span : @parser.Span? = None
    for argument in arguments {
      match @semantics.literal_text(argument) {
        Some(text) => {
          if mkdir_text_has_parents_flag(text) {
            saw_parents = true
          }
          if mkdir_text_has_mode_flag(text) && mode_span is None {
            mode_span = Some(argument.span)
          }
        }
        None => ()
      }
    }
    guard saw_parents else { return }
    let span = match mode_span {
      Some(span) => span
      None => return
    }
    for argument in arguments {
      if mkdir_argument_could_have_subdirs(argument) {
        push_diagnostic(
          diagnostics,
          span,
          CheckSeverity::Warning,
          2174,
          "When used with -p, -m only applies to the deepest directory.",
        )
        return
      }
    }
  })
}

///|
fn mkdir_text_has_parents_flag(text : String) -> Bool {
  text == "--parents" || short_option_cluster_contains(text, 'p')
}

///|
fn mkdir_text_has_mode_flag(text : String) -> Bool {
  text == "--mode" ||
  text.has_prefix("--mode=") ||
  short_option_cluster_contains(text, 'm')
}

///|
fn short_option_cluster_contains(text : String, flag : Char) -> Bool {
  if !text.has_prefix("-") || text.has_prefix("--") {
    return false
  }
  let view = text[:]
  let mut i = 1
  while i < view.length() {
    if view[i].unsafe_to_char() == flag {
      return true
    }
    i += 1
  }
  false
}

///|
fn mkdir_argument_could_have_subdirs(argument : @parser.Word) -> Bool {
  match @semantics.literal_text(argument) {
    Some(text) =>
      text.contains("/") && !mkdir_literal_is_single_relative_segment(text)
    None => true
  }
}

///|
fn mkdir_literal_is_single_relative_segment(text : String) -> Bool {
  let mut rest = text
  let mut consumed = false
  while rest.has_prefix("../") || rest.has_prefix("./") {
    consumed = true
    rest = rest
      .view(start_offset=if rest.has_prefix("../") { 3 } else { 2 })
      .to_string()
  }
  consumed && !rest.contains("/") && rest != ""
}

///|
fn check_interactive_su(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_pipelines(script, fn(pipeline) {
    guard pipeline.segments.length() == 1 else { return }
    let command = pipeline.segments[0].command
    guard command_matches_basename(command, "su") else { return }
    if command.redirects.length() > 0 {
      return
    }
    if @semantics.effective_command_arguments(command).length() <= 1 {
      push_diagnostic(
        diagnostics,
        command.span,
        CheckSeverity::Info,
        2117,
        "To run commands as another user, use su -c or sudo.",
      )
    }
  })
}

///|
fn check_ssh_command_string(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_basename(command, "ssh") else { return }
    let arguments = @semantics.effective_command_arguments(command)
    if arguments.any(@semantics.is_unquoted_flag) || arguments.length() < 2 {
      return
    }
    let last_argument = arguments[arguments.length() - 1]
    match ssh_remote_command_span(last_argument) {
      Some(span) =>
        push_diagnostic(
          diagnostics,
          span,
          CheckSeverity::Info,
          2029,
          "Note that, unescaped, this expands on the client side.",
        )
      None => ()
    }
  })
}

///|
fn ssh_remote_command_span(argument : @parser.Word) -> @parser.Span? {
  match word_is_plain_double_quoted(argument) {
    Some(parts) =>
      match ssh_first_dynamic_needle(parts) {
        Some(needle) =>
          match word_subspan(argument, needle) {
            Some(span) => Some(span)
            None => Some(argument.span)
          }
        None => None
      }
    None => None
  }
}

///|
fn ssh_first_dynamic_needle(parts : Array[@parser.WordPart]) -> String? {
  for part in parts {
    match ssh_dynamic_part_needle(part) {
      Some(needle) => return Some(needle)
      None => ()
    }
  }
  None
}

///|
fn ssh_dynamic_part_needle(part : @parser.WordPart) -> String? {
  match part {
    @parser.WordPart::Parameter(name) => Some("$\{name}")
    @parser.WordPart::SpecialParameter(name) => Some("$\{name}")
    @parser.WordPart::BracedParameter(expansion) => Some("${\{expansion.raw}}")
    @parser.WordPart::CommandSubstitution(_) => Some("$(")
    @parser.WordPart::BraceCommandSubstitution(_, _) => Some("${")
    @parser.WordPart::BackQuoted(_) => Some("`")
    @parser.WordPart::ProcessSubstitution(prefix, _) => Some("\{prefix}(")
    @parser.WordPart::ArithmeticExpansion(_) => Some("$((")
    @parser.WordPart::DollarBracket(_) => Some("$[")
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      ssh_first_dynamic_needle(parts)
    _ => None
  }
}

///|
fn check_set_assignment(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_exact_name(command, "set") else { return }
    let arguments = @semantics.effective_command_arguments(command)
    match arguments {
      [first, ..] =>
        match @semantics.leading_unquoted_text(first) {
          Some(text) if (arguments.length() > 1 && is_identifier_name(text)) ||
            text.contains("=") =>
            push_diagnostic(
              diagnostics,
              first.span,
              CheckSeverity::Warning,
              2121,
              "To assign a variable, use just 'var=value', no 'set ..'.",
            )
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn check_exported_expansions(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_exact_name(command, "export") else { return }
    for argument in @semantics.effective_command_arguments(command) {
      match read_expansion_target_name(argument) {
        Some(name) =>
          push_diagnostic(
            diagnostics,
            argument.span,
            CheckSeverity::Warning,
            2163,
            "This does not export '\{name}'. Remove $/${} for that, or use ${var?} to quiet.",
          )
        None => ()
      }
    }
  })
}

///|
fn check_unset_globs(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_exact_name(command, "unset") else { return }
    for argument in @semantics.effective_command_arguments(command) {
      if @semantics.is_glob_word(argument) {
        push_diagnostic(
          diagnostics,
          argument.span,
          CheckSeverity::Warning,
          2184,
          "Quote arguments to unset so they're not glob expanded.",
        )
      }
    }
  })
}

///|
fn check_timed_command(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell_is_posix_sh(shell) else { return }
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Time(clause) => {
        if clause.body.segments.length() > 1 {
          push_diagnostic(
            diagnostics,
            command_keyword_span(command, "time"),
            CheckSeverity::Warning,
            2176,
            "'time' is undefined for pipelines. time single stage or bash -c instead.",
          )
          return
        }
        match clause.body.segments.get(0) {
          Some(segment) if !timed_body_is_simple(segment.command) =>
            push_diagnostic(
              diagnostics,
              segment.command.span,
              CheckSeverity::Warning,
              2177,
              "'time' is undefined for compound commands, time sh -c instead.",
            )
          _ => ()
        }
      }
      _ => ()
    }
  })
}

///|
fn timed_body_is_simple(command : @parser.Command) -> Bool {
  match command.kind {
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_) => true
    _ => false
  }
}

///|
fn check_local_scope(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell_is_one_of(shell, [
    @semantics.ShellDialect::Bash,
    @semantics.ShellDialect::Dash,
    @semantics.ShellDialect::BusyboxSh,
  ]) else {
    return
  }
  visit_commands_with_function_scope(script, false, fn(command, in_function) {
    if !in_function && command_matches_exact_name(command, "local") {
      push_diagnostic(
        diagnostics,
        effective_command_span(command),
        CheckSeverity::Error,
        2168,
        "'local' is only valid in functions.",
      )
    }
  })
}

///|
fn visit_commands_with_function_scope(
  script : @parser.Script,
  in_function : Bool,
  visit : (@parser.Command, Bool) -> Unit,
) -> Unit {
  for item in script.items {
    visit_pipeline_with_function_scope(item.and_or.head, in_function, visit)
    for pair in item.and_or.tail {
      let (_, pipeline) = pair
      visit_pipeline_with_function_scope(pipeline, in_function, visit)
    }
  }
}

///|
fn visit_pipeline_with_function_scope(
  pipeline : @parser.Pipeline,
  in_function : Bool,
  visit : (@parser.Command, Bool) -> Unit,
) -> Unit {
  for segment in pipeline.segments {
    visit_command_with_function_scope(segment.command, in_function, visit)
  }
}

///|
fn visit_command_with_function_scope(
  command : @parser.Command,
  in_function : Bool,
  visit : (@parser.Command, Bool) -> Unit,
) -> Unit {
  visit(command, in_function)
  match command.kind {
    @parser.CommandKind::Time(clause) =>
      visit_pipeline_with_function_scope(clause.body, in_function, visit)
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BraceGroup(script) =>
      visit_commands_with_function_scope(script, in_function, visit)
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        visit_commands_with_function_scope(arm.condition, in_function, visit)
        visit_commands_with_function_scope(arm.body, in_function, visit)
      }
      match clause.else_body {
        Some(body) =>
          visit_commands_with_function_scope(body, in_function, visit)
        None => ()
      }
    }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) => {
      visit_commands_with_function_scope(clause.condition, in_function, visit)
      visit_commands_with_function_scope(clause.body, in_function, visit)
    }
    @parser.CommandKind::ForIn(clause) =>
      visit_commands_with_function_scope(clause.body, in_function, visit)
    @parser.CommandKind::ForArithmetic(clause) =>
      visit_commands_with_function_scope(clause.body, in_function, visit)
    @parser.CommandKind::Select(clause) =>
      visit_commands_with_function_scope(clause.body, in_function, visit)
    @parser.CommandKind::Case(clause) =>
      for item in clause.items {
        visit_commands_with_function_scope(item.body, in_function, visit)
      }
    @parser.CommandKind::Function(function_) =>
      visit_command_with_function_scope(function_.body, true, visit)
    @parser.CommandKind::BatsTest(clause) =>
      visit_commands_with_function_scope(clause.body, true, visit)
    @parser.CommandKind::CoProc(clause) =>
      visit_command_with_function_scope(clause.body, in_function, visit)
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_) => ()
  }
}

///|
fn check_catastrophic_rm(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_basename(command, "rm") else { return }
    guard rm_is_recursive(@semantics.effective_command_arguments(command)) else {
      return
    }
    for argument in @semantics.effective_command_arguments(command) {
      if rm_word_has_safe_path_guard(argument) {
        continue
      }
      for candidate in rm_word_potential_paths(argument) {
        let (raw_path, dynamic) = candidate
        let path = rm_normalize_path(raw_path)
        if rm_important_paths().contains(path) {
          if dynamic {
            push_diagnostic(
              diagnostics,
              argument.span,
              CheckSeverity::Warning,
              2115,
              "Use \"${var:?}\" to ensure this never expands to \{path} .",
            )
          } else {
            push_diagnostic(
              diagnostics,
              argument.span,
              CheckSeverity::Warning,
              2114,
              "Warning: deletes a system directory.",
            )
          }
          return
        }
      }
    }
  })
}

///|
fn rm_is_recursive(arguments : Array[@parser.Word]) -> Bool {
  for argument in arguments {
    match @semantics.literal_text(argument) {
      Some(text) if text == "--recursive" => return true
      Some(text) if short_option_cluster_contains(text, 'r') ||
        short_option_cluster_contains(text, 'R') => return true
      _ => ()
    }
  }
  false
}

///|
fn rm_word_has_safe_path_guard(word : @parser.Word) -> Bool {
  let mut safe = false
  for part in word.parts {
    @semantics.walk_word_part(part, fn(current) {
      match current {
        @parser.WordPart::BracedParameter(expansion) =>
          match expansion.operator {
            Some(@parser.ParameterOperator::DefaultValue(_))
            | Some(@parser.ParameterOperator::AssignDefault(_))
            | Some(@parser.ParameterOperator::ErrorValue(_)) => safe = true
            _ => ()
          }
        _ => ()
      }
    })
  }
  safe
}

///|
fn rm_word_potential_paths(word : @parser.Word) -> Array[(String, Bool)] {
  let mut current : Array[(String, Bool)] = [("", false)]
  for part in word.parts {
    let variants = rm_part_path_variants(part)
    if variants.length() == 0 {
      return []
    }
    let next : Array[(String, Bool)] = []
    for prefix in current {
      for variant in variants {
        next.push((prefix.0 + variant.0, prefix.1 || variant.1))
      }
    }
    current = next
  }
  current
}

///|
fn rm_part_path_variants(part : @parser.WordPart) -> Array[(String, Bool)] {
  match part {
    @parser.WordPart::Literal(text)
    | @parser.WordPart::SingleQuoted(text)
    | @parser.WordPart::DollarSingleQuoted(text)
    | @parser.WordPart::Glob(text) => [(text, false)]
    @parser.WordPart::Parameter(_)
    | @parser.WordPart::SpecialParameter(_)
    | @parser.WordPart::BracedParameter(_)
    | @parser.WordPart::CommandSubstitution(_)
    | @parser.WordPart::BraceCommandSubstitution(_, _)
    | @parser.WordPart::BackQuoted(_)
    | @parser.WordPart::ArithmeticExpansion(_)
    | @parser.WordPart::DollarBracket(_)
    | @parser.WordPart::ProcessSubstitution(_, _) => [("", true)]
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      rm_parts_path_variants(parts)
    @parser.WordPart::ExtGlob(_) => [("", true)]
    @parser.WordPart::BraceExpansion(expansion) => {
      let variants : Array[(String, Bool)] = []
      for element in expansion.elements {
        for variant in rm_word_potential_paths(element) {
          variants.push(variant)
        }
      }
      variants
    }
  }
}

///|
fn rm_parts_path_variants(
  parts : Array[@parser.WordPart],
) -> Array[(String, Bool)] {
  let mut current : Array[(String, Bool)] = [("", false)]
  for part in parts {
    let variants = rm_part_path_variants(part)
    if variants.length() == 0 {
      return []
    }
    let next : Array[(String, Bool)] = []
    for prefix in current {
      for variant in variants {
        next.push((prefix.0 + variant.0, prefix.1 || variant.1))
      }
    }
    current = next
  }
  current
}

///|
fn rm_normalize_path(path : String) -> String {
  let normalized = rm_skip_repeating(rm_skip_repeating(path, '/'), '*')
  if normalized == "/" {
    normalized
  } else {
    rm_strip_trailing(normalized, '/')
  }
}

///|
fn rm_skip_repeating(text : String, target : Char) -> String {
  let view = text[:]
  let buf = StringBuilder::new()
  let mut i = 0
  while i < view.length() {
    let current = view[i].unsafe_to_char()
    buf.write_string(uint16_to_string(view[i]))
    if current == target {
      let mut j = i + 1
      while j < view.length() && view[j].unsafe_to_char() == target {
        j += 1
      }
      i = j
    } else {
      i += 1
    }
  }
  buf.to_string()
}

///|
fn rm_strip_trailing(text : String, target : Char) -> String {
  let view = text[:]
  let mut end_ = view.length()
  while end_ > 0 && view[end_ - 1].unsafe_to_char() == target {
    end_ -= 1
  }
  text.view(end_offset=end_).to_string()
}

///|
fn rm_important_paths() -> Array[String] {
  let bases = [
    "", "/bin", "/etc", "/home", "/mnt", "/usr", "/usr/share", "/usr/local", "/var",
    "/lib", "/dev", "/media", "/boot", "/lib64", "/usr/bin",
  ]
  let suffixes = ["", "/", "/*", "/*/*"]
  let paths : Array[String] = []
  for base in bases {
    for suffix in suffixes {
      let path = base + suffix
      if path != "" && !paths.contains(path) {
        paths.push(path)
      }
    }
  }
  paths
}

///|
fn check_unquoted_echo_spaces(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_basename(command, "echo") else { return }
    let arguments = @semantics.effective_command_arguments(command)
    if arguments.length() < 2 {
      return
    }
    let redirect_offsets : Array[Int] = []
    for redirect in command.redirects {
      redirect_offsets.push(redirect.span.start.offset)
    }
    let mut i = 0
    while i + 1 < arguments.length() {
      let lhs = arguments[i]
      let rhs = arguments[i + 1]
      if lhs.span.end.line == rhs.span.start.line &&
        rhs.span.start.column - lhs.span.end.column >= 4 &&
        !echo_has_redirection_between(
          redirect_offsets,
          lhs.span.end.offset,
          rhs.span.start.offset,
        ) {
        push_diagnostic(
          diagnostics,
          command.span,
          CheckSeverity::Info,
          2291,
          "Quote repeated spaces to avoid them collapsing into one.",
        )
        return
      }
      i += 1
    }
  })
}

///|
fn echo_has_redirection_between(
  redirect_offsets : Array[Int],
  start : Int,
  end_ : Int,
) -> Bool {
  for offset in redirect_offsets {
    if start < offset && offset < end_ {
      return true
    }
  }
  false
}

///|
fn check_multiple_declaring(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    let command_name = match @semantics.effective_command_name(command) {
      Some(name) => name
      None => return
    }
    if !@semantics.declaring_command_names().contains(command_name) {
      return
    }
    for argument in @semantics.effective_command_arguments(command) {
      match @semantics.leading_unquoted_text(argument) {
        Some(text) if @semantics.declaring_command_names().contains(text) =>
          push_diagnostic(
            diagnostics,
            argument.span,
            CheckSeverity::Error,
            2316,
            "This applies \{command_name} to the variable named \{text}, which is probably not what you want. Use a separate command or the appropriate `declare` options instead.",
          )
        _ => ()
      }
    }
  })
}

///|
fn check_backreferencing_declaration(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    let command_name = match @semantics.effective_command_name(command) {
      Some(name) => name
      None => return
    }
    if !@semantics.declaring_command_names().contains(command_name) {
      return
    }
    let elements = declaration_elements_in_command(command)
    guard elements.length() > 0 else { return }
    let assigned : Map[String, @parser.Span] = Map::new()
    let warned : Array[String] = []
    for element in elements {
      let references = declaration_element_references(element)
      for reference in references {
        guard !warned.contains(reference) else { continue }
        match assigned.get(reference) {
          Some(span) => {
            push_diagnostic(
              diagnostics,
              span,
              CheckSeverity::Warning,
              2318,
              "This assignment is used again in this '\{command_name}', but won't have taken effect. Use two '\{command_name}'s.",
            )
            warned.push(reference)
          }
          None => ()
        }
      }
      match element {
        DeclarationCommandElement::Assignment(assignment) =>
          assigned.set(assignment.name, assignment_name_span(assignment))
        DeclarationCommandElement::Word(_) => ()
      }
    }
  })
}

///|
priv enum DeclarationCommandElement {
  Assignment(@parser.Assignment)
  Word(@parser.Word)
}

///|
fn declaration_elements_in_command(
  command : @parser.Command,
) -> Array[DeclarationCommandElement] {
  match command.kind {
    @parser.CommandKind::Simple(simple) => {
      let elements : Array[(Int, DeclarationCommandElement)] = []
      for assignment in simple.assignments {
        elements.push(
          (
            assignment.span.start.offset,
            DeclarationCommandElement::Assignment(assignment),
          ),
        )
      }
      for word in @semantics.effective_command_arguments(command) {
        elements.push(
          (word.span.start.offset, DeclarationCommandElement::Word(word)),
        )
      }
      declaration_sort_elements(elements)
    }
    _ => []
  }
}

///|
fn declaration_sort_elements(
  elements : Array[(Int, DeclarationCommandElement)],
) -> Array[DeclarationCommandElement] {
  let sorted : Array[(Int, DeclarationCommandElement)] = []
  for element in elements {
    sorted.push(element)
  }
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      if sorted[j].0 < sorted[i].0 {
        let current = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = current
      }
      j += 1
    }
    i += 1
  }
  let ordered : Array[DeclarationCommandElement] = []
  for pair in sorted {
    ordered.push(pair.1)
  }
  ordered
}

///|
fn declaration_element_references(
  element : DeclarationCommandElement,
) -> Array[String] {
  let references : Array[String] = []
  match element {
    DeclarationCommandElement::Assignment(assignment) => {
      for index in assignment.indexes {
        collect_word_part_reference_names(index.parts, references)
      }
      collect_assignment_value_reference_names(assignment.value, references)
    }
    DeclarationCommandElement::Word(word) =>
      collect_word_reference_names(word, references)
  }
  references
}

///|
fn collect_assignment_value_reference_names(
  value : @parser.AssignmentValue,
  references : Array[String],
) -> Unit {
  match value {
    @parser.AssignmentValue::Empty => ()
    @parser.AssignmentValue::Word(word) =>
      collect_word_reference_names(word, references)
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      for element in elements {
        for index in element.indexes {
          collect_word_part_reference_names(index.parts, references)
        }
        collect_assignment_value_reference_names(element.value, references)
      }
  }
}

///|
fn collect_word_reference_names(
  word : @parser.Word,
  references : Array[String],
) -> Unit {
  collect_word_part_reference_names(word.parts, references)
}

///|
fn collect_word_part_reference_names(
  parts : Array[@parser.WordPart],
  references : Array[String],
) -> Unit {
  for part in parts {
    @semantics.walk_word_part(part, fn(current) {
      match current {
        @parser.WordPart::Parameter(name) =>
          push_unique_reference_name(references, name)
        @parser.WordPart::BracedParameter(expansion) =>
          match expansion.name {
            Some(name) => push_unique_reference_name(references, name)
            None => ()
          }
        @parser.WordPart::ArithmeticExpansion(expr)
        | @parser.WordPart::DollarBracket(expr) =>
          analytics_collect_arithmetic_reference_names(expr, references)
        _ => ()
      }
    })
  }
}

///|
fn push_unique_reference_name(
  references : Array[String],
  name : String,
) -> Unit {
  if !references.contains(name) {
    references.push(name)
  }
}
