///|
fn append_analytics_batch_p_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_p_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_p_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2270,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Use set -- instead of assigning positional parameters as command names.",
    },
    {
      code: 2271,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Dynamic assignment targets become command names instead of assignments.",
    },
    {
      code: 2272,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Command names containing == are usually mistaken comparisons.",
    },
    {
      code: 2273,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "A command name made only of === often indicates a conflict marker.",
    },
    {
      code: 2274,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Command names starting with === are likely commented borders.",
    },
    {
      code: 2275,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "A command name starting with = usually indicates a bad line break.",
    },
    {
      code: 2276,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Command names containing = are often malformed assignments or comparisons.",
    },
    {
      code: 2277,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Assign to BASH_ARGV0 instead of $0 in Bash.",
    },
    {
      code: 2278,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "$0 can not be assigned in Ksh.",
    },
    {
      code: 2279,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "$0 assignments become command names in Dash and BusyBox Ash.",
    },
    {
      code: 2280,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "$0 can not be assigned portably.",
    },
    {
      code: 2281,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Do not put $ or ${} on the left side of assignments.",
    },
    {
      code: 2282,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Variable names can not start with numbers.",
    },
  ]
}

///|
fn run_analytics_batch_p_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_equals_in_command(script, shell, diagnostics)
}

///|
fn check_equals_in_command(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        if simple.words.length() > 0 {
          p_check_equals_command_word(
            command.span,
            simple,
            simple.words[0],
            shell,
            diagnostics,
          )
        }
      _ => ()
    }
  })
}

///|
fn p_check_equals_command_word(
  command_span : @parser.Span,
  simple : @parser.SimpleCommand,
  word : @parser.Word,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let first_eq_text = match p_first_literal_with_equals(word.parts) {
    Some((_, text)) => text
    None => return
  }
  let leading_parts = p_parts_before_first_equals(word.parts)
  let stripped_leading = p_strip_single_plus(leading_parts)
  let stripped_prefix_width = match p_stripped_prefix_width(word.source) {
    Some(width) => width
    None => return
  }
  let has_assignment_plus = p_source_has_plus_before_equals(word.source)

  if stripped_leading.length() == 0 && first_eq_text.has_prefix("-") {
    return
  }

  if stripped_leading.length() == 0 && first_eq_text.has_prefix("=") {
    if simple.assignments.length() == 0 &&
      simple.words.length() == 1 &&
      p_word_is_conflict_marker(word) {
      push_diagnostic(
        diagnostics,
        command_span,
        CheckSeverity::Error,
        2273,
        "Sequence of ===s found. Merge conflict or intended as a commented border?",
      )
    } else if first_eq_text.has_prefix("===") {
      push_diagnostic(
        diagnostics,
        command_span,
        CheckSeverity::Error,
        2274,
        "Command name starts with ===. Intended as a commented border?",
      )
    } else {
      push_diagnostic(
        diagnostics,
        word.span,
        CheckSeverity::Error,
        2275,
        "Command name starts with =. Bad line break?",
      )
    }
    return
  }

  if first_eq_text.contains("==") {
    push_diagnostic(
      diagnostics,
      word.span,
      CheckSeverity::Error,
      2272,
      "Command name contains ==. For comparison, use [ \"$var\" = value ].",
    )
    return
  }

  if p_assignment_target_is_direct_reference(stripped_leading) &&
    (first_eq_text.has_prefix("=") || has_assignment_plus) {
    p_push_direct_reference_assignment_diagnostic(
      word,
      stripped_leading[0],
      stripped_prefix_width,
      shell,
      diagnostics,
    )
    return
  }

  if stripped_leading.length() == 0 {
    match p_positional_assignment_width(first_eq_text) {
      Some(width) =>
        if first_eq_text.has_prefix("0=") {
          p_push_literal_zero_assignment(word, shell, diagnostics)
        } else {
          push_diagnostic(
            diagnostics,
            span_prefix(word.span, width),
            CheckSeverity::Error,
            2270,
            "To assign positional parameters, use 'set -- first second ..' (or use [ ] to compare).",
          )
        }
      None =>
        if p_is_leading_number_var(first_eq_text) {
          push_diagnostic(
            diagnostics,
            word.span,
            CheckSeverity::Error,
            2282,
            "Variable names can't start with numbers, so this is interpreted as a command.",
          )
          return
        }
    }
    if p_positional_assignment_width(first_eq_text) is Some(_) ||
      p_is_leading_number_var(first_eq_text) {
      return
    }
  }

  if stripped_leading.length() > 0 &&
    p_may_be_variable_name(stripped_leading) &&
    p_text_is_all_variable_chars(p_text_before_equals(first_eq_text)) {
    push_diagnostic(
      diagnostics,
      word.span,
      CheckSeverity::Error,
      2271,
      "For indirection, use arrays, declare \"var$n=value\", or (for sh) read/eval.",
    )
    return
  }

  push_diagnostic(
    diagnostics,
    word.span,
    CheckSeverity::Error,
    2276,
    "This is interpreted as a command name containing '='. Bad assignment or comparison?",
  )
}

