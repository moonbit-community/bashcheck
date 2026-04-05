///|
fn append_commands_batch_a_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for
    description in [
      {
        code: 2003,
        severity: CheckSeverity::Style,
        category: "commands",
        summary: "expr is antiquated. Prefer modern shell arithmetic or tests.",
      },
      {
        code: 2018,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "Use '[:lower:]' with tr to support accents and foreign alphabets.",
      },
      {
        code: 2019,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "Use '[:upper:]' with tr to support accents and foreign alphabets.",
      },
      {
        code: 2020,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "tr replaces character sets, not whole words.",
      },
      {
        code: 2021,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "Don't wrap tr classes in [].",
      },
      {
        code: 2022,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "Regex wildcards in grep differ from glob wildcards.",
      },
      {
        code: 2059,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "Don't use variables in the printf format string.",
      },
      {
        code: 2060,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Quote tr arguments to prevent glob expansion.",
      },
      {
        code: 2061,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Quote find patterns so the shell won't interpret them.",
      },
      {
        code: 2062,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Quote the grep pattern so the shell won't interpret it.",
      },
      {
        code: 2063,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "grep uses regex, but this pattern looks like a glob.",
      },
      {
        code: 2064,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Use single quotes in trap handlers to defer expansion.",
      },
      {
        code: 2146,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Group find actions behind -o with \\( \\).",
      },
      {
        code: 2150,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "find -exec does not invoke a shell.",
      },
      {
        code: 2151,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "return accepts only one integer 0-255.",
      },
      {
        code: 2152,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "return values must be within 0-255.",
      },
      {
        code: 2156,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Injecting filenames into sh -c under find is fragile.",
      },
      {
        code: 2182,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "printf format string has no variables, so extra arguments are ignored.",
      },
      {
        code: 2183,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "printf format string and argument count do not match.",
      },
      {
        code: 2229,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "read takes variable names, not expansions.",
      },
      {
        code: 2232,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "sudo can't directly run shell builtins.",
      },
      {
        code: 2240,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "The dot command does not support arguments in sh/dash.",
      },
      {
        code: 2241,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "exit accepts only one integer 0-255.",
      },
      {
        code: 2242,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "exit values must be within 0-255.",
      },
      {
        code: 2304,
        severity: CheckSeverity::Error,
        category: "commands",
        summary: "Escape * in expr to multiply.",
      },
      {
        code: 2305,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Quote regex arguments to expr to avoid glob expansion.",
      },
      {
        code: 2306,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Escape glob characters in expr arguments.",
      },
      {
        code: 2307,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "expr expects separate operator and operand arguments.",
      },
      {
        code: 2308,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "Prefer modern replacements for expr subcommands.",
      },
      {
        code: 2313,
        severity: CheckSeverity::Warning,
        category: "commands",
        summary: "Quote array indices in read targets to avoid glob expansion.",
      },
    ] {
    descriptions.push(description)
  }
}

///|
fn check_tr_arguments(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "tr") {
      return
    }
    for argument in @semantics.effective_command_arguments(command) {
      if @semantics.is_glob_word(argument) {
        push_diagnostic(
          diagnostics,
          argument.span,
          CheckSeverity::Warning,
          2060,
          "Quote parameters to tr to prevent glob expansion.",
        )
        continue
      }
      match @semantics.literal_text(argument) {
        Some("a-z") =>
          push_diagnostic(
            diagnostics,
            argument.span,
            CheckSeverity::Info,
            2018,
            "Use '[:lower:]' to support accents and foreign alphabets.",
          )
        Some("A-Z") =>
          push_diagnostic(
            diagnostics,
            argument.span,
            CheckSeverity::Info,
            2019,
            "Use '[:upper:]' to support accents and foreign alphabets.",
          )
        Some(text) => {
          if !text.has_prefix("-") &&
            !text.contains("[:") &&
            tr_literal_has_duplicate_letters(text) {
            push_diagnostic(
              diagnostics,
              argument.span,
              CheckSeverity::Info,
              2020,
              "tr replaces sets of chars, not words (mentioned due to duplicates).",
            )
          }
          if !text.has_prefix("[:") &&
            !text.has_prefix("[=") &&
            text.has_prefix("[") &&
            text.has_suffix("]") &&
            text[:].length() > 2 &&
            !text.contains("*") {
            push_diagnostic(
              diagnostics,
              argument.span,
              CheckSeverity::Info,
              2021,
              "Don't use [] around classes in tr, it replaces literal square brackets.",
            )
          }
        }
        None => ()
      }
    }
  })
}

