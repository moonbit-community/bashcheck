///|
fn append_analytics_batch_j_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_j_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_j_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2256,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Translated strings that are variable names should be quoted as substitutions.",
    },
    {
      code: 2268,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "x-prefixes in comparisons no longer need to be written.",
    },
    {
      code: 2283,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Remove spaces around = when assigning or compare with [ ].",
    },
    {
      code: 2284,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Use [ x = y ] for comparisons, not a spaced == word.",
    },
    {
      code: 2285,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Remove spaces around += when assigning.",
    },
  ]
}

///|
fn run_analytics_batch_j_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_translated_string_variable(script, diagnostics)
  check_comparison_with_leading_x(script, diagnostics)
  check_second_arg_is_comparison(script, diagnostics)
}

///|
fn check_translated_string_variable(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let assigned_names : Array[String] = []
  analytics_collect_assigned_names(script, assigned_names)
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      match word.parts {
        [
          @parser.WordPart::DollarDoubleQuoted(
            [@parser.WordPart::Literal(text)]
          ),
        ] if analytics_word_is_variable_name(text) &&
          assigned_names.contains(text) =>
          push_diagnostic_with_fix(
            diagnostics,
            word.span,
            CheckSeverity::Warning,
            2256,
            "This translated string is the name of a variable. Flip leading $ and \" if this should be a quoted substitution.",
            analytics_replace_prefix_fix(word.span, 2, "\"$"),
          )
        _ => ()
      }
    })
  })
}

///|
fn analytics_collect_assigned_names(
  script : @parser.Script,
  names : Array[String],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        for assignment in simple.assignments {
          analytics_push_unique_name(names, assignment.name)
        }
      @parser.CommandKind::Source(source) =>
        for assignment in source.assignments {
          analytics_push_unique_name(names, assignment.name)
        }
      _ => ()
    }
  })
}

///|
fn analytics_word_is_variable_name(text : String) -> Bool {
  is_identifier_name(text)
}

///|
fn check_comparison_with_leading_x(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match analytics_command_condition_binary(command) {
      Some(binary) if binary.op == "=" || binary.op == "==" || binary.op == "!=" => {
        let precedence = analytics_comparison_fix_precedence(command)
        match analytics_leading_x_replacement(binary.lhs, precedence) {
          Some(lhs_fix) =>
            match analytics_leading_x_replacement(binary.rhs, precedence) {
              Some(rhs_fix) =>
                push_diagnostic_with_fix(
                  diagnostics,
                  binary.lhs.span,
                  CheckSeverity::Style,
                  2268,
                  "Avoid x-prefix in comparisons as it no longer serves a purpose.",
                  @fixer.Fix::from_replacements([lhs_fix, rhs_fix]),
                )
              None => ()
            }
          None => ()
        }
      }
      _ => ()
    }
  })
}

///|
fn analytics_leading_x_replacement(
  word : @parser.Word,
  precedence : Int,
) -> @fixer.Replacement? {
  match word.parts {
    [@parser.WordPart::SingleQuoted(text), ..] if analytics_text_starts_with_x(
        text,
      ) =>
      return Some(
        @fixer.Replacement::new(
          "",
          word.span.start,
          analytics_position_offset(word.span.start, 2),
          "'",
          precedence,
          @fixer.InsertionPoint::after(),
        ),
      )
    _ => ()
  }
  match analytics_leading_x_offset(word.parts, 0) {
    Some(offset) => {
      let text = if word.source.length() == 1 { "\"\"" } else { "" }
      let start = analytics_position_offset(word.span.start, offset)
      let end = analytics_position_offset(start, 1)
      Some(
        @fixer.Replacement::new(
          "",
          start,
          end,
          text,
          precedence,
          @fixer.InsertionPoint::after(),
        ),
      )
    }
    None => None
  }
}

///|
fn analytics_comparison_fix_precedence(command : @parser.Command) -> Int {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      match simple.words {
        [name, ..] if @semantics.literal_text(name) == Some("test") => 7
        _ => 8
      }
    _ => 8
  }
}

///|
fn analytics_leading_x_offset(
  parts : Array[@parser.WordPart],
  prefix_offset : Int,
) -> Int? {
  match parts {
    [] => None
    [@parser.WordPart::Literal(text), ..] =>
      if analytics_text_starts_with_x(text) {
        Some(prefix_offset)
      } else {
        None
      }
    [@parser.WordPart::SingleQuoted(text), ..] =>
      if analytics_text_starts_with_x(text) {
        Some(prefix_offset + 1)
      } else {
        None
      }
    [@parser.WordPart::DoubleQuoted(nested), ..] =>
      analytics_leading_x_offset(nested, prefix_offset + 1)
    [@parser.WordPart::DollarDoubleQuoted(nested), ..] =>
      analytics_leading_x_offset(nested, prefix_offset + 2)
    _ => None
  }
}

///|
fn analytics_text_starts_with_x(text : String) -> Bool {
  let view = text[:]
  if view.length() == 0 {
    return false
  }
  let first = view[0].unsafe_to_char()
  first == 'x' || first == 'X'
}

///|
fn check_second_arg_is_comparison(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        match simple.words {
          [_, arg, ..] =>
            match @semantics.leading_unquoted_text(arg) {
              Some(text) if !text.has_prefix("====") =>
                analytics_push_second_arg_comparison(
                  command, arg, text, diagnostics,
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
fn analytics_push_second_arg_comparison(
  command : @parser.Command,
  arg : @parser.Word,
  arg_text : String,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if arg_text.has_prefix("+=") {
    push_diagnostic(
      diagnostics,
      command.span,
      CheckSeverity::Error,
      2285,
      "Remove spaces around += to assign (or quote '+=' if literal).",
    )
    return
  }
  if arg_text.has_prefix("==") {
    push_diagnostic(
      diagnostics,
      command.span,
      CheckSeverity::Error,
      2284,
      "Use [ x = y ] to compare values (or quote '==' if literal).",
    )
    return
  }
  if arg_text.has_prefix("=") {
    push_diagnostic(
      diagnostics,
      arg.span,
      CheckSeverity::Error,
      2283,
      "Remove spaces around = to assign (or use [ ] to compare, or quote '=' if literal).",
    )
  }
}

///|
fn analytics_position_offset(
  position : @parser.Position,
  delta : Int,
) -> @parser.Position {
  @parser.Position::new(
    position.offset + delta,
    position.line,
    position.column + delta,
  )
}

///|
fn analytics_replace_prefix_fix(
  span : @parser.Span,
  width : Int,
  text : String,
) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      span.start,
      analytics_position_offset(span.start, width),
      text,
      7,
      @fixer.InsertionPoint::after(),
    ),
  ])
}