///|
fn p_push_direct_reference_assignment_diagnostic(
  word : @parser.Word,
  target : @parser.WordPart,
  target_width : Int,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let target_span = span_prefix(word.span, target_width)
  match target {
    @parser.WordPart::Parameter(_) =>
      push_diagnostic_with_fix(
        diagnostics,
        target_span,
        CheckSeverity::Error,
        2281,
        "Don't use $ on the left side of assignments.",
        p_remove_dollar_fix(word.span.start),
      )
    @parser.WordPart::SpecialParameter(name) =>
      if name == "0" {
        p_push_zero_assignment_with_optional_fix(
          diagnostics,
          target_span,
          shell,
          Some(p_replace_prefix_fix(word.span.start, 2, "BASH_ARGV0")),
        )
      } else if p_text_is_all_digits(name) {
        push_diagnostic(
          diagnostics,
          target_span,
          CheckSeverity::Error,
          2270,
          "To assign positional parameters, use 'set -- first second ..' (or use [ ] to compare).",
        )
      } else {
        push_diagnostic(
          diagnostics,
          word.span,
          CheckSeverity::Error,
          2276,
          "This is interpreted as a command name containing '='. Bad assignment or comparison?",
        )
      }
    @parser.WordPart::BracedParameter(expansion) =>
      p_push_braced_assignment_diagnostic(
        word.span.start,
        target_span,
        target_width,
        expansion,
        shell,
        diagnostics,
      )
    _ => ()
  }
}

///|
fn p_push_braced_assignment_diagnostic(
  word_start : @parser.Position,
  target_span : @parser.Span,
  target_width : Int,
  expansion : @parser.ParameterExpansion,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let name = match expansion.name {
    Some(name) => name
    None => ""
  }
  if name == "" || expansion.length_prefix {
    push_diagnostic(
      diagnostics,
      target_span,
      CheckSeverity::Error,
      2276,
      "This is interpreted as a command name containing '='. Bad assignment or comparison?",
    )
    return
  }
  if name == "0" &&
    !expansion.indirect &&
    expansion.operator is None &&
    expansion.index is None {
    p_push_zero_assignment_with_optional_fix(
      diagnostics,
      target_span,
      shell,
      Some(
        @fixer.Fix::from_replacements([
          @fixer.Replacement::new(
            "",
            word_start,
            analytics_position_offset(word_start, target_width),
            "BASH_ARGV0",
            7,
            @fixer.InsertionPoint::before(),
          ),
        ]),
      ),
    )
    return
  }
  if p_text_is_all_digits(name) &&
    !expansion.indirect &&
    expansion.operator is None &&
    expansion.index is None {
    push_diagnostic(
      diagnostics,
      target_span,
      CheckSeverity::Error,
      2270,
      "To assign positional parameters, use 'set -- first second ..' (or use [ ] to compare).",
    )
    return
  }
  if !expansion.indirect &&
    expansion.operator is None &&
    is_identifier_name(name) {
    push_diagnostic_with_fix(
      diagnostics,
      target_span,
      CheckSeverity::Error,
      2281,
      "Don't use ${} on the left side of assignments.",
      p_remove_braced_reference_fix(word_start, target_width),
    )
    return
  }
  push_diagnostic(
    diagnostics,
    @parser.Span::new(
      word_start,
      analytics_position_offset(word_start, target_width),
    ),
    CheckSeverity::Error,
    2271,
    "For indirection, use arrays, declare \"var$n=value\", or (for sh) read/eval.",
  )
}