///|
fn tr_literal_has_duplicate_letters(text : String) -> Bool {
  let seen : Array[Char] = []
  for ch in text[:] {
    if !tr_is_ascii_alpha(ch) {
      continue
    }
    if seen.contains(ch) {
      return true
    }
    seen.push(ch)
  }
  false
}

///|
fn tr_is_ascii_alpha(ch : Char) -> Bool {
  ('a' <= ch && ch <= 'z') || ('A' <= ch && ch <= 'Z')
}

///|
fn check_find_name_globs(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "find") {
      return
    }
    let arguments = @semantics.effective_command_arguments(command)
    let mut i = 1
    while i < arguments.length() {
      match @semantics.literal_text(arguments[i - 1]) {
        Some(flag) if find_pattern_option_accepts_glob(flag) &&
          @semantics.is_glob_word(arguments[i]) =>
          push_diagnostic(
            diagnostics,
            arguments[i].span,
            CheckSeverity::Warning,
            2061,
            "Quote the parameter to \{flag} so the shell won't interpret it.",
          )
        _ => ()
      }
      i += 1
    }
  })
}

///|
fn find_pattern_option_accepts_glob(text : String) -> Bool {
  [
    "-ilname", "-iname", "-ipath", "-iregex", "-iwholename", "-lname", "-name", "-path",
    "-regex", "-wholename",
  ].contains(text)
}

///|
fn check_find_exec_single_argument(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "find") {
      return
    }
    let arguments = @semantics.effective_command_arguments(command)
    let mut i = 0
    while i + 2 < arguments.length() {
      let exec = @semantics.literal_text(arguments[i])
      let term = @semantics.literal_text(arguments[i + 2])
      let snippet = find_literal_argument_text(arguments[i + 1], " ")
      match (exec, term) {
        (Some(exec_name), Some(term_name)) if find_exec_operators().contains(
            exec_name,
          ) &&
          (term_name == ";" || term_name == "+") &&
          find_exec_single_argument_looks_like_command(snippet) =>
          push_diagnostic(
            diagnostics,
            arguments[i].span,
            CheckSeverity::Warning,
            2150,
            "\{exec_name} does not invoke a shell. Rewrite or use \{exec_name} sh -c .. .",
          )
        _ => ()
      }
      i += 1
    }
  })
}

///|
fn find_exec_operators() -> Array[String] {
  ["-exec", "-execdir", "-ok", "-okdir"]
}

///|
fn find_exec_single_argument_looks_like_command(text : String) -> Bool {
  text.contains(" ") || text.contains("|") || text.contains(";")
}

///|
fn check_injectable_find_sh(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "find") {
      return
    }
    let arguments = @semantics.effective_command_arguments(command)
    let mut i = 0
    while i + 3 < arguments.length() {
      match
        (
          @semantics.literal_text(arguments[i]),
          @semantics.literal_text(arguments[i + 1]),
          @semantics.literal_text(arguments[i + 2]),
          @semantics.literal_text(arguments[i + 3]),
        ) {
        (Some(exec_name), Some(shell_name), Some("-c"), Some(snippet)) if find_exec_operators().contains(
            exec_name,
          ) &&
          ["sh", "bash", "dash", "ksh"].contains(shell_name) &&
          snippet.contains("{}") =>
          push_diagnostic(
            diagnostics,
            arguments[i + 3].span,
            CheckSeverity::Warning,
            2156,
            "Injecting filenames is fragile and insecure. Use parameters.",
          )
        _ => ()
      }
      i += 1
    }
  })
}

///|
fn check_find_action_precedence(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "find") {
      return
    }
    let arguments = @semantics.effective_command_arguments(command)
    let mut i = 0
    while i + 5 < arguments.length() {
      if find_is_match_test(arguments[i]) &&
        find_is_or_operator(arguments[i + 2]) &&
        find_is_match_test(arguments[i + 3]) &&
        find_is_action(arguments[i + 5]) {
        push_diagnostic(
          diagnostics,
          arguments[i + 5].span,
          CheckSeverity::Warning,
          2146,
          "This action ignores everything before the -o. Use \\( \\) to group.",
        )
      }
      i += 1
    }
  })
}

///|
fn find_is_match_test(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some(text) =>
      ["-name", "-regex", "-iname", "-iregex", "-wholename", "-iwholename"].contains(
        text,
      )
    None => false
  }
}

