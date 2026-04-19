///|
fn append_analytics_batch_m_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_m_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_m_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2054,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use spaces, not commas, to separate array elements.",
    },
    {
      code: 2190,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Elements in associative arrays need explicit [index]=value syntax.",
    },
    {
      code: 2191,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "This literal = looks like a mistaken array index assignment.",
    },
    {
      code: 2192,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "This indexed array element has no value.",
    },
    {
      code: 2194,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "This word is constant. Did you forget the $ on a variable?",
    },
    {
      code: 2195,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "This pattern will never match the case statement's word. Double check them.",
    },
    {
      code: 2221,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "This pattern always overrides a later one on line N.",
    },
    {
      code: 2222,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "This pattern never matches because of a previous pattern on line N.",
    },
  ]
}

///|
fn run_analytics_batch_m_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_commarray_literals(script, diagnostics)
  check_array_assignment_indices(script, diagnostics)
  check_unmatchable_cases(script, diagnostics)
}

///|
fn check_commarray_literals(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        for assignment in simple.assignments {
          m_maybe_warn_comma_array(assignment, diagnostics)
        }
      @parser.CommandKind::Source(source) =>
        for assignment in source.assignments {
          m_maybe_warn_comma_array(assignment, diagnostics)
        }
      _ => ()
    }
  })
}

///|
fn m_maybe_warn_comma_array(
  assignment : @parser.Assignment,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match assignment.value {
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      if elements.any(fn(element) { m_array_element_has_literal_comma(element) }) {
        push_diagnostic(
          diagnostics,
          array_assignment_value_span(assignment),
          CheckSeverity::Warning,
          2054,
          "Use spaces, not commas, to separate array elements.",
        )
      }
    _ => ()
  }
}

///|
fn m_array_element_has_literal_comma(element : @parser.ArrayElement) -> Bool {
  m_assignment_value_has_literal_comma(element.value)
}

///|
fn m_assignment_value_has_literal_comma(
  value : @parser.AssignmentValue,
) -> Bool {
  match value {
    @parser.AssignmentValue::Empty => false
    @parser.AssignmentValue::Word(word) =>
      m_word_has_unquoted_literal_comma(word)
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      elements.any(fn(element) { m_array_element_has_literal_comma(element) })
  }
}

///|
fn m_word_has_unquoted_literal_comma(word : @parser.Word) -> Bool {
  word.parts.any(fn(part) { m_word_part_has_unquoted_literal_comma(part) }) ||
  m_word_source_has_unquoted_index_separator(word.source)
}

///|
fn m_word_part_has_unquoted_literal_comma(part : @parser.WordPart) -> Bool {
  match part {
    @parser.WordPart::Literal(text) => text.contains(",")
    _ => false
  }
}

///|
fn m_word_source_has_unquoted_index_separator(source : String) -> Bool {
  let view = source[:]
  let mut i = 0
  let mut in_single = false
  let mut in_double = false
  while i + 1 < view.length() {
    let ch = view[i]
    if in_single {
      if ch == '\'' {
        in_single = false
      }
      i += 1
      continue
    }
    if in_double {
      if ch == '\\' && i + 1 < view.length() {
        i += 2
        continue
      }
      if ch == '"' {
        in_double = false
      }
      i += 1
      continue
    }
    if ch == '\'' {
      in_single = true
      i += 1
      continue
    }
    if ch == '"' {
      in_double = true
      i += 1
      continue
    }
    if ch == ',' && view[i + 1] == '[' {
      return true
    }
    i += 1
  }
  false
}

///|
fn check_array_assignment_indices(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let associative_names = m_collect_associative_array_names(script)
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        for assignment in simple.assignments {
          m_check_array_assignment_indices(
            assignment,
            associative_names.contains(assignment.name),
            diagnostics,
          )
        }
      @parser.CommandKind::Source(source) =>
        for assignment in source.assignments {
          m_check_array_assignment_indices(
            assignment,
            associative_names.contains(assignment.name),
            diagnostics,
          )
        }
      _ => ()
    }
  })
}

