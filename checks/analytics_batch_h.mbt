///|
fn append_analytics_batch_h_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_h_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_h_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2035,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Globs that expand to names with dashes can become options.",
    },
    {
      code: 2141,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Suspicious IFS values are usually meant to use escapes or literal whitespace.",
    },
    {
      code: 2123,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "PATH is the shell search path and should not be repurposed as a local variable.",
    },
    {
      code: 2147,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Literal tilde in PATH works poorly across programs.",
    },
  ]
}

///|
fn run_analytics_batch_h_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_globs_as_options(script, diagnostics)
  check_suspicious_ifs(script, shell, diagnostics)
  check_overriding_path(script, diagnostics)
  check_tilde_in_path(script, diagnostics)
}

///|
fn check_globs_as_options(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match @semantics.command_basename(command) {
      Some("echo") | Some("printf") => ()
      _ =>
        match command.kind {
          @parser.CommandKind::Simple(_) => {
            let arguments = @semantics.command_arguments(command)
            let mut i = 0
            while i < arguments.length() {
              let argument = arguments[i]
              if analytics_word_is_glob_option(argument) {
                push_diagnostic(
                  diagnostics,
                  argument.span,
                  CheckSeverity::Info,
                  2035,
                  "Use ./*glob* or -- *glob* so names with dashes won't become options.",
                )
              }
              if analytics_is_end_of_args(argument) {
                break
              }
              i += 1
            }
          }
          _ => ()
        }
    }
  })
}

///|
fn analytics_word_is_glob_option(word : @parser.Word) -> Bool {
  match word.parts.get(0) {
    Some(@parser.WordPart::Glob(text)) =>
      text.has_prefix("*") || text.has_prefix("?")
    _ => false
  }
}

///|
fn analytics_is_end_of_args(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some("--") | Some(":::") | Some("::::") => true
    _ => false
  }
}

///|
fn check_suspicious_ifs(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        for assignment in simple.assignments {
          match assignment.value {
            @parser.AssignmentValue::Word(value) =>
              if assignment.name == "IFS" &&
                !assignment.append &&
                assignment.indexes.length() == 0 {
                match @semantics.literal_text(value) {
                  Some(text) =>
                    analytics_maybe_warn_suspicious_ifs(
                      text,
                      value.span,
                      shell,
                      diagnostics,
                    )
                  None => ()
                }
              }
            _ => ()
          }
        }
      _ => ()
    }
  })
}

///|
fn analytics_maybe_warn_suspicious_ifs(
  text : String,
  span : @parser.Span,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let has_dollar_single = shell == @semantics.ShellDialect::Bash ||
    shell == @semantics.ShellDialect::Ksh
  let linefeed_hint = if has_dollar_single {
    "$'\\n'"
  } else {
    "'<literal linefeed here>'"
  }
  let tab_hint = if has_dollar_single {
    "$'\\t'"
  } else {
    "\"$(printf '\\t')\""
  }

  if text == "\\n" {
    push_diagnostic(
      diagnostics,
      span,
      CheckSeverity::Warning,
      2141,
      "This backslash is literal. Did you mean IFS=\{linefeed_hint} ?",
    )
    return
  }
  if text == "\\t" {
    push_diagnostic(
      diagnostics,
      span,
      CheckSeverity::Warning,
      2141,
      "This backslash is literal. Did you mean IFS=\{tab_hint} ?",
    )
    return
  }
  if text.contains("\\") {
    analytics_warn_suspicious_ifs(span, "a literal backslash", diagnostics)
    return
  }
  if text.contains("n") {
    analytics_warn_suspicious_ifs(span, "the literal letter 'n'", diagnostics)
    return
  }
  if text.contains("t") {
    analytics_warn_suspicious_ifs(span, "the literal letter 't'", diagnostics)
  }
}

///|
fn analytics_warn_suspicious_ifs(
  span : @parser.Span,
  desc : String,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  push_diagnostic(
    diagnostics,
    span,
    CheckSeverity::Warning,
    2141,
    "This IFS value contains \{desc}. For tabs/linefeeds/escapes, use $'..', literal, or printf.",
  )
}

///|
fn check_tilde_in_path(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        for assignment in simple.assignments {
          match assignment.value {
            @parser.AssignmentValue::Word(value) =>
              if assignment.name == "PATH" &&
                !assignment.append &&
                assignment.indexes.length() == 0 {
                if analytics_word_has_quoted_tilde(value) {
                  push_diagnostic(
                    diagnostics,
                    assignment.span,
                    CheckSeverity::Warning,
                    2147,
                    "Literal tilde in PATH works poorly across programs.",
                  )
                }
              }
            _ => ()
          }
        }
      _ => ()
    }
  })
}

///|
fn check_overriding_path(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        if simple.words.length() == 0 {
          for assignment in simple.assignments {
            h_maybe_warn_overriding_path(assignment, diagnostics)
          }
        }
      _ => ()
    }
  })
}

///|
fn h_maybe_warn_overriding_path(
  assignment : @parser.Assignment,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard assignment.name == "PATH" &&
    !assignment.append &&
    assignment.indexes.length() == 0 else {
    return
  }
  let value = match assignment.value {
    @parser.AssignmentValue::Word(value) => value
    _ => return
  }
  let text = value.source
  guard !text.contains("/bin") && !text.contains("/sbin") else { return }
  if text.contains("/") && !text.contains(":") {
    push_diagnostic(
      diagnostics,
      assignment_name_span(assignment),
      CheckSeverity::Warning,
      2123,
      "PATH is the shell search path. Use another name.",
    )
    return
  }
  if @semantics.literal_text(value) is Some(_) &&
    !text.contains(":") &&
    !text.contains("/") {
    push_diagnostic(
      diagnostics,
      assignment_name_span(assignment),
      CheckSeverity::Warning,
      2123,
      "PATH is the shell search path. Use another name.",
    )
  }
}

///|
fn analytics_word_has_quoted_tilde(word : @parser.Word) -> Bool {
  for part in word.parts {
    if analytics_word_part_has_quoted_tilde(part, false) {
      return true
    }
  }
  false
}

///|
fn analytics_word_part_has_quoted_tilde(
  part : @parser.WordPart,
  quoted : Bool,
) -> Bool {
  match part {
    @parser.WordPart::Literal(text) => quoted && text.contains("~")
    @parser.WordPart::SingleQuoted(text)
    | @parser.WordPart::DollarSingleQuoted(text) => text.contains("~")
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      parts.any(fn(part) { analytics_word_part_has_quoted_tilde(part, true) })
    _ => false
  }
}