///|
fn find_is_or_operator(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some("-o") | Some("-or") => true
    _ => false
  }
}

///|
fn find_is_action(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some(text) =>
      [
        "-exec", "-execdir", "-delete", "-print", "-print0", "-fls", "-fprint", "-fprint0",
        "-fprintf", "-ls", "-ok", "-okdir", "-printf",
      ].contains(text)
    None => false
  }
}

///|
fn check_find_redirections(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "find") {
      return
    }
    let words = @semantics.command_words(command)
    let last_word = match words.get(words.length() - 1) {
      Some(word) => word
      None => return
    }
    for redirect in command.redirects {
      if redirect.span.start.offset < last_word.span.end.offset {
        push_diagnostic(
          diagnostics,
          redirect_operator_span(redirect),
          CheckSeverity::Warning,
          2227,
          "Redirection applies to the find command itself. Rewrite to work per action (or move to end).",
        )
      }
    }
  })
}

///|
fn check_expr_usage(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "expr") {
      return
    }
    let arguments = @semantics.effective_command_arguments(command)
    if expr_should_warn_antiquated(arguments) {
      push_diagnostic(
        diagnostics,
        effective_command_span(command),
        CheckSeverity::Style,
        2003,
        "expr is antiquated. Consider rewriting this using $((..)), ${} or [[ ]].",
      )
    }
    match arguments {
      [lhs, op, rhs] => {
        expr_check_op_replacement(lhs, diagnostics)
        if word_is_exact_unquoted_glob_text(op, "*") {
          push_diagnostic(
            diagnostics,
            op.span,
            CheckSeverity::Error,
            2304,
            "* must be escaped to multiply: \\*. Modern $((x * y)) avoids this issue.",
          )
        }
        match @semantics.literal_text(op) {
          Some(":") if @semantics.is_glob_word(rhs) =>
            push_diagnostic(
              diagnostics,
              rhs.span,
              CheckSeverity::Warning,
              2305,
              "Quote regex argument to expr to avoid it expanding as a glob.",
            )
          _ => ()
        }
      }
      [single] if !word_may_expand_to_multiple(single) =>
        push_diagnostic(
          diagnostics,
          single.span,
          CheckSeverity::Warning,
          2307,
          "'expr' expects 3+ arguments but sees 1. Make sure each operator/operand is a separate argument, and escape <>&|.",
        )
      [first, second] if @semantics.literal_text(first) != Some("length") &&
        !word_may_expand_to_multiple(first) &&
        !word_may_expand_to_multiple(second) => {
        expr_check_op_replacement(first, diagnostics)
        push_diagnostic(
          diagnostics,
          effective_command_span(command),
          CheckSeverity::Warning,
          2307,
          "'expr' expects 3+ arguments, but sees 2. Make sure each operator/operand is a separate argument, and escape <>&|.",
        )
      }
      [first, ..] => {
        expr_check_op_replacement(first, diagnostics)
        let mut i = 1
        while i < arguments.length() {
          if @semantics.is_glob_word(arguments[i]) {
            push_diagnostic(
              diagnostics,
              arguments[i].span,
              CheckSeverity::Warning,
              2306,
              "Escape glob characters in arguments to expr to avoid pathname expansion.",
            )
          }
          i += 1
        }
      }
      _ => ()
    }
  })
}

///|
fn expr_should_warn_antiquated(arguments : Array[@parser.Word]) -> Bool {
  for argument in arguments {
    match @semantics.literal_text(argument) {
      Some(text) if expr_antiquated_exceptions().contains(text) => return false
      _ => ()
    }
  }
  true
}

///|
fn expr_antiquated_exceptions() -> Array[String] {
  [":", "<", ">", "<=", ">=", "match", "length", "substr", "index"]
}

///|
fn expr_check_op_replacement(
  word : @parser.Word,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match @semantics.literal_text(word) {
    Some("match") =>
      push_diagnostic(
        diagnostics,
        word.span,
        CheckSeverity::Info,
        2308,
        "'expr match' has unspecified results. Prefer 'expr str : regex'.",
      )
    Some("length") =>
      push_diagnostic(
        diagnostics,
        word.span,
        CheckSeverity::Info,
        2308,
        "'expr length' has unspecified results. Prefer ${#var}.",
      )
    Some("substr") =>
      push_diagnostic(
        diagnostics,
        word.span,
        CheckSeverity::Info,
        2308,
        "'expr substr' has unspecified results. Prefer 'cut' or ${var#???}.",
      )
    Some("index") =>
      push_diagnostic(
        diagnostics,
        word.span,
        CheckSeverity::Info,
        2308,
        "'expr index' has unspecified results. Prefer x=${var%%[chars]*}; $((${#x}+1)).",
      )
    _ => ()
  }
}

