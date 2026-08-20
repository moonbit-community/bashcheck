///|
fn append_analytics_batch_i_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_i_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_i_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2145,
      severity: Error,
      category: "analytics",
      summary: "Arguments should not mix string fragments with array expansions.",
    },
    {
      code: 2295,
      severity: Info,
      category: "analytics",
      summary: "Quote expansions inside ${..} pattern operators separately.",
    },
  ]
}

///|
fn run_analytics_batch_i_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_concatenated_dollar_at(script, diagnostics)
  check_unquoted_parameter_expansion_pattern(script, diagnostics)
}

///|
fn check_concatenated_dollar_at(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      if !analytics_word_has_mixed_array_and_string(word) {
        return
      }
      match analytics_word_first_array_span(word) {
        Some(span) =>
          push_diagnostic(
            diagnostics,
            span,
            Error,
            2145,
            "Argument mixes string and array. Use * or separate argument.",
          )
        None => ()
      }
    })
  })
}

///|
fn analytics_word_has_mixed_array_and_string(word : @parser.Word) -> Bool {
  let content = analytics_word_content(word.parts)
  content.has_array && content.has_other
}

///|
priv struct AnalyticsWordContent {
  has_array : Bool
  has_other : Bool
}

///|
fn analytics_word_content(
  parts : Array[@parser.WordPart],
) -> AnalyticsWordContent {
  let mut has_array = false
  let mut has_other = false
  for part in parts {
    let content = analytics_word_part_content(part)
    has_array = has_array || content.has_array
    has_other = has_other || content.has_other
  }
  { has_array, has_other }
}

///|
fn analytics_word_part_content(part : @parser.WordPart) -> AnalyticsWordContent {
  match part {
    SpecialParameter("@") => { has_array: true, has_other: false }
    BracedParameter(expansion) =>
      if braced_parameter_is_unquoted_array_expansion(expansion) {
        { has_array: true, has_other: false }
      } else {
        { has_array: false, has_other: true }
      }
    DoubleQuoted(parts) | DollarDoubleQuoted(parts) =>
      analytics_word_content(parts)
    _ => { has_array: false, has_other: true }
  }
}

///|
fn analytics_word_first_array_span(word : @parser.Word) -> @parser.Span? {
  for part in word.parts {
    match analytics_word_part_array_span(word, part) {
      Some(span) => return Some(span)
      None => ()
    }
  }
  None
}

///|
fn analytics_word_part_array_span(
  word : @parser.Word,
  part : @parser.WordPart,
) -> @parser.Span? {
  match part {
    SpecialParameter("@") => analytics_word_fragment_span(word, "$@")
    BracedParameter(expansion) =>
      if braced_parameter_is_unquoted_array_expansion(expansion) {
        analytics_word_fragment_span(word, "${\{expansion.raw}}")
      } else {
        None
      }
    DoubleQuoted(parts) | DollarDoubleQuoted(parts) => {
      let mut found : @parser.Span? = None
      for nested in parts {
        if found is Some(_) {
          continue
        }
        match analytics_word_part_array_span(word, nested) {
          Some(span) => found = Some(span)
          None => ()
        }
      }
      found
    }
    _ => None
  }
}

///|
fn analytics_word_fragment_span(
  word : @parser.Word,
  fragment : String,
) -> @parser.Span? {
  match analytics_string_offset(word.source, fragment) {
    Some(offset) =>
      Some(analytics_span_offset(word.span, offset, fragment.length()))
    None => None
  }
}

///|
fn check_unquoted_parameter_expansion_pattern(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      analytics_visit_parameter_patterns(word.parts, false, word, diagnostics)
    })
  })
}

///|
fn analytics_visit_parameter_patterns(
  parts : Array[@parser.WordPart],
  quoted : Bool,
  word : @parser.Word,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for part in parts {
    match part {
      DoubleQuoted(nested) | DollarDoubleQuoted(nested) =>
        analytics_visit_parameter_patterns(nested, true, word, diagnostics)
      BracedParameter(expansion) =>
        analytics_check_parameter_pattern(word, expansion, quoted, diagnostics)
      _ => ()
    }
  }
}

///|
fn analytics_check_parameter_pattern(
  word : @parser.Word,
  expansion : @parser.ParameterExpansion,
  quoted : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let pattern = match analytics_parameter_pattern_text(expansion) {
    Some(pattern) => pattern
    None => return
  }
  let pattern_word = @parser.parse_text_as_word(pattern)
  for part in pattern_word.parts {
    match analytics_parameter_pattern_part_fragment(part, pattern_word.source) {
      Some(fragment) =>
        analytics_warn_parameter_pattern_part(
          word,
          "${\{expansion.raw}}",
          fragment,
          quoted,
          diagnostics,
        )
      None => ()
    }
  }
}

///|
fn analytics_parameter_pattern_part_fragment(
  part : @parser.WordPart,
  raw : String,
) -> String? {
  match part {
    Parameter(name) | SpecialParameter(name) => Some("$\{name}")
    BracedParameter(expansion) => Some("${\{expansion.raw}}")
    CommandSubstitution(_) =>
      match analytics_string_offset(raw, "$(") {
        Some(offset) => {
          let fragment = raw.view(start_offset=offset).to_owned()
          Some(
            fragment
            .view(end_offset=analytics_command_substitution_width(fragment))
            .to_owned(),
          )
        }
        None => None
      }
    BackQuoted(_) =>
      match analytics_string_offset(raw, "`") {
        Some(offset) => {
          let fragment = raw.view(start_offset=offset).to_owned()
          Some(
            fragment
            .view(end_offset=analytics_backquoted_width(fragment))
            .to_owned(),
          )
        }
        None => None
      }
    _ => None
  }
}

///|
fn analytics_parameter_pattern_text(
  expansion : @parser.ParameterExpansion,
) -> String? {
  match expansion.operator {
    Some(RemoveShortestPrefix(text))
    | Some(RemoveLongestPrefix(text))
    | Some(RemoveShortestSuffix(text))
    | Some(RemoveLongestSuffix(text)) => Some(text)
    _ => None
  }
}

///|
fn analytics_warn_parameter_pattern_part(
  word : @parser.Word,
  outer : String,
  inner : String,
  quoted : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let span = analytics_span_for_nested_word_text(word, outer, inner)
  push_diagnostic_with_fix(
    diagnostics,
    span,
    Info,
    2295,
    "Expansions inside ${..} need to be quoted separately, otherwise they match as patterns.",
    analytics_quote_nested_span_fix(span, if quoted { 10 } else { 9 }),
  )
}

///|
fn analytics_quote_nested_span_fix(
  span : @parser.Span,
  precedence : Int,
) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      span.start,
      span.start,
      "\"",
      precedence,
      @fixer.InsertionPoint::after(),
    ),
    @fixer.Replacement::new(
      "",
      span.end,
      span.end,
      "\"",
      precedence,
      @fixer.InsertionPoint::before(),
    ),
  ])
}