///|
fn m_check_array_assignment_indices(
  assignment : @parser.Assignment,
  is_associative : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match assignment.value {
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      m_check_array_assignment_elements(
        elements,
        is_associative,
        assignment.span,
        diagnostics,
      )
    _ => ()
  }
}

///|
fn m_check_array_assignment_elements(
  elements : Array[@parser.ArrayElement],
  is_associative : Bool,
  assignment_span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut i = 0
  while i < elements.length() {
    match m_spaced_index_assignment_pattern(elements, i) {
      Some((equals_word, consumed)) => {
        push_diagnostic_with_fix(
          diagnostics,
          equals_word.span,
          CheckSeverity::Warning,
          2191,
          "The = here is literal. To assign by index, use ( [index]=value ) with no spaces. To keep as literal, quote it.",
          m_quote_span_fix(equals_word.span),
        )
        i += consumed
        continue
      }
      None => ()
    }

    let element = elements[i]
    if element.indexes.length() > 0 {
      if element.value is @parser.AssignmentValue::Empty {
        push_diagnostic(
          diagnostics,
          m_empty_indexed_element_span(elements, i, assignment_span),
          CheckSeverity::Warning,
          2192,
          "This array element has no value. Remove spaces after = or use \"\" for empty string.",
        )
        i += m_empty_indexed_element_consumed(elements, i)
        continue
      }
      i += 1
      continue
    }

    match element.value {
      @parser.AssignmentValue::Word(word) =>
        match m_array_assignment_equals_kind(word) {
          MArrayAssignmentEqualsKind::LiteralEquals(span) =>
            push_diagnostic_with_fix(
              diagnostics,
              span,
              CheckSeverity::Warning,
              2191,
              "The = here is literal. To assign by index, use ( [index]=value ) with no spaces. To keep as literal, quote it.",
              m_quote_span_fix(span),
            )
          MArrayAssignmentEqualsKind::PlainIdentifierEquals
          | MArrayAssignmentEqualsKind::None =>
            if is_associative {
              push_diagnostic(
                diagnostics,
                word.span,
                CheckSeverity::Warning,
                2190,
                "Elements in associative arrays need index, e.g. array=( [index]=value ) .",
              )
            }
        }
      _ => ()
    }
    i += 1
  }
}

///|
priv enum MArrayAssignmentEqualsKind {
  None
  PlainIdentifierEquals
  LiteralEquals(@parser.Span)
}

///|
fn m_array_assignment_equals_kind(
  word : @parser.Word,
) -> MArrayAssignmentEqualsKind {
  let mut part_index = 0
  while part_index < word.parts.length() {
    match word.parts[part_index] {
      @parser.WordPart::Literal(text) =>
        match m_find_char(text, '=') {
          Some(index) => {
            let before = text.view(end_offset=index).to_string()
            if part_index == 0 && m_is_identifier_name(before) {
              return MArrayAssignmentEqualsKind::PlainIdentifierEquals
            }
            return MArrayAssignmentEqualsKind::LiteralEquals(
              m_span_for_literal_fragment(word, text),
            )
          }
          None => ()
        }
      _ => ()
    }
    part_index += 1
  }
  MArrayAssignmentEqualsKind::None
}

///|
fn m_spaced_index_assignment_pattern(
  elements : Array[@parser.ArrayElement],
  index : Int,
) -> (@parser.Word, Int)? {
  guard index + 1 < elements.length() else { return None }
  guard elements[index].indexes.length() == 0 else { return None }
  let index_word = match m_array_element_word(elements[index]) {
    Some(word) if m_word_is_bracketed_index_candidate(word) => word
    _ => return None
  }
  ignore(index_word)
  guard elements[index + 1].indexes.length() == 0 else { return None }
  let equals_word = match m_array_element_word(elements[index + 1]) {
    Some(word) if m_word_starts_with_equals(word) => word
    _ => return None
  }
  let consumed = if equals_word.source == "=" && index + 2 < elements.length() {
    3
  } else {
    2
  }
  Some((equals_word, consumed))
}