///|
fn word_is_exact_unquoted_glob_text(word : @parser.Word, text : String) -> Bool {
  match word.parts {
    [@parser.WordPart::Glob(raw)] => raw == text
    _ => false
  }
}

///|
fn check_grep_patterns(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "grep") {
      return
    }
    let arguments = @semantics.effective_command_arguments(command)
    let pattern = grep_pattern_argument(arguments)
    match pattern {
      Some(word) => {
        if @semantics.is_glob_word(word) {
          push_diagnostic(
            diagnostics,
            word.span,
            CheckSeverity::Warning,
            2062,
            "Quote the grep pattern so the shell won't interpret it.",
          )
        }
        guard !grep_uses_glob_sensitive_flags(arguments) else { return }
        match @semantics.literal_text(word) {
          Some(text) if grep_regex_looks_like_glob(text) =>
            push_diagnostic(
              diagnostics,
              word.span,
              CheckSeverity::Warning,
              2063,
              "Grep uses regex, but this looks like a glob.",
            )
          Some(text) =>
            match grep_suspicious_regex_char(text) {
              Some(ch) =>
                push_diagnostic(
                  diagnostics,
                  word.span,
                  CheckSeverity::Info,
                  2022,
                  "Note that unlike globs, \{uint16_to_string(ch)}* here matches '\{uint16_to_string(ch)}\{uint16_to_string(ch)}\{uint16_to_string(ch)}' but not '\{grep_word_starting_with(ch)}'.",
                )
              None => ()
            }
          None => ()
        }
      }
      None => ()
    }
  })
}

///|
fn grep_pattern_argument(arguments : Array[@parser.Word]) -> @parser.Word? {
  let mut i = 0
  while i < arguments.length() {
    let text = match @semantics.literal_text(arguments[i]) {
      Some(text) => text
      None => arguments[i].source
    }
    if text == "--" || text == "-e" || text == "--regex" {
      if i + 1 < arguments.length() {
        return Some(arguments[i + 1])
      }
      return None
    }
    if text.has_prefix("-") && !text.has_prefix("--regex=") {
      i += 1
      continue
    }
    return Some(arguments[i])
  }
  None
}

///|
fn grep_uses_glob_sensitive_flags(arguments : Array[@parser.Word]) -> Bool {
  for argument in arguments {
    match @semantics.literal_text(argument) {
      Some(text) if grep_flag_is_glob_sensitive(text) => return true
      _ => ()
    }
  }
  false
}

///|
fn grep_flag_is_glob_sensitive(text : String) -> Bool {
  if text == "--fixed-strings" ||
    text == "--include" ||
    text.has_prefix("--include=") ||
    text == "--exclude" ||
    text.has_prefix("--exclude=") ||
    text == "--exclude-dir" ||
    text.has_prefix("--exclude-dir=") ||
    text == "--only-matching" {
    return true
  }
  if !text.has_prefix("-") || text.has_prefix("--") {
    return false
  }
  let view = text[:]
  let mut i = 1
  while i < view.length() {
    if view[i] == 'F' || view[i] == 'o' {
      return true
    }
    i += 1
  }
  false
}

///|
fn grep_regex_looks_like_glob(text : String) -> Bool {
  if text.contains("?") {
    return true
  }
  if !text.contains("*") {
    return false
  }
  if text.has_prefix("*") ||
    text.contains("*.") ||
    text.contains("*/") ||
    text.contains("/*") {
    return true
  }
  let view = text[:]
  let mut in_class = false
  let mut escaped = false
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if escaped {
      escaped = false
      i += 1
      continue
    }
    if ch == '\\' {
      escaped = true
      i += 1
      continue
    }
    if ch == '[' {
      in_class = true
      i += 1
      continue
    }
    if ch == ']' {
      in_class = false
      i += 1
      continue
    }
    if ch == '*' &&
      !in_class &&
      i > 0 &&
      i + 1 < view.length() &&
      (view[i + 1] == '.' || view[i - 1] == '/' || view[i + 1] == '/') {
      return true
    }
    i += 1
  }
  false
}

