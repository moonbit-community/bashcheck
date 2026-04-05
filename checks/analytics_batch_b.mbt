///|
fn append_analytics_batch_b_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_b_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_b_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2049,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use = instead of =~ when the right-hand side is a glob.",
    },
    {
      code: 2053,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Quote variable right-hand sides in [[ ]] string comparisons.",
    },
    {
      code: 2065,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "test < and > are redirections, not comparison operators.",
    },
    {
      code: 2081,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "[ .. ] does not support glob matching.",
    },
    {
      code: 2083,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Do not write ./ with a separating space before the path.",
    },
    {
      code: 2099,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use $((..)) for arithmetic instead of invoking + - * / as commands.",
    },
    {
      code: 2100,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use $((..)) for arithmetic-looking assignments.",
    },
    {
      code: 2210,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Numeric redirection targets are files unless you use fd duplication syntax.",
    },
    {
      code: 2211,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "A glob used as a command name is probably a syntax mistake.",
    },
    {
      code: 2212,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Use false instead of an empty [ ] or [[ ]] condition.",
    },
    {
      code: 2215,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "A flag at command position is usually a bad line break or missing test brackets.",
    },
    {
      code: 2238,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Redirect to a file path, not what looks like a command name.",
    },
    {
      code: 2286,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "An empty string command name is usually a syntax error.",
    },
    {
      code: 2287,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Command names ending in / usually indicate malformed syntax.",
    },
    {
      code: 2288,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Suspicious trailing punctuation in a command name likely indicates malformed syntax.",
    },
    {
      code: 2289,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Tabs or linefeeds inside a command name indicate malformed syntax.",
    },
    {
      code: 2327,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Redirecting output inside a command substitution can make it capture nothing.",
    },
    {
      code: 2328,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "This redirection steals output from the surrounding command substitution.",
    },
    {
      code: 2330,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "BusyBox [[ .. ]] does not support glob matching.",
    },
  ]
}

///|
fn run_analytics_batch_b_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_globbed_regex(script, diagnostics)
  check_comparison_against_glob(script, shell, diagnostics)
  check_test_redirects(script, diagnostics)
  check_lonely_dot_dash(script, diagnostics)
  check_arithmetic_op_command(script, diagnostics)
  check_wrong_arithmetic_assignment(script, diagnostics)
  check_redirection_to_number(script, diagnostics)
  check_glob_as_command(script, diagnostics)
  check_flag_as_command(script, diagnostics)
  check_empty_condition(script, diagnostics)
  check_redirection_to_command(script, diagnostics)
  check_command_with_trailing_symbol(script, diagnostics)
  check_expansion_with_redirection(script, diagnostics)
}

///|
fn check_globbed_regex(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        match condition.kind {
          @parser.ConditionKind::DoubleBracket =>
            visit_condition_binaries(condition.expr, fn(op, _, rhs) {
              if op == "=~" && word_looks_like_glob_regex_confusion(rhs) {
                push_diagnostic(
                  diagnostics,
                  rhs.span,
                  CheckSeverity::Warning,
                  2049,
                  "=~ is for regex, but this looks like a glob. Use = instead.",
                )
              }
            })
          @parser.ConditionKind::SingleBracket => ()
        }
      _ => ()
    }
  })
}

///|
fn check_comparison_against_glob(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        visit_condition_binaries(condition.expr, fn(op, _, rhs) {
          if op != "=" && op != "==" && op != "!=" {
            return
          }
          match condition.kind {
            @parser.ConditionKind::DoubleBracket =>
              if word_is_plain_parameter_reference(rhs) {
                push_diagnostic(
                  diagnostics,
                  rhs.span,
                  CheckSeverity::Warning,
                  2053,
                  "Quote the right-hand side of \{op} in [[ ]] to prevent glob matching.",
                )
              } else if shell == @semantics.ShellDialect::BusyboxSh &&
                @semantics.is_glob_word(rhs) {
                push_diagnostic(
                  diagnostics,
                  rhs.span,
                  CheckSeverity::Error,
                  2330,
                  "BusyBox [[ .. ]] does not support glob matching. Use a case statement.",
                )
              }
            @parser.ConditionKind::SingleBracket =>
              if @semantics.is_glob_word(rhs) {
                push_diagnostic(
                  diagnostics,
                  rhs.span,
                  CheckSeverity::Error,
                  2081,
                  single_bracket_glob_message(shell),
                )
              }
          }
        })
      _ => ()
    }
  })
}