///|
fn m_empty_indexed_element_consumed(
  elements : Array[@parser.ArrayElement],
  index : Int,
) -> Int {
  guard index + 1 < elements.length() else { return 1 }
  if elements[index + 1].indexes.length() == 0 &&
    m_array_element_word(elements[index + 1]) is Some(_) {
    2
  } else {
    1
  }
}

///|
fn m_empty_indexed_element_span(
  elements : Array[@parser.ArrayElement],
  index : Int,
  assignment_span : @parser.Span,
) -> @parser.Span {
  if index + 1 < elements.length() && elements[index + 1].indexes.length() == 0 {
    match m_array_element_word(elements[index + 1]) {
      Some(word) => {
        let point = m_position_offset(word.span.start, -1)
        return @parser.Span::new(point, point)
      }
      None => ()
    }
  }
  let point = m_position_offset(assignment_span.end, -1)
  @parser.Span::new(point, point)
}

///|
fn m_collect_associative_array_names(script : @parser.Script) -> Array[String] {
  let names : Array[String] = []
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        m_collect_associative_names_from_simple(simple, names)
      _ => ()
    }
  })
  names
}

///|
fn m_collect_associative_names_from_simple(
  simple : @parser.SimpleCommand,
  names : Array[String],
) -> Unit {
  guard simple.words.length() > 0 else { return }
  let command_name = match m_word_plain_text(simple.words[0]) {
    Some(name) => name
    None => return
  }
  if command_name != "declare" &&
    command_name != "local" &&
    command_name != "typeset" {
    return
  }
  let mut has_associative_flag = false
  let mut i = 1
  while i < simple.words.length() {
    match m_word_plain_text(simple.words[i]) {
      Some(flag) if flag.has_prefix("-") && flag.contains("A") => {
        has_associative_flag = true
        break
      }
      _ => ()
    }
    i += 1
  }
  guard has_associative_flag else { return }
  for assignment in simple.assignments {
    m_push_unique_name(names, assignment.name)
  }
  i = 1
  while i < simple.words.length() {
    match m_word_plain_text(simple.words[i]) {
      Some(text) if text == "--" => ()
      Some(text) if text.has_prefix("-") => ()
      _ =>
        match m_word_plain_identifier(simple.words[i]) {
          Some(name) => m_push_unique_name(names, name)
          None => ()
        }
    }
    i += 1
  }
}

///|
fn m_word_plain_identifier(word : @parser.Word) -> String? {
  match m_word_plain_text(word) {
    Some(text) if m_is_identifier_name(text) => Some(text)
    _ => None
  }
}

///|
fn m_word_plain_text(word : @parser.Word) -> String? {
  match word.parts {
    [@parser.WordPart::Literal(text)] => Some(text)
    _ => None
  }
}

///|
fn m_push_unique_name(names : Array[String], name : String) -> Unit {
  if !names.contains(name) {
    names.push(name)
  }
}

///|
fn m_array_element_word(element : @parser.ArrayElement) -> @parser.Word? {
  match element.value {
    @parser.AssignmentValue::Word(word) => Some(word)
    _ => None
  }
}

///|
fn m_word_is_bracketed_index_candidate(word : @parser.Word) -> Bool {
  match m_word_plain_text(word) {
    Some(text) => text.has_prefix("[") && text.has_suffix("]")
    None => false
  }
}

///|
fn m_word_starts_with_equals(word : @parser.Word) -> Bool {
  word.source.has_prefix("=")
}

///|
fn m_span_for_literal_fragment(
  word : @parser.Word,
  fragment : String,
) -> @parser.Span {
  match m_string_offset(word.source, fragment) {
    Some(offset) => m_span_offset(word.span, offset, fragment.length())
    None => word.span
  }
}