///|
fn grep_suspicious_regex_char(text : String) -> UInt16? {
  if text.contains("[") ||
    text.contains("]") ||
    text.contains(".") ||
    text.contains("^") ||
    text.contains("$") ||
    text.contains("+") ||
    text.contains("\\") ||
    text.contains("(") ||
    text.contains(")") {
    return None
  }
  let view = text[:]
  let mut i = 1
  while i < view.length() {
    if view[i] == '*' && grep_is_regex_literal_char(view[i - 1]) {
      return Some(view[i - 1])
    }
    i += 1
  }
  None
}

///|
fn grep_is_regex_literal_char(ch : UInt16) -> Bool {
  let char_ = ch.unsafe_to_char()
  ('a' <= char_ && char_ <= 'z') ||
  ('A' <= char_ && char_ <= 'Z') ||
  ('1' <= char_ && char_ <= '9')
}

///|
fn grep_word_starting_with(ch : UInt16) -> String {
  let char_ = ch.unsafe_to_char()
  let lower = if 'A' <= char_ && char_ <= 'Z' { ch + ('a' - 'A') } else { ch }
  for word in @semantics.sample_words() {
    let view = word[:]
    if view.length() > 0 && view[0] == lower {
      return word
    }
  }
  "\{uint16_to_string(lower)}test"
}

///|
fn check_trap_quotes(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_exact_name(command, "trap") {
      return
    }
    match @semantics.effective_command_arguments(command).get(0) {
      Some(argument) =>
        match word_is_plain_double_quoted(argument) {
          Some(parts) if trap_parts_expand_immediately(parts) =>
            push_diagnostic(
              diagnostics,
              argument.span,
              CheckSeverity::Warning,
              2064,
              "Use single quotes, otherwise this expands now rather than when signalled.",
            )
          _ => ()
        }
      None => ()
    }
  })
}

///|
fn trap_parts_expand_immediately(parts : Array[@parser.WordPart]) -> Bool {
  for part in parts {
    match part {
      @parser.WordPart::Parameter(_)
      | @parser.WordPart::SpecialParameter(_)
      | @parser.WordPart::BracedParameter(_)
      | @parser.WordPart::CommandSubstitution(_)
      | @parser.WordPart::BraceCommandSubstitution(_, _)
      | @parser.WordPart::BackQuoted(_)
      | @parser.WordPart::ArithmeticExpansion(_)
      | @parser.WordPart::DollarBracket(_) => return true
      @parser.WordPart::DoubleQuoted(nested)
      | @parser.WordPart::DollarDoubleQuoted(nested) =>
        if trap_parts_expand_immediately(nested) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn check_return_status_values(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if command_matches_exact_name(command, "return") {
      check_return_or_exit_value(
        command, diagnostics, 2151, "Only one integer 0-255 can be returned. Use stdout for other data.",
        2152, "Can only return 0-255. Other data should be written to stdout.",
      )
    }
  })
}

///|
fn check_exit_status_values(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if command_matches_exact_name(command, "exit") {
      check_return_or_exit_value(
        command, diagnostics, 2241, "The exit status can only be one integer 0-255. Use stdout for other data.",
        2242, "Can only exit with status 0-255. Other data should be written to stdout/stderr.",
      )
    }
  })
}

///|
fn check_return_or_exit_value(
  command : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
  multi_code : Int,
  multi_message : String,
  invalid_code : Int,
  invalid_message : String,
) -> Unit {
  match @semantics.effective_command_arguments(command) {
    [first, second, ..] => {
      ignore(second)
      push_diagnostic(
        diagnostics,
        first.span,
        CheckSeverity::Error,
        multi_code,
        multi_message,
      )
    }
    [value] =>
      if return_or_exit_argument_is_invalid(value) {
        push_diagnostic(
          diagnostics,
          value.span,
          CheckSeverity::Error,
          invalid_code,
          invalid_message,
        )
      }
    _ => ()
  }
}

///|
fn return_or_exit_argument_is_invalid(word : @parser.Word) -> Bool {
  let text = return_or_exit_literal_text(word)
  if text == "" {
    return true
  }
  for ch in text {
    if ch < '0' || ch > '9' {
      return true
    }
  }
  if text.length() > 5 {
    return true
  }
  digits_to_int(text) > 255
}

///|
fn return_or_exit_literal_text(word : @parser.Word) -> String {
  let buf = StringBuilder::new()
  if !append_return_or_exit_parts(word.parts, buf) {
    return ""
  }
  buf.to_string()
}