///|
fn check_test_redirects(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_basename(command, "test") else { return }
    for redirect in command.redirects {
      if test_redirect_is_suspicious(redirect) {
        push_diagnostic(
          diagnostics,
          redirect.span,
          CheckSeverity::Warning,
          2065,
          "This is interpreted as a shell file redirection, not a comparison.",
        )
      }
    }
  })
}

///|
fn check_lonely_dot_dash(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        match simple.words.get(0) {
          Some(word) if word_single_literal_text(word) == Some("./") =>
            push_diagnostic(
              diagnostics,
              word.span,
              CheckSeverity::Error,
              2083,
              "Don't add spaces after the slash in './file'.",
            )
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn check_arithmetic_op_command(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) if simple.assignments.length() == 1 &&
        simple.words.length() > 0 =>
        match word_literal_or_glob_text(simple.words[0]) {
          Some(op) if op == "+" || op == "-" || op == "*" || op == "/" =>
            push_diagnostic(
              diagnostics,
              simple.words[0].span,
              CheckSeverity::Warning,
              2099,
              "Use $((..)) for arithmetics, e.g. i=$((i \{op} 2))",
            )
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn check_wrong_arithmetic_assignment(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let seen_names : Array[String] = []
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) => {
        if simple.assignments.length() == 1 && simple.words.length() == 0 {
          let assignment = simple.assignments[0]
          match assignment.value {
            @parser.AssignmentValue::Word(word) =>
              match
                arithmetic_assignment_reference(
                  word,
                  assignment.name,
                  seen_names,
                ) {
                Some(op) =>
                  push_diagnostic(
                    diagnostics,
                    word.span,
                    CheckSeverity::Warning,
                    2100,
                    "Use $((..)) for arithmetics, e.g. i=$((i \{op} 2))",
                  )
                None => ()
              }
            _ => ()
          }
        }
        for assignment in simple.assignments {
          push_unique_string(seen_names, assignment.name)
        }
      }
      @parser.CommandKind::Source(source) =>
        for assignment in source.assignments {
          push_unique_string(seen_names, assignment.name)
        }
      _ => ()
    }
  })
}

///|
fn check_redirection_to_number(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if command_matches_basename(command, "test") {
      return
    }
    for redirect in command.redirects {
      if redirection_points_to_plain_number(redirect) {
        push_diagnostic(
          diagnostics,
          redirect.span,
          CheckSeverity::Warning,
          2210,
          "This is a file redirection. Was it supposed to be a comparison or fd operation?",
        )
      }
    }
  })
}