///|
fn p_push_literal_zero_assignment(
  word : @parser.Word,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let diagnostic_span = span_prefix(word.span, 2)
  p_push_zero_assignment_with_optional_fix(
    diagnostics,
    diagnostic_span,
    shell,
    Some(p_replace_prefix_fix(word.span.start, 1, "BASH_ARGV0")),
  )
}

///|
fn p_push_zero_assignment_with_optional_fix(
  diagnostics : Array[CheckDiagnostic],
  span : @parser.Span,
  shell : @semantics.ShellDialect,
  bash_fix : @fixer.Fix?,
) -> Unit {
  match shell {
    @semantics.ShellDialect::Bash =>
      match bash_fix {
        Some(fix) =>
          push_diagnostic_with_fix(
            diagnostics,
            span,
            CheckSeverity::Error,
            2277,
            "Use BASH_ARGV0 to assign to $0 in bash (or use [ ] to compare).",
            fix,
          )
        None =>
          push_diagnostic(
            diagnostics,
            span,
            CheckSeverity::Error,
            2277,
            "Use BASH_ARGV0 to assign to $0 in bash (or use [ ] to compare).",
          )
      }
    @semantics.ShellDialect::Ksh =>
      push_diagnostic(
        diagnostics,
        span,
        CheckSeverity::Error,
        2278,
        "$0 can't be assigned in Ksh (but it does reflect the current function).",
      )
    @semantics.ShellDialect::Dash =>
      push_diagnostic(
        diagnostics,
        span,
        CheckSeverity::Error,
        2279,
        "$0 can't be assigned in Dash. This becomes a command name.",
      )
    @semantics.ShellDialect::BusyboxSh =>
      push_diagnostic(
        diagnostics,
        span,
        CheckSeverity::Error,
        2279,
        "$0 can't be assigned in Busybox Ash. This becomes a command name.",
      )
    @semantics.ShellDialect::Sh =>
      push_diagnostic(
        diagnostics,
        span,
        CheckSeverity::Error,
        2280,
        "$0 can't be assigned this way, and there is no portable alternative.",
      )
  }
}

///|
fn p_assignment_target_is_direct_reference(
  parts : Array[@parser.WordPart],
) -> Bool {
  match parts {
    [
      @parser.WordPart::Parameter(_)
      | @parser.WordPart::SpecialParameter(_)
      | @parser.WordPart::BracedParameter(_),
    ] => true
    _ => false
  }
}

///|
fn p_first_literal_with_equals(
  parts : Array[@parser.WordPart],
) -> (Int, String)? {
  let mut i = 0
  while i < parts.length() {
    match parts[i] {
      @parser.WordPart::Literal(text) if text.contains("=") =>
        return Some((i, text))
      _ => ()
    }
    i += 1
  }
  None
}

///|
fn p_parts_before_first_equals(
  parts : Array[@parser.WordPart],
) -> Array[@parser.WordPart] {
  let leading : Array[@parser.WordPart] = []
  for part in parts {
    match part {
      @parser.WordPart::Literal(text) if text.contains("=") => break
      _ => leading.push(part)
    }
  }
  leading
}

///|
fn p_strip_single_plus(
  parts : Array[@parser.WordPart],
) -> Array[@parser.WordPart] {
  let stripped : Array[@parser.WordPart] = []
  let mut end_ = parts.length()
  match parts.last() {
    Some(@parser.WordPart::Literal("+")) => end_ -= 1
    _ => ()
  }
  let mut i = 0
  while i < end_ {
    stripped.push(parts[i])
    i += 1
  }
  stripped
}

///|
fn p_word_is_conflict_marker(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some(text) =>
      text.length() >= 4 &&
      text.length() <= 12 &&
      p_string_all(text, fn(ch) { ch == '=' })
    None => false
  }
}

///|
fn p_positional_assignment_width(text : String) -> Int? {
  let prefix = p_text_before_equals(text)
  if prefix.length() == 0 || prefix.length() > 2 {
    return None
  }
  if p_text_is_all_digits(prefix) {
    Some(prefix.length() + 1)
  } else {
    None
  }
}

///|
fn p_is_leading_number_var(text : String) -> Bool {
  let prefix = p_text_before_equals(text)
  if prefix.length() == 0 || !p_is_ascii_digit(p_char_at(prefix, 0)) {
    return false
  }
  p_text_is_all_variable_chars(prefix) && !p_text_is_all_digits(prefix)
}