///|
fn append_return_or_exit_parts(
  parts : Array[@parser.WordPart],
  buf : StringBuilder,
) -> Bool {
  for part in parts {
    if !append_return_or_exit_part(part, buf) {
      return false
    }
  }
  true
}

///|
fn append_return_or_exit_part(
  part : @parser.WordPart,
  buf : StringBuilder,
) -> Bool {
  match part {
    @parser.WordPart::Literal(text)
    | @parser.WordPart::SingleQuoted(text)
    | @parser.WordPart::DollarSingleQuoted(text)
    | @parser.WordPart::Glob(text) => {
      buf.write_string(text)
      true
    }
    @parser.WordPart::Parameter(_)
    | @parser.WordPart::SpecialParameter(_)
    | @parser.WordPart::BracedParameter(_)
    | @parser.WordPart::CommandSubstitution(_)
    | @parser.WordPart::BraceCommandSubstitution(_, _)
    | @parser.WordPart::BackQuoted(_)
    | @parser.WordPart::ArithmeticExpansion(_)
    | @parser.WordPart::DollarBracket(_) => {
      buf.write_string("0")
      true
    }
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      append_return_or_exit_parts(parts, buf)
    _ => false
  }
}

///|
fn check_printf_arguments(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_exact_name(command, "printf") {
      return
    }
    let arguments = @semantics.effective_command_arguments(command)
    let (format, params) = printf_format_and_args(arguments)
    match format {
      Some(format_word) => {
        check_printf_argument_count(format_word, params, diagnostics)
        if !format_word.source.contains("%") &&
          !@semantics.is_constant_word(format_word) {
          push_diagnostic(
            diagnostics,
            format_word.span,
            CheckSeverity::Info,
            2059,
            "Don't use variables in the printf format string. Use printf '..%s..' \"$foo\".",
          )
        }
      }
      None => ()
    }
  })
}

///|
fn printf_format_and_args(
  arguments : Array[@parser.Word],
) -> (@parser.Word?, Array[@parser.Word]) {
  let mut start = 0
  match arguments.get(start) {
    Some(word) if @semantics.literal_text(word) == Some("--") => start += 1
    _ => ()
  }
  match arguments.get(start) {
    Some(word) if @semantics.literal_text(word) == Some("-v") => start += 2
    _ => ()
  }
  match arguments.get(start) {
    Some(format_word) =>
      (Some(format_word), copy_words_from(arguments, start + 1))
    None => (None, [])
  }
}

///|
fn copy_words_from(
  words : Array[@parser.Word],
  start : Int,
) -> Array[@parser.Word] {
  let copied : Array[@parser.Word] = []
  let mut i = start
  while i < words.length() {
    copied.push(words[i])
    i += 1
  }
  copied
}

///|
fn check_printf_argument_count(
  format : @parser.Word,
  params : Array[@parser.Word],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match @semantics.literal_text(format) {
    Some(text) => {
      let formats = printf_formats(text)
      let format_count = formats[:].length()
      let arg_count = params.length()
      if arg_count == 0 && format_count == 0 {
        return
      }
      if format_count == 0 && arg_count > 0 {
        push_diagnostic(
          diagnostics,
          format.span,
          CheckSeverity::Error,
          2182,
          "This printf format string has no variables. Other arguments are ignored.",
        )
        return
      }
      if params.any(fn(param) { word_may_expand_to_multiple(param) }) {
        return
      }
      if arg_count < format_count && printf_only_trailing_ts(formats, arg_count) {
        return
      }
      if arg_count > 0 && arg_count % format_count == 0 {
        return
      }
      let variable_word = printf_pluralize("variable", format_count)
      let argument_word = printf_pluralize("argument", arg_count)
      push_diagnostic(
        diagnostics,
        format.span,
        CheckSeverity::Warning,
        2183,
        "This format string has \{format_count} \{variable_word}, but is passed \{arg_count} \{argument_word}.",
      )
    }
    None => ()
  }
}