///|
fn check_glob_as_command(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        match simple.words.get(0) {
          Some(word) if @semantics.is_glob_word(word) =>
            push_diagnostic(
              diagnostics,
              word.span,
              CheckSeverity::Warning,
              2211,
              "This is a glob used as a command name. Was it supposed to be in ${..}, array, or is it missing quoting?",
            )
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn check_flag_as_command(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let suppressed = subshell_test_inner_command_spans(script)
  visit_script_commands(script, fn(command) {
    if suppressed.contains(command.span) {
      return
    }
    match command.kind {
      @parser.CommandKind::Simple(simple) if simple.assignments.length() == 0 &&
        simple.words.length() > 0 => {
        let first = simple.words[0]
        if @semantics.is_unquoted_flag(first) {
          push_diagnostic(
            diagnostics,
            first.span,
            CheckSeverity::Warning,
            2215,
            "This flag is used as a command name. Bad line break or missing [ .. ]?",
          )
        }
      }
      _ => ()
    }
  })
}

///|
fn check_empty_condition(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        match condition.expr {
          @parser.ConditionExpr::Empty =>
            push_diagnostic(
              diagnostics,
              command.span,
              CheckSeverity::Style,
              2212,
              "Use 'false' instead of empty [/[[ conditionals.",
            )
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn check_redirection_to_command(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let common_commands = @semantics.common_command_names()
  visit_script_commands(script, fn(command) {
    for redirect in command.redirects {
      match redirect.target {
        @parser.RedirectionTarget::Word(word) =>
          match word_single_literal_text(word) {
            Some(name) if name != "file" &&
              common_commands.any(fn(command_name) { command_name == name }) =>
              push_diagnostic(
                diagnostics,
                word.span,
                CheckSeverity::Warning,
                2238,
                "Redirecting to/from command name instead of file. Did you want pipes/xargs (or quote to ignore)?",
              )
            _ => ()
          }
        @parser.RedirectionTarget::HereDoc(_) => ()
      }
    }
  })
}

///|
fn check_command_with_trailing_symbol(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        match simple.words.get(0) {
          Some(word) =>
            match command_name_issue(word) {
              Some((severity, code, message)) =>
                push_diagnostic(diagnostics, word.span, severity, code, message)
              None => ()
            }
          None => ()
        }
      _ => ()
    }
  })
}

///|
fn check_expansion_with_redirection(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      walk_word_deep(word, fn(part) {
        match part {
          @parser.WordPart::CommandSubstitution(inner)
          | @parser.WordPart::BraceCommandSubstitution(_, inner)
          | @parser.WordPart::BackQuoted(inner) =>
            check_substitution_redirects(word.span, inner, diagnostics)
          _ => ()
        }
      })
    })
  })
}

///|
fn visit_condition_binaries(
  expr : @parser.ConditionExpr,
  visit : (String, @parser.Word, @parser.Word) -> Unit,
) -> Unit {
  match expr {
    @parser.ConditionExpr::Binary(op, lhs, rhs) => visit(op, lhs, rhs)
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      visit_condition_binaries(inner, visit)
    @parser.ConditionExpr::And(lhs, rhs)
    | @parser.ConditionExpr::Or(lhs, rhs) => {
      visit_condition_binaries(lhs, visit)
      visit_condition_binaries(rhs, visit)
    }
    _ => ()
  }
}

///|
fn word_looks_like_glob_regex_confusion(word : @parser.Word) -> Bool {
  let text = word.source
  if text == "" || !has_unescaped_glob_operator(text) {
    return false
  }
  if text.contains("\\") ||
    text.contains("^") ||
    text.contains(".") ||
    text.contains("+") ||
    text.contains("(") ||
    text.contains("[") ||
    text.contains("|") {
    return false
  }
  let star_count = count_unescaped_char(text, '*')
  if has_unescaped_question(text) {
    return true
  }
  if star_count >= 2 {
    return true
  }
  starts_with_unescaped_char(text, '*') || ends_with_unescaped_char(text, '*')
}

///|
fn word_is_plain_parameter_reference(word : @parser.Word) -> Bool {
  match word.parts {
    [@parser.WordPart::Parameter(_)] => true
    [@parser.WordPart::BracedParameter(expansion)] =>
      !expansion.length_prefix &&
      !expansion.indirect &&
      !parameter_has_index(expansion) &&
      expansion.operator is None &&
      expansion.name is Some(_)
    _ => false
  }
}

///|
fn single_bracket_glob_message(shell : @semantics.ShellDialect) -> String {
  if shell == @semantics.ShellDialect::Bash ||
    shell == @semantics.ShellDialect::Ksh {
    "[ .. ] can't match globs. Use [[ .. ]] or case statement."
  } else {
    "[ .. ] can't match globs. Use a case statement."
  }
}