///|
fn m_quote_span_fix(span : @parser.Span) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      span.start,
      span.start,
      "\"",
      9,
      @fixer.InsertionPoint::after(),
    ),
    @fixer.Replacement::new(
      "",
      span.end,
      span.end,
      "\"",
      9,
      @fixer.InsertionPoint::before(),
    ),
  ])
}

///|
fn m_is_identifier_name(name : String) -> Bool {
  let view = name[:]
  guard view.length() > 0 else { return false }
  if !m_is_identifier_start(view[0].unsafe_to_char()) {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if !m_is_identifier_continue(view[i].unsafe_to_char()) {
      return false
    }
    i += 1
  }
  true
}

///|
fn m_is_identifier_start(ch : Char) -> Bool {
  ('a' <= ch && ch <= 'z') || ('A' <= ch && ch <= 'Z') || ch == '_'
}

///|
fn m_is_identifier_continue(ch : Char) -> Bool {
  m_is_identifier_start(ch) || ('0' <= ch && ch <= '9')
}

///|
fn m_find_char(text : String, target : Char) -> Int? {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    if view[i].unsafe_to_char() == target {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn m_string_offset(text : String, fragment : String) -> Int? {
  let source = text[:]
  let needle = fragment[:]
  if needle.length() == 0 {
    return Some(0)
  }
  if needle.length() > source.length() {
    return None
  }
  let mut offset = 0
  while offset + needle.length() <= source.length() {
    let mut matched = true
    let mut i = 0
    while i < needle.length() {
      if source[offset + i] != needle[i] {
        matched = false
        break
      }
      i += 1
    }
    if matched {
      return Some(offset)
    }
    offset += 1
  }
  None
}

///|
fn m_position_offset(
  position : @parser.Position,
  offset : Int,
) -> @parser.Position {
  @parser.Position::new(
    position.offset + offset,
    position.line,
    position.column + offset,
  )
}

///|
fn m_span_offset(
  span : @parser.Span,
  offset : Int,
  width : Int,
) -> @parser.Span {
  @parser.Span::new(
    m_position_offset(span.start, offset),
    m_position_offset(span.start, offset + width),
  )
}

///|
fn check_unmatchable_cases(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Case(clause) => {
        let constant_word = @semantics.is_constant_word(clause.word)
        if constant_word {
          push_diagnostic(
            diagnostics,
            clause.word.span,
            CheckSeverity::Warning,
            2194,
            "This word is constant. Did you forget the $ on a variable?",
          )
        }

        if !constant_word {
          let all_patterns : Array[@parser.Word] = []
          for item in clause.items {
            for pattern in item.patterns {
              all_patterns.push(pattern)
            }
          }

          let target = word_to_pseudo_glob(clause.word)
          for pattern in all_patterns {
            if !pseudo_globs_can_overlap(target, word_to_pseudo_glob(pattern)) {
              push_diagnostic(
                diagnostics,
                pattern.span,
                CheckSeverity::Warning,
                2195,
                "This pattern will never match the case statement's word. Double check them.",
              )
            }
          }
        }

        let break_patterns : Array[
          (Int, @parser.Word, Array[PseudoGlob]?, Array[PseudoGlob]),
        ] = []
        let mut pattern_index = 0
        for item in clause.items {
          for pattern in item.patterns {
            if item.separator is @parser.CaseSeparator::Break {
              break_patterns.push(
                (
                  pattern_index,
                  pattern,
                  word_to_exact_pseudo_glob(pattern),
                  word_to_pseudo_glob(pattern),
                ),
              )
            }
            pattern_index += 1
          }
        }

        let mut left_index = 0
        while left_index < break_patterns.length() {
          let (_, left_pattern, maybe_glob, _) = break_patterns[left_index]
          match maybe_glob {
            Some(left_glob) => {
              let mut rest_index = left_index + 1
              while rest_index < break_patterns.length() {
                let (_, right_pattern, _, right_glob) = break_patterns[rest_index]
                if pseudo_glob_is_superset_of(left_glob, right_glob) {
                  push_diagnostic(
                    diagnostics,
                    left_pattern.span,
                    CheckSeverity::Warning,
                    2221,
                    "This pattern always overrides a later one on line " +
                    right_pattern.span.start.line.to_string() +
                    ".",
                  )
                  push_diagnostic(
                    diagnostics,
                    right_pattern.span,
                    CheckSeverity::Warning,
                    2222,
                    "This pattern never matches because of a previous pattern on line " +
                    left_pattern.span.start.line.to_string() +
                    ".",
                  )
                  break
                }
                rest_index += 1
              }
            }
            None => ()
          }
          left_index += 1
        }
      }
      _ => ()
    }
  })
}