///|
fn printf_formats(text : String) -> String {
  let view = text[:]
  let buf = StringBuilder::new()
  let mut i = 0
  while i < view.length() {
    if view[i] != '%' {
      i += 1
      continue
    }
    if i + 1 < view.length() && view[i + 1] == '%' {
      i += 2
      continue
    }
    if i + 1 < view.length() && view[i + 1] == '(' {
      i += 2
      while i < view.length() && view[i] != ')' {
        i += 1
      }
      if i + 1 < view.length() {
        buf.write_char(view[i + 1].unsafe_to_char())
        i += 2
      } else {
        i = view.length()
      }
      continue
    }
    i += 1
    while i < view.length() &&
          (
            view[i] == '#' ||
            view[i] == '-' ||
            view[i] == '+' ||
            view[i] == ' ' ||
            view[i] == '0'
          ) {
      i += 1
    }
    if i < view.length() && view[i] == '*' {
      buf.write_char('*')
      i += 1
    } else {
      while i < view.length() && printf_is_ascii_digit(view[i]) {
        i += 1
      }
    }
    if i < view.length() && view[i] == '.' {
      i += 1
      if i < view.length() && view[i] == '*' {
        buf.write_char('*')
        i += 1
      } else {
        while i < view.length() && printf_is_ascii_digit(view[i]) {
          i += 1
        }
      }
    }
    if i + 1 < view.length() &&
      (
        (view[i] == 'h' && view[i + 1] == 'h') ||
        (view[i] == 'l' && view[i + 1] == 'l')
      ) {
      i += 2
    } else if i < view.length() &&
      (
        view[i] == 'h' ||
        view[i] == 'l' ||
        view[i] == 'q' ||
        view[i] == 'L' ||
        view[i] == 'j' ||
        view[i] == 'z' ||
        view[i] == 'Z' ||
        view[i] == 't'
      ) {
      i += 1
    }
    if i < view.length() {
      buf.write_char(view[i].unsafe_to_char())
      i += 1
    }
  }
  buf.to_string()
}

///|
fn printf_only_trailing_ts(formats : String, arg_count : Int) -> Bool {
  let view = formats[:]
  let mut i = arg_count
  while i < view.length() {
    if view[i] != 'T' {
      return false
    }
    i += 1
  }
  true
}

///|
fn printf_pluralize(word : String, count : Int) -> String {
  if count == 1 {
    word
  } else {
    "\{word}s"
  }
}

///|
fn printf_is_ascii_digit(ch : UInt16) -> Bool {
  let char_ = ch.unsafe_to_char()
  '0' <= char_ && char_ <= '9'
}

///|
fn check_source_arguments(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell_is_posix_sh(shell) else { return }
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Source(source) =>
        match source.args.get(0) {
          Some(argument) =>
            push_diagnostic(
              diagnostics,
              argument.span,
              CheckSeverity::Warning,
              2240,
              "The dot command does not support arguments in sh/dash. Set them as variables.",
            )
          None => ()
        }
      _ => ()
    }
  })
}

///|
fn check_sudo_arguments(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "sudo") {
      return
    }
    match sudo_command_word(@semantics.effective_command_arguments(command)) {
      Some(command_word) =>
        match @semantics.literal_text(command_word) {
          Some(name) if sudo_builtin_names().contains(name) =>
            push_diagnostic(
              diagnostics,
              effective_command_span(command),
              CheckSeverity::Warning,
              2232,
              "Can't use sudo with builtins like \{name}. Did you want sudo sh -c .. instead?",
            )
          _ => ()
        }
      None => ()
    }
  })
}

///|
fn sudo_builtin_names() -> Array[String] {
  [
    "cd", "command", "declare", "eval", "exec", "exit", "export", "hash", "history",
    "local", "popd", "pushd", "read", "readonly", "return", "set", "source", "trap",
    "type", "typeset", "ulimit", "umask", "unset", "wait",
  ]
}

///|
fn sudo_command_word(arguments : Array[@parser.Word]) -> @parser.Word? {
  let mut i = 0
  while i < arguments.length() {
    let text = match @semantics.literal_text(arguments[i]) {
      Some(text) => text
      None => return Some(arguments[i])
    }
    if text == "--" {
      if i + 1 < arguments.length() {
        return Some(arguments[i + 1])
      }
      return None
    }
    if !text.has_prefix("-") || text == "-" {
      return Some(arguments[i])
    }
    if text.has_prefix("--") {
      if sudo_long_option_takes_argument(text) &&
        !text.contains("=") &&
        i + 1 < arguments.length() {
        i += 2
      } else {
        i += 1
      }
      continue
    }
    if sudo_short_option_consumes_next(text) && i + 1 < arguments.length() {
      i += 2
    } else {
      i += 1
    }
  }
  None
}

///|
fn sudo_short_option_consumes_next(text : String) -> Bool {
  if !text.has_prefix("-") || text.has_prefix("--") {
    return false
  }
  let view = text[:]
  let mut i = 1
  while i < view.length() {
    if sudo_short_option_takes_argument(view[i]) {
      return i + 1 == view.length()
    }
    i += 1
  }
  false
}