///|
fn test_redirect_is_suspicious(redirect : @parser.Redirection) -> Bool {
  if !redirection_is_read_or_write(redirect.op) {
    return false
  }
  match redirect.source {
    Some(@parser.RedirectionSource::Fd(2)) => false
    _ => true
  }
}

///|
fn word_literal_or_glob_text(word : @parser.Word) -> String? {
  match word.parts {
    [@parser.WordPart::Literal(text)] | [@parser.WordPart::Glob(text)] =>
      Some(text)
    _ => None
  }
}

///|
fn word_single_literal_text(word : @parser.Word) -> String? {
  match word.parts {
    [@parser.WordPart::Literal(text)] => Some(text)
    _ => None
  }
}

///|
fn arithmetic_assignment_reference(
  word : @parser.Word,
  current_name : String,
  seen_names : Array[String],
) -> String? {
  let text = match word_unquoted_plain_text(word) {
    Some(text) => text
    None => return None
  }
  let parsed = match leading_variable_arithmetic_op(text) {
    Some(parsed) => parsed
    None => return None
  }
  let (name, op) = parsed
  if name == current_name || seen_names.contains(name) {
    return Some(op)
  }
  None
}

///|
fn word_unquoted_plain_text(word : @parser.Word) -> String? {
  let buf = StringBuilder::new()
  for part in word.parts {
    match part {
      @parser.WordPart::Literal(text) | @parser.WordPart::Glob(text) =>
        buf.write_string(text)
      _ => return None
    }
  }
  Some(buf.to_string())
}

///|
fn leading_variable_arithmetic_op(text : String) -> (String, String)? {
  let view = text[:]
  guard view.length() >= 3 else { return None }
  guard is_ascii_name_start(view[0]) else { return None }
  let mut i = 1
  while i < view.length() && is_ascii_name_part(view[i]) {
    i += 1
  }
  guard i + 1 < view.length() else { return None }
  let op = view[i]
  guard op == '+' || op == '-' || op == '*' || op == '/' else { return None }
  Some((text.view(end_offset=i).to_string(), uint16_to_string(op)))
}

///|
fn push_unique_string(values : Array[String], value : String) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
fn redirection_points_to_plain_number(redirect : @parser.Redirection) -> Bool {
  if redirection_is_dup_redirect(redirect.op) {
    return false
  }
  match redirect.target {
    @parser.RedirectionTarget::Word(word) =>
      match word_single_literal_text(word) {
        Some(text) => string_is_digits(text)
        None => false
      }
    @parser.RedirectionTarget::HereDoc(_) => false
  }
}

///|
fn command_name_issue(word : @parser.Word) -> (CheckSeverity, Int, String)? {
  guard !@semantics.is_glob_word(word) else { return None }
  if word_single_literal_text(word) == Some("./") {
    return None
  }
  let text = match @semantics.literal_text(word) {
    Some(text) => text
    None => return None
  }
  guard text != "." && text != ":" && text != " " && text != "//" else {
    return None
  }
  if text == "" {
    return Some(
      (
        CheckSeverity::Error,
        2286,
        "This empty string is interpreted as a command name. Double check syntax (or use 'true' as a no-op).",
      ),
    )
  }
  if text.contains("\t") {
    return Some(
      (
        CheckSeverity::Error,
        2289,
        "This is interpreted as a command name containing a tab. Double check syntax.",
      ),
    )
  }
  if text.contains("\n") {
    return Some(
      (
        CheckSeverity::Error,
        2289,
        "This is interpreted as a command name containing a linefeed. Double check syntax.",
      ),
    )
  }
  let view = text[:]
  let last = view[view.length() - 1]
  if last == '/' {
    return Some(
      (
        CheckSeverity::Error,
        2287,
        "This is interpreted as a command name ending with '/'. Double check syntax.",
      ),
    )
  }
  if trailing_command_symbol_is_suspicious(last) {
    return Some(
      (
        CheckSeverity::Warning,
        2288,
        "This is interpreted as a command name ending with \{trailing_command_symbol_label(last)}. Double check syntax.",
      ),
    )
  }
  None
}

