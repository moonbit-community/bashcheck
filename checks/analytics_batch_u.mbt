///|
fn append_analytics_batch_u_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_u_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_u_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2009,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Consider using pgrep instead of grepping ps output.",
    },
    {
      code: 2010,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Don't use ls | grep for filtering filenames.",
    },
    {
      code: 2011,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Prefer find -print0/-exec+ over ls | xargs.",
    },
    {
      code: 2012,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Use find instead of ls for safer filename handling.",
    },
    {
      code: 2013,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Use while read for line-oriented command substitutions in loops.",
    },
    {
      code: 2014,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "find -exec arguments expand once before find runs.",
    },
    {
      code: 2038,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use find -print0/-exec+ with xargs to handle filenames safely.",
    },
    {
      code: 2067,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "find -exec requires a separate ';' or '+' terminator.",
    },
    {
      code: 2126,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Consider using grep -c instead of grep piped to wc -l.",
    },
  ]
}

///|
fn run_analytics_batch_u_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_pipeline_pitfalls_u(script, diagnostics)
  check_for_in_line_based_commands_u(script, diagnostics)
  check_find_exec_u(script, diagnostics)
}

///|
fn check_pipeline_pitfalls_u(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_pipelines(script, fn(pipeline) {
    guard pipeline.segments.length() >= 2 else { return }
    let mut saw_ls_specific_warning = false
    let mut i = 0
    while i + 1 < pipeline.segments.length() {
      let lhs = pipeline.segments[i].command
      let rhs = pipeline.segments[i + 1].command
      match
        (@semantics.command_basename(lhs), @semantics.command_basename(rhs)) {
        (Some("find"), Some("xargs")) =>
          if find_xargs_needs_null_safety_u(lhs, rhs) {
            push_diagnostic(
              diagnostics,
              command_words_span_u(lhs),
              CheckSeverity::Warning,
              2038,
              "Use 'find .. -print0 | xargs -0 ..' or 'find .. -exec .. +' to allow non-alphanumeric filenames.",
            )
          }
        (Some("ps"), Some("grep")) =>
          if !ps_has_pid_filter_u(lhs) {
            push_diagnostic(
              diagnostics,
              command_words_span_u(lhs),
              CheckSeverity::Info,
              2009,
              "Consider using pgrep instead of grepping ps output.",
            )
          }
        (Some("grep"), Some("wc")) =>
          if grep_wc_prefers_count_flag_u(lhs, rhs) {
            push_diagnostic(
              diagnostics,
              command_words_span_u(lhs),
              CheckSeverity::Style,
              2126,
              "Consider using 'grep -c' instead of 'grep|wc -l'.",
            )
          }
        (Some("ls"), Some("grep")) => {
          saw_ls_specific_warning = true
          push_diagnostic(
            diagnostics,
            command_words_span_u(lhs),
            CheckSeverity::Warning,
            2010,
            "Don't use ls | grep. Use a glob or a for loop with a condition to allow non-alphanumeric filenames.",
          )
        }
        (Some("ls"), Some("xargs")) => {
          saw_ls_specific_warning = true
          push_diagnostic(
            diagnostics,
            command_words_span_u(lhs),
            CheckSeverity::Warning,
            2011,
            "Use 'find .. -print0 | xargs -0 ..' or 'find .. -exec .. +' to allow non-alphanumeric filenames.",
          )
        }
        _ => ()
      }
      i += 1
    }

    if saw_ls_specific_warning {
      return
    }

    i = 0
    while i + 1 < pipeline.segments.length() {
      let command = pipeline.segments[i].command
      if @semantics.command_basename(command) == Some("ls") &&
        !command_has_short_flag_u(command, 'N') {
        push_diagnostic(
          diagnostics,
          command_words_span_u(command),
          CheckSeverity::Info,
          2012,
          "Use find instead of ls to better handle non-alphanumeric filenames.",
        )
      }
      i += 1
    }
  })
}

///|
fn find_xargs_needs_null_safety_u(
  find_command : @parser.Command,
  xargs_command : @parser.Command,
) -> Bool {
  let words = literal_command_words_u(find_command)
  for word in literal_command_words_u(xargs_command) {
    words.push(word)
  }
  !words_have_short_flag_u(words, '0') &&
  !words_have_named_flag_u(words, "null") &&
  !words_have_named_flag_u(words, "print0") &&
  !words_have_named_flag_u(words, "printf")
}