///|
priv enum PseudoGlob {
  Any
  Many
  Char(Char)
}

///|
fn word_to_pseudo_glob(word : @parser.Word) -> Array[PseudoGlob] {
  match word_to_pseudo_glob_impl(word, false) {
    Some(glob) => glob
    None => [PseudoGlob::Many]
  }
}

///|
fn word_to_exact_pseudo_glob(word : @parser.Word) -> Array[PseudoGlob]? {
  word_to_pseudo_glob_impl(word, true)
}

///|
fn word_to_pseudo_glob_impl(
  word : @parser.Word,
  exact : Bool,
) -> Array[PseudoGlob]? {
  let glob : Array[PseudoGlob] = []
  let parts = word.parts
  match parts {
    [@parser.WordPart::Literal(text), .. rest] if text.has_prefix("~") => {
      if exact {
        return None
      }
      if !append_tilde_prefix(text, glob) {
        return None
      }
      if !append_word_parts_pseudo_glob(rest.to_array(), exact, glob) {
        return None
      }
    }
    _ => if !append_word_parts_pseudo_glob(parts, exact, glob) { return None }
  }
  Some(simplify_pseudo_glob(glob))
}

///|
fn append_tilde_prefix(text : String, glob : Array[PseudoGlob]) -> Bool {
  glob.push(PseudoGlob::Many)
  let mut in_tail = false
  for ch in text {
    if in_tail {
      glob.push(PseudoGlob::Char(ch))
    } else if ch == '/' {
      in_tail = true
      glob.push(PseudoGlob::Char(ch))
    }
  }
  true
}

///|
fn append_word_parts_pseudo_glob(
  parts : Array[@parser.WordPart],
  exact : Bool,
  glob : Array[PseudoGlob],
) -> Bool {
  for part in parts {
    if !append_word_part_pseudo_glob(part, exact, glob) {
      return false
    }
  }
  true
}

///|
fn append_word_part_pseudo_glob(
  part : @parser.WordPart,
  exact : Bool,
  glob : Array[PseudoGlob],
) -> Bool {
  match part {
    @parser.WordPart::Literal(text) | @parser.WordPart::SingleQuoted(text) =>
      append_text_pseudo_glob(text, glob)
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      append_word_parts_pseudo_glob(parts, exact, glob)
    @parser.WordPart::Glob(text) =>
      append_glob_text_pseudo_glob(text, exact, glob)
    @parser.WordPart::Parameter(_)
    | @parser.WordPart::SpecialParameter(_)
    | @parser.WordPart::BracedParameter(_)
    | @parser.WordPart::BraceCommandSubstitution(_, _)
    | @parser.WordPart::CommandSubstitution(_)
    | @parser.WordPart::BackQuoted(_)
    | @parser.WordPart::ArithmeticExpansion(_)
    | @parser.WordPart::DollarBracket(_)
    | @parser.WordPart::ExtGlob(_)
    | @parser.WordPart::ProcessSubstitution(_, _)
    | @parser.WordPart::BraceExpansion(_) =>
      if exact {
        false
      } else {
        glob.push(PseudoGlob::Many)
        true
      }
    @parser.WordPart::DollarSingleQuoted(text) =>
      append_text_pseudo_glob(decode_dollar_single_quoted_local(text), glob)
  }
}