///|
fn p_may_be_variable_name(parts : Array[@parser.WordPart]) -> Bool {
  let buf = StringBuilder::new()
  for part in parts {
    match p_variable_name_placeholder(part) {
      Some(text) => buf.write_string(text)
      None => return false
    }
  }
  let candidate = buf.to_string()
  candidate != "" && is_identifier_name(candidate)
}

///|
fn p_variable_name_placeholder(part : @parser.WordPart) -> String? {
  match part {
    @parser.WordPart::Literal(text) => Some(text)
    @parser.WordPart::BracedParameter(expansion) =>
      if p_braced_parameter_can_stand_in_identifier(expansion) {
        Some("x")
      } else {
        None
      }
    @parser.WordPart::ArithmeticExpansion(_)
    | @parser.WordPart::DollarBracket(_)
    | @parser.WordPart::BraceCommandSubstitution(_, _)
    | @parser.WordPart::CommandSubstitution(_)
    | @parser.WordPart::BackQuoted(_) => Some("x")
    _ => None
  }
}

///|
fn p_braced_parameter_can_stand_in_identifier(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  if expansion.length_prefix || expansion.indirect {
    return false
  }
  match expansion.operator {
    Some(@parser.ParameterOperator::Names(_)) => false
    Some(_) => false
    None =>
      match expansion.name {
        Some("@") | Some("*") => false
        Some(_) => true
        None => false
      }
  }
}

///|
fn p_text_before_equals(text : String) -> String {
  let view = text[:]
  let mut end_ = 0
  while end_ < view.length() && view[end_].unsafe_to_char() != '=' {
    end_ += 1
  }
  text.view(end_offset=end_).to_string()
}

///|
fn p_text_is_all_digits(text : String) -> Bool {
  text != "" && p_string_all(text, fn(ch) { p_is_ascii_digit(ch) })
}

///|
fn p_text_is_all_variable_chars(text : String) -> Bool {
  p_string_all(text, fn(ch) { p_is_variable_char(ch) })
}

///|
fn p_is_variable_char(ch : Char) -> Bool {
  is_identifier_continue(ch)
}

///|
fn p_is_ascii_digit(ch : Char) -> Bool {
  '0' <= ch && ch <= '9'
}

///|
fn p_stripped_prefix_width(source : String) -> Int? {
  let width = match p_first_equals_offset(source) {
    Some(width) => width
    None => return None
  }
  if width > 0 && p_char_at(source, width - 1) == '+' {
    Some(width - 1)
  } else {
    Some(width)
  }
}

///|
fn p_source_has_plus_before_equals(source : String) -> Bool {
  match p_first_equals_offset(source) {
    Some(width) if width > 0 => p_char_at(source, width - 1) == '+'
    _ => false
  }
}

///|
fn p_first_equals_offset(source : String) -> Int? {
  let view = source[:]
  let mut i = 0
  while i < view.length() {
    if view[i].unsafe_to_char() == '=' {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn p_char_at(text : String, index : Int) -> Char {
  text[:][index].unsafe_to_char()
}

///|
fn p_string_all(text : String, predicate : (Char) -> Bool) -> Bool {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    if !predicate(view[i].unsafe_to_char()) {
      return false
    }
    i += 1
  }
  true
}

///|
fn p_remove_dollar_fix(start : @parser.Position) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      start,
      analytics_position_offset(start, 1),
      "",
      7,
      @fixer.InsertionPoint::after(),
    ),
  ])
}

///|
fn p_remove_braced_reference_fix(
  start : @parser.Position,
  width : Int,
) -> @fixer.Fix {
  let end_ = analytics_position_offset(start, width)
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      start,
      analytics_position_offset(start, 2),
      "",
      7,
      @fixer.InsertionPoint::after(),
    ),
    @fixer.Replacement::new(
      "",
      analytics_position_offset(end_, -1),
      end_,
      "",
      7,
      @fixer.InsertionPoint::before(),
    ),
  ])
}

///|
fn p_replace_prefix_fix(
  start : @parser.Position,
  width : Int,
  text : String,
) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      start,
      analytics_position_offset(start, width),
      text,
      7,
      @fixer.InsertionPoint::after(),
    ),
  ])
}