///|
fn literal_command_words_u(command : @parser.Command) -> Array[String] {
  let words : Array[String] = []
  for word in @semantics.command_words(command) {
    match @semantics.literal_text(word) {
      Some(text) => words.push(text)
      None => ()
    }
  }
  words
}

///|
fn words_have_short_flag_u(words : Array[String], flag : Char) -> Bool {
  for word in words {
    if short_option_cluster_contains(word, flag) {
      return true
    }
  }
  false
}

///|
fn words_have_named_flag_u(words : Array[String], name : String) -> Bool {
  for word in words {
    if text_has_named_flag_u(word, name) {
      return true
    }
  }
  false
}

///|
fn text_has_named_flag_u(text : String, name : String) -> Bool {
  let trimmed = trim_leading_dashes_u(text)
  trimmed.has_prefix(name)
}

///|
fn trim_leading_dashes_u(text : String) -> String {
  let view = text[:]
  let mut i = 0
  while i < view.length() && view[i] == '-' {
    i += 1
  }
  text.view(start_offset=i).to_string()
}

///|
fn ps_has_pid_filter_u(command : @parser.Command) -> Bool {
  for argument in @semantics.command_arguments(command) {
    let text = match @semantics.literal_text(argument) {
      Some(text) => text
      None => continue
    }
    if ["-p", "-q", "--pid", "--quick-pid"].contains(text) ||
      text.has_prefix("--pid=") ||
      text.has_prefix("--quick-pid=") ||
      short_option_cluster_contains(text, 'p') ||
      short_option_cluster_contains(text, 'q') {
      return true
    }
  }
  false
}

///|
fn grep_wc_prefers_count_flag_u(
  grep_command : @parser.Command,
  wc_command : @parser.Command,
) -> Bool {
  !grep_has_counting_exception_u(grep_command) &&
  wc_has_explicit_line_count_only_u(wc_command)
}

///|
fn grep_has_counting_exception_u(command : @parser.Command) -> Bool {
  for argument in @semantics.command_arguments(command) {
    let text = match @semantics.literal_text(argument) {
      Some(text) => text
      None => continue
    }
    if short_option_cluster_contains(text, 'l') ||
      short_option_cluster_contains(text, 'L') ||
      short_option_cluster_contains(text, 'o') ||
      short_option_cluster_contains(text, 'r') ||
      short_option_cluster_contains(text, 'R') ||
      short_option_cluster_contains(text, 'A') ||
      short_option_cluster_contains(text, 'B') ||
      text_has_named_flag_u(text, "files-with-matches") ||
      text_has_named_flag_u(text, "files-without-matches") ||
      text_has_named_flag_u(text, "only-matching") ||
      text_has_named_flag_u(text, "recursive") ||
      text_has_named_flag_u(text, "after-context") ||
      text_has_named_flag_u(text, "before-context") {
      return true
    }
  }
  false
}

///|
fn wc_has_explicit_line_count_only_u(command : @parser.Command) -> Bool {
  let mut saw_flag = false
  for argument in @semantics.command_arguments(command) {
    let text = match @semantics.literal_text(argument) {
      Some(text) => text
      None => continue
    }
    if text == "-" || !text.has_prefix("-") {
      continue
    }
    saw_flag = true
    if short_option_cluster_contains(text, 'm') ||
      short_option_cluster_contains(text, 'w') ||
      short_option_cluster_contains(text, 'c') ||
      short_option_cluster_contains(text, 'L') ||
      text_has_named_flag_u(text, "chars") ||
      text_has_named_flag_u(text, "words") ||
      text_has_named_flag_u(text, "bytes") ||
      text_has_named_flag_u(text, "max-line-length") {
      return false
    }
  }
  saw_flag
}

///|
fn command_has_short_flag_u(command : @parser.Command, flag : Char) -> Bool {
  for argument in @semantics.command_arguments(command) {
    match @semantics.literal_text(argument) {
      Some(text) if short_option_cluster_contains(text, flag) => return true
      _ => ()
    }
  }
  false
}

///|
fn command_words_span_u(command : @parser.Command) -> @parser.Span {
  let words = @semantics.command_words(command)
  match (words.get(0), words.get(words.length() - 1)) {
    (Some(first), Some(last)) =>
      @parser.Span::new(first.span.start, last.span.end)
    _ => command.span
  }
}