///|
fn append_text_pseudo_glob(text : String, glob : Array[PseudoGlob]) -> Bool {
  for ch in text {
    glob.push(PseudoGlob::Char(ch))
  }
  true
}

///|
fn append_glob_text_pseudo_glob(
  text : String,
  exact : Bool,
  glob : Array[PseudoGlob],
) -> Bool {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch == '?' {
      if exact {
        return false
      }
      glob.push(PseudoGlob::Any)
      i += 1
      continue
    }
    if ch == '*' {
      if exact {
        return false
      }
      glob.push(PseudoGlob::Many)
      i += 1
      continue
    }
    if ch == '[' {
      let mut j = i + 1
      while j < view.length() && view[j] != ']' {
        j += 1
      }
      if j < view.length() {
        if exact {
          return false
        }
        glob.push(PseudoGlob::Any)
        i = j + 1
        continue
      }
      if exact {
        return false
      }
      glob.push(PseudoGlob::Many)
      return true
    }
    glob.push(PseudoGlob::Char(ch.unsafe_to_char()))
    i += 1
  }
  true
}

///|
fn simplify_pseudo_glob(glob : Array[PseudoGlob]) -> Array[PseudoGlob] {
  let simplified : Array[PseudoGlob] = []
  let mut index = 0
  while index < glob.length() {
    match glob[index] {
      PseudoGlob::Any | PseudoGlob::Many => {
        let mut seen_many = false
        let anys : Array[PseudoGlob] = []
        while index < glob.length() {
          match glob[index] {
            PseudoGlob::Any => anys.push(PseudoGlob::Any)
            PseudoGlob::Many => seen_many = true
            _ => break
          }
          index += 1
        }
        for part in anys {
          simplified.push(part)
        }
        if seen_many {
          simplified.push(PseudoGlob::Many)
        }
      }
      PseudoGlob::Char(ch) => {
        simplified.push(PseudoGlob::Char(ch))
        index += 1
      }
    }
  }
  simplified
}

///|
fn pseudo_globs_can_overlap(
  x : Array[PseudoGlob],
  y : Array[PseudoGlob],
) -> Bool {
  matchable(x, y)
}

///|
fn matchable(x : Array[PseudoGlob], y : Array[PseudoGlob]) -> Bool {
  match (x, y) {
    ([], []) => true
    ([], _) => matchable(y, [])
    (_, []) =>
      match x {
        [PseudoGlob::Many, .. rest] => matchable(rest.to_array(), [])
        _ => false
      }
    ([x_head, .. x_rest], [y_head, .. y_rest]) =>
      match (x_head, y_head) {
        (PseudoGlob::Many, _) =>
          matchable(x, y_rest.to_array()) || matchable(x_rest.to_array(), y)
        (_, PseudoGlob::Many) =>
          matchable(x, y_rest.to_array()) || matchable(x_rest.to_array(), y)
        (PseudoGlob::Any, _) => matchable(x_rest.to_array(), y_rest.to_array())
        (_, PseudoGlob::Any) => matchable(x_rest.to_array(), y_rest.to_array())
        (PseudoGlob::Char(x_char), PseudoGlob::Char(y_char)) =>
          x_char == y_char && matchable(x_rest.to_array(), y_rest.to_array())
      }
  }
}

///|
fn pseudo_glob_is_superset_of(
  x : Array[PseudoGlob],
  y : Array[PseudoGlob],
) -> Bool {
  matchable_superset(x, y)
}