///|
fn sudo_short_option_takes_argument(flag : UInt16) -> Bool {
  match flag {
    'a' | 'g' | 'h' | 'p' | 'u' | 'c' | 'T' | 'r' => true
    _ => false
  }
}

///|
fn sudo_long_option_takes_argument(text : String) -> Bool {
  text == "--host" ||
  text == "--prompt" ||
  text == "--group" ||
  text == "--user" ||
  text == "--role" ||
  text == "--type" ||
  text == "--chdir"
}

///|
fn check_read_expansions(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_exact_name(command, "read") {
      return
    }
    let arguments = @semantics.effective_command_arguments(command)
    for variable_word in read_variable_words(arguments) {
      match read_expansion_target_name(variable_word) {
        Some(name) if is_identifier_name(name) =>
          push_diagnostic(
            diagnostics,
            variable_word.span,
            CheckSeverity::Warning,
            2229,
            "This does not read '\{name}'. Remove $/${} for that, or use ${var?} to quiet.",
          )
        _ => ()
      }
    }
    for argument in arguments {
      if read_word_has_unquoted_array_index(argument) {
        push_diagnostic(
          diagnostics,
          argument.span,
          CheckSeverity::Warning,
          2313,
          "Quote array indices to avoid them expanding as globs.",
        )
      }
    }
  })
}

///|
fn read_variable_words(arguments : Array[@parser.Word]) -> Array[@parser.Word] {
  let variables : Array[@parser.Word] = []
  let mut i = 0
  while i < arguments.length() {
    let text = match @semantics.leading_unquoted_text(arguments[i]) {
      Some(text) => text
      None => {
        variables.push(arguments[i])
        i += 1
        continue
      }
    }
    if text == "--" {
      i += 1
      while i < arguments.length() {
        variables.push(arguments[i])
        i += 1
      }
      break
    }
    if !text.has_prefix("-") || text == "-" {
      variables.push(arguments[i])
      i += 1
      continue
    }
    let option_text = text.view(start_offset=1).to_string()
    if option_text == "" {
      variables.push(arguments[i])
      i += 1
      continue
    }
    let view = option_text[:]
    let mut consumed_next = false
    let mut j = 0
    while j < view.length() {
      let flag = view[j]
      if read_flag_takes_argument(flag) {
        let attached = option_text.view(start_offset=j + 1).to_string()
        if flag == 'a' {
          if attached == "" && i + 1 < arguments.length() {
            variables.push(arguments[i + 1])
          }
        }
        if attached == "" && i + 1 < arguments.length() {
          consumed_next = true
        }
        break
      }
      j += 1
    }
    if consumed_next {
      i += 2
    } else {
      i += 1
    }
  }
  variables
}

///|
fn read_expansion_target_name(word : @parser.Word) -> String? {
  match word.parts {
    [@parser.WordPart::Parameter(name)]
    | [@parser.WordPart::SpecialParameter(name)] => Some(name)
    [@parser.WordPart::BracedParameter(expansion)] =>
      read_braced_target_name(expansion)
    [@parser.WordPart::DoubleQuoted(parts)]
    | [@parser.WordPart::DollarDoubleQuoted(parts)] =>
      match parts {
        [@parser.WordPart::Parameter(name)]
        | [@parser.WordPart::SpecialParameter(name)] => Some(name)
        [@parser.WordPart::BracedParameter(expansion)] =>
          read_braced_target_name(expansion)
        _ => None
      }
    _ => None
  }
}

///|
fn read_braced_target_name(expansion : @parser.ParameterExpansion) -> String? {
  if expansion.length_prefix ||
    expansion.indirect ||
    expansion.index is Some(_) ||
    expansion.operator is Some(_) {
    return None
  }
  expansion.name
}

///|
fn read_word_has_unquoted_array_index(word : @parser.Word) -> Bool {
  for part in word.parts {
    match part {
      @parser.WordPart::Glob(text) if text.has_prefix("[") => return true
      _ => ()
    }
  }
  word.source.contains("[") &&
  word.source.contains("]") &&
  !word_is_plain_single_quoted(word) &&
  word_is_plain_double_quoted(word) is None
}

///|
fn find_literal_argument_text(word : @parser.Word, fallback : String) -> String {
  match @semantics.literal_text(word) {
    Some(text) => text
    None => fallback
  }
}