///|
fn check_for_in_line_based_commands_u(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::ForIn(clause) =>
        match clause.values {
          [word] =>
            match word_single_top_level_substitution_script(word) {
              Some(subscript) if script_is_line_based_pipeline_u(subscript) =>
                push_diagnostic(
                  diagnostics,
                  word.span,
                  CheckSeverity::Info,
                  2013,
                  "To read lines rather than words, pipe/redirect to a 'while read' loop.",
                )
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn script_is_line_based_pipeline_u(script : @parser.Script) -> Bool {
  match script.items {
    [item] if item.and_or.tail.length() == 0 =>
      pipeline_is_line_based_u(item.and_or.head)
    _ => false
  }
}

///|
fn pipeline_is_line_based_u(pipeline : @parser.Pipeline) -> Bool {
  guard pipeline.segments.length() > 0 else { return false }
  for segment in pipeline.segments {
    match @semantics.command_basename(segment.command) {
      Some(name) if line_based_command_name_u(name) => ()
      _ => return false
    }
  }
  true
}

///|
fn line_based_command_name_u(name : String) -> Bool {
  ["grep", "fgrep", "egrep", "sed", "cat", "awk", "cut", "sort"].contains(name)
}

///|
fn check_find_exec_u(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_basename(command, "find") else { return }
    let arguments = @semantics.effective_command_arguments(command)
    let mut in_exec = false
    for argument in arguments {
      if in_exec {
        maybe_push_find_exec_preexpansion_u(argument, diagnostics)
      }
      match @semantics.literal_text(argument) {
        Some(text) if find_exec_operator_name_u(text) => in_exec = true
        Some("+") | Some(";") => in_exec = false
        _ => ()
      }
    }
    if in_exec && arguments.length() > 0 {
      push_diagnostic(
        diagnostics,
        arguments[arguments.length() - 1].span,
        CheckSeverity::Error,
        2067,
        "Missing ';' or + terminating -exec. You can't use |/||/&&, and ';' has to be a separate, quoted argument.",
      )
    }
  })
}

///|
fn find_exec_operator_name_u(text : String) -> Bool {
  ["-exec", "-execdir", "-ok", "-okdir"].contains(text)
}

///|
fn maybe_push_find_exec_preexpansion_u(
  word : @parser.Word,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match find_exec_preexpansion_span_u(word) {
    Some(span) =>
      push_diagnostic(
        diagnostics,
        span,
        CheckSeverity::Info,
        2014,
        "This will expand once before find runs, not per file found.",
      )
    None => ()
  }
}

///|
fn find_exec_preexpansion_span_u(word : @parser.Word) -> @parser.Span? {
  for part in word.parts {
    match part {
      @parser.WordPart::CommandSubstitution(_)
      | @parser.WordPart::BraceCommandSubstitution(_, _)
      | @parser.WordPart::BackQuoted(_) =>
        return Some(command_substitution_span_u(word))
      @parser.WordPart::Glob(text) =>
        return Some(glob_indicator_span_u(word, text))
      @parser.WordPart::ExtGlob(_) => return Some(span_prefix(word.span, 1))
      _ => ()
    }
  }
  None
}

///|
fn command_substitution_span_u(word : @parser.Word) -> @parser.Span {
  match command_substitution_range_u(word.source) {
    Some((offset, width)) => analytics_span_offset(word.span, offset, width)
    None => word.span
  }
}

///|
fn command_substitution_range_u(text : String) -> (Int, Int)? {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    if view[i] == '`' {
      let start = i
      i += 1
      while i < view.length() {
        if view[i] == '`' {
          return Some((start, i - start + 1))
        }
        i += 1
      }
      return Some((start, view.length() - start))
    }
    if i + 1 < view.length() && view[i] == '$' && view[i + 1] == '(' {
      let start = i
      let mut depth = 1
      i += 2
      while i < view.length() {
        if i + 1 < view.length() && view[i] == '$' && view[i + 1] == '(' {
          depth += 1
          i += 2
          continue
        }
        if view[i] == ')' {
          depth -= 1
          if depth == 0 {
            return Some((start, i - start + 1))
          }
        }
        i += 1
      }
      return Some((start, view.length() - start))
    }
    i += 1
  }
  None
}

///|
fn glob_indicator_span_u(word : @parser.Word, text : String) -> @parser.Span {
  let marker = match first_glob_indicator_u(text) {
    Some(marker) => marker
    None => return word.span
  }
  match analytics_string_offset(word.source, marker) {
    Some(offset) => analytics_span_offset(word.span, offset, marker.length())
    None => word.span
  }
}

///|
fn first_glob_indicator_u(text : String) -> String? {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    if view[i] == '*' || view[i] == '?' || view[i] == '[' {
      return Some(uint16_to_string(view[i]))
    }
    i += 1
  }
  None
}