///|
fn trailing_command_symbol_is_suspicious(ch : UInt16) -> Bool {
  ch == '\\' ||
  ch == '.' ||
  ch == ',' ||
  ch == '(' ||
  ch == '[' ||
  ch == '{' ||
  ch == '<' ||
  ch == '>' ||
  ch == '}' ||
  ch == ']' ||
  ch == ')' ||
  ch == '#' ||
  ch == '"' ||
  ch == '\'' ||
  ch == '%' ||
  ch == ' '
}

///|
fn trailing_command_symbol_label(ch : UInt16) -> String {
  if ch == ' ' {
    "space"
  } else if ch == '\'' {
    "apostrophe"
  } else if ch == '"' {
    "doublequote"
  } else {
    "'\{uint16_to_string(ch)}'"
  }
}

///|
fn check_substitution_redirects(
  capture_span : @parser.Span,
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let pipeline = match single_pipeline_in_script(script) {
    Some(pipeline) => pipeline
    None => return
  }
  guard pipeline.segments.length() > 0 else { return }
  let last_command = pipeline.segments[pipeline.segments.length() - 1].command
  let mut stderr_captured = false
  for redirect in last_command.redirects {
    if redirect_duplicates_stderr_to_stdout(redirect) {
      stderr_captured = true
      continue
    }
    if !stderr_captured && redirect_removes_substitution_output(redirect) {
      push_diagnostic(
        diagnostics,
        capture_span,
        CheckSeverity::Warning,
        2327,
        "This command substitution will be empty because the command's output gets redirected away.",
      )
      push_diagnostic(
        diagnostics,
        redirect.span,
        CheckSeverity::Error,
        2328,
        redirection_steals_substitution_output_message(redirect),
      )
    }
  }
}

///|
fn single_pipeline_in_script(script : @parser.Script) -> @parser.Pipeline? {
  guard script.items.length() == 1 else { return None }
  let item = script.items[0]
  guard item.and_or.tail.length() == 0 else { return None }
  Some(item.and_or.head)
}

///|
fn subshell_test_inner_command_spans(
  script : @parser.Script,
) -> Array[@parser.Span] {
  let spans : Array[@parser.Span] = []
  let unary_ops = @semantics.unary_test_operators()
  let binary_ops = @semantics.binary_test_operators()
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Subshell(inner) =>
        match first_command_in_script(inner) {
          Some(inner_command) if command_looks_like_test(
              inner_command, unary_ops, binary_ops,
            ) => spans.push(inner_command.span)
          _ => ()
        }
      _ => ()
    }
  })
  spans
}

///|
fn command_looks_like_test(
  command : @parser.Command,
  unary_ops : Array[String],
  binary_ops : Array[String],
) -> Bool {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      match simple.words.get(0) {
        Some(first_word) =>
          match @semantics.literal_text(first_word) {
            Some(op) if unary_ops.any(fn(current) { current == op }) => true
            _ =>
              match simple.words.get(1) {
                Some(second_word) =>
                  match @semantics.literal_text(second_word) {
                    Some(op) if binary_ops.any(fn(current) { current == op }) =>
                      true
                    _ => false
                  }
                None => false
              }
          }
        None => false
      }
    _ => false
  }
}

///|
fn redirect_duplicates_stderr_to_stdout(redirect : @parser.Redirection) -> Bool {
  if !redirection_is_dup_output(redirect.op) {
    return false
  }
  match (redirect.source, redirect.target) {
    (
      Some(@parser.RedirectionSource::Fd(2)),
      @parser.RedirectionTarget::Word(word),
    ) => word_single_literal_text(word) == Some("1")
    _ => false
  }
}