///|
fn matchable_superset(x : Array[PseudoGlob], y : Array[PseudoGlob]) -> Bool {
  match (x, y) {
    ([], []) => true
    ([PseudoGlob::Many, .. rest], []) => matchable_superset(rest.to_array(), [])
    ([], _) => false
    (_, []) => false
    ([x_head, .. x_rest], [y_head, .. y_rest]) =>
      match (x_head, y_head) {
        (PseudoGlob::Many, PseudoGlob::Many) =>
          matchable_superset(x, y_rest.to_array())
        (PseudoGlob::Many, _) =>
          matchable_superset(x, y_rest.to_array()) ||
          matchable_superset(x_rest.to_array(), y)
        (_, PseudoGlob::Many) => false
        (PseudoGlob::Any, _) =>
          matchable_superset(x_rest.to_array(), y_rest.to_array())
        (_, PseudoGlob::Any) => false
        (PseudoGlob::Char(x_char), PseudoGlob::Char(y_char)) =>
          x_char == y_char &&
          matchable_superset(x_rest.to_array(), y_rest.to_array())
      }
  }
}

///|
fn decode_dollar_single_quoted_local(text : String) -> String {
  let view = text.view()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch != '\\' {
      buf.write_char(ch.unsafe_to_char())
      i += 1
      continue
    }
    if i + 1 >= view.length() {
      buf.write_char('\\')
      i += 1
      continue
    }
    let next = view[i + 1]
    match next {
      'a' => {
        buf.write_char((7).unsafe_to_char())
        i += 2
      }
      'b' => {
        buf.write_char((8).unsafe_to_char())
        i += 2
      }
      'e' => {
        buf.write_char((27).unsafe_to_char())
        i += 2
      }
      'f' => {
        buf.write_char((12).unsafe_to_char())
        i += 2
      }
      'n' => {
        buf.write_char('\n')
        i += 2
      }
      'r' => {
        buf.write_char('\r')
        i += 2
      }
      't' => {
        buf.write_char('\t')
        i += 2
      }
      'v' => {
        buf.write_char((11).unsafe_to_char())
        i += 2
      }
      '\'' | '"' | '\\' => {
        buf.write_char(next.unsafe_to_char())
        i += 2
      }
      'x' => {
        let first = if i + 2 < view.length() {
          decode_hex_digit(view[i + 2])
        } else {
          None
        }
        let second = if i + 3 < view.length() {
          decode_hex_digit(view[i + 3])
        } else {
          None
        }
        match (first, second) {
          (Some(a), Some(b)) => {
            buf.write_char((a * 16 + b).unsafe_to_char())
            i += 4
          }
          (Some(a), None) => {
            buf.write_char(a.unsafe_to_char())
            i += 3
          }
          _ => {
            buf.write_char('\\')
            buf.write_char('x')
            i += 2
          }
        }
      }
      _ if is_octal_digit(next) => {
        let mut value = octal_digit_value(next)
        let mut consumed = 2
        if i + consumed < view.length() && is_octal_digit(view[i + consumed]) {
          value = value * 8 + octal_digit_value(view[i + consumed])
          consumed += 1
        }
        if i + consumed < view.length() && is_octal_digit(view[i + consumed]) {
          value = value * 8 + octal_digit_value(view[i + consumed])
          consumed += 1
        }
        buf.write_char((value % 256).unsafe_to_char())
        i += consumed
      }
      _ => {
        buf.write_char('\\')
        buf.write_char(next.unsafe_to_char())
        i += 2
      }
    }
  }
  buf.to_string()
}

///|
fn decode_hex_digit(ch : UInt16) -> Int? {
  if ch >= '0' && ch <= '9' {
    return Some(ch.to_int() - '0'.to_int())
  }
  if ch >= 'a' && ch <= 'f' {
    return Some(ch.to_int() - 'a'.to_int() + 10)
  }
  if ch >= 'A' && ch <= 'F' {
    return Some(ch.to_int() - 'A'.to_int() + 10)
  }
  None
}

///|
fn octal_digit_value(ch : UInt16) -> Int {
  ch.to_int() - '0'.to_int()
}

///|
fn is_octal_digit(ch : UInt16) -> Bool {
  ch >= '0' && ch <= '7'
}