///|
fn redirect_removes_substitution_output(redirect : @parser.Redirection) -> Bool {
  if redirect_retargets_stdout_to_file(redirect) {
    return true
  }
  if !redirection_is_dup_output(redirect.op) {
    return false
  }
  match redirect.source {
    None | Some(@parser.RedirectionSource::Fd(1)) =>
      match redirect.target {
        @parser.RedirectionTarget::Word(word) =>
          word_single_literal_text(word) != Some("1")
        @parser.RedirectionTarget::HereDoc(_) => false
      }
    _ => false
  }
}

///|
fn redirect_retargets_stdout_to_file(redirect : @parser.Redirection) -> Bool {
  if !redirection_is_stdout_file_redirect(redirect.op) {
    return false
  }
  match redirect.source {
    None | Some(@parser.RedirectionSource::Fd(1)) => true
    _ => false
  }
}

///|
fn redirection_steals_substitution_output_message(
  redirect : @parser.Redirection,
) -> String {
  if redirect_target_is_dev_null(redirect) {
    "This redirection takes output away from the command substitution."
  } else {
    "This redirection takes output away from the command substitution (use tee to duplicate)."
  }
}

///|
fn redirect_target_is_dev_null(redirect : @parser.Redirection) -> Bool {
  match redirect.target {
    @parser.RedirectionTarget::Word(word) =>
      word_single_literal_text(word) == Some("/dev/null")
    @parser.RedirectionTarget::HereDoc(_) => false
  }
}

///|
fn has_unescaped_glob_operator(text : String) -> Bool {
  has_unescaped_char(text, '*') || has_unescaped_question(text)
}

///|
fn has_unescaped_question(text : String) -> Bool {
  has_unescaped_char(text, '?')
}

///|
fn has_unescaped_char(text : String, target : UInt16) -> Bool {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch == '\\' && i + 1 < view.length() {
      i += 2
      continue
    }
    if ch == target {
      return true
    }
    i += 1
  }
  false
}

///|
fn count_unescaped_char(text : String, target : UInt16) -> Int {
  let view = text[:]
  let mut count = 0
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch == '\\' && i + 1 < view.length() {
      i += 2
      continue
    }
    if ch == target {
      count += 1
    }
    i += 1
  }
  count
}

///|
fn starts_with_unescaped_char(text : String, target : UInt16) -> Bool {
  let view = text[:]
  view.length() > 0 && view[0] == target
}

///|
fn ends_with_unescaped_char(text : String, target : UInt16) -> Bool {
  let view = text[:]
  view.length() > 0 && view[view.length() - 1] == target
}

///|
fn is_ascii_name_start(ch : UInt16) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

///|
fn is_ascii_name_part(ch : UInt16) -> Bool {
  is_ascii_name_start(ch) || is_ascii_digit(ch)
}

///|
fn is_ascii_digit(ch : UInt16) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn redirection_is_read_or_write(op : @parser.RedirectionOperator) -> Bool {
  match op {
    @parser.RedirectionOperator::Read | @parser.RedirectionOperator::Write =>
      true
    _ => false
  }
}

///|
fn redirection_is_dup_redirect(op : @parser.RedirectionOperator) -> Bool {
  match op {
    @parser.RedirectionOperator::DupInput
    | @parser.RedirectionOperator::DupOutput => true
    _ => false
  }
}

///|
fn redirection_is_dup_output(op : @parser.RedirectionOperator) -> Bool {
  match op {
    @parser.RedirectionOperator::DupOutput => true
    _ => false
  }
}

///|
fn redirection_is_stdout_file_redirect(
  op : @parser.RedirectionOperator,
) -> Bool {
  match op {
    @parser.RedirectionOperator::Write
    | @parser.RedirectionOperator::Append
    | @parser.RedirectionOperator::Clobber => true
    _ => false
  }
}

///|
fn string_is_digits(text : String) -> Bool {
  let view = text[:]
  if view.length() == 0 {
    return false
  }
  let mut i = 0
  while i < view.length() {
    if !is_ascii_digit(view[i]) {
      return false
    }
    i += 1
  }
  true
}
