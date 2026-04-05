///|
fn walk_word_deep(
  word : @parser.Word,
  visit : (@parser.WordPart) -> Unit,
) -> Unit {
  walk_word_parts_deep(word.parts, visit)
}

///|
fn walk_word_parts_deep(
  parts : Array[@parser.WordPart],
  visit : (@parser.WordPart) -> Unit,
) -> Unit {
  for part in parts {
    walk_word_part_deep(part, visit)
  }
}

///|
fn walk_word_part_deep(
  part : @parser.WordPart,
  visit : (@parser.WordPart) -> Unit,
) -> Unit {
  visit(part)
  match part {
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      walk_word_parts_deep(parts, visit)
    @parser.WordPart::BracedParameter(expansion) =>
      walk_parameter_expansion_parts(expansion, visit)
    @parser.WordPart::ArithmeticExpansion(expr)
    | @parser.WordPart::DollarBracket(expr) =>
      walk_arithmetic_expr_word_parts(expr, visit)
    @parser.WordPart::ExtGlob(pattern) =>
      for alternative in pattern.alternatives {
        walk_word_deep(alternative, visit)
      }
    @parser.WordPart::BraceExpansion(expansion) =>
      for element in expansion.elements {
        walk_word_deep(element, visit)
      }
    _ => ()
  }
}

///|
fn walk_parameter_expansion_parts(
  expansion : @parser.ParameterExpansion,
  visit : (@parser.WordPart) -> Unit,
) -> Unit {
  match expansion.index {
    Some(index) => walk_word_parts_deep(index.parts, visit)
    None => ()
  }
  walk_parameter_operator_parts(expansion.operator, visit)
}

///|
fn walk_parameter_operator_parts(
  operator : @parser.ParameterOperator?,
  visit : (@parser.WordPart) -> Unit,
) -> Unit {
  match operator {
    Some(@parser.ParameterOperator::Slice(offset, length)) => {
      walk_arithmetic_expr_word_parts(
        @parser.parse_arithmetic_expr(offset),
        visit,
      )
      match length {
        Some(length) =>
          walk_arithmetic_expr_word_parts(
            @parser.parse_arithmetic_expr(length),
            visit,
          )
        None => ()
      }
    }
    Some(@parser.ParameterOperator::Replace(_, pattern, replacement)) => {
      walk_word_deep(@parser.parse_text_as_word(pattern), visit)
      match replacement {
        Some(replacement) =>
          walk_word_deep(@parser.parse_text_as_word(replacement), visit)
        None => ()
      }
    }
    Some(@parser.ParameterOperator::CaseModify(_, Some(pattern))) =>
      walk_word_deep(@parser.parse_text_as_word(pattern), visit)
    Some(@parser.ParameterOperator::DefaultValue(text))
    | Some(@parser.ParameterOperator::AssignDefault(text))
    | Some(@parser.ParameterOperator::ErrorValue(text))
    | Some(@parser.ParameterOperator::AlternateValue(text))
    | Some(@parser.ParameterOperator::RemoveShortestPrefix(text))
    | Some(@parser.ParameterOperator::RemoveLongestPrefix(text))
    | Some(@parser.ParameterOperator::RemoveShortestSuffix(text))
    | Some(@parser.ParameterOperator::RemoveLongestSuffix(text))
    | Some(@parser.ParameterOperator::Transform(text))
    | Some(@parser.ParameterOperator::Raw(text)) =>
      walk_word_deep(@parser.parse_text_as_word(text), visit)
    Some(@parser.ParameterOperator::Names(_))
    | Some(@parser.ParameterOperator::CaseModify(_, None))
    | None => ()
  }
}

///|
fn walk_arithmetic_expr_word_parts(
  expr : @parser.ArithmeticExpr,
  visit : (@parser.WordPart) -> Unit,
) -> Unit {
  for token in expr.tokens {
    match token {
      @parser.ArithmeticToken::Expansion(word) => walk_word_deep(word, visit)
      @parser.ArithmeticToken::Group(inner) =>
        walk_arithmetic_expr_word_parts(inner, visit)
      @parser.ArithmeticToken::Variable(_, indexes) =>
        for index in indexes {
          walk_word_parts_deep(index.parts, visit)
        }
      _ => ()
    }
  }
}

///|
fn word_has_backquoted_part(word : @parser.Word) -> Bool {
  let mut found = false
  walk_word_deep(word, fn(part) {
    match part {
      @parser.WordPart::BackQuoted(script) if script.items.length() > 0 =>
        found = true
      _ => ()
    }
  })
  found
}

///|
fn word_has_top_level_command_substitution(word : @parser.Word) -> Bool {
  for part in word.parts {
    match part {
      @parser.WordPart::CommandSubstitution(script)
      | @parser.WordPart::BraceCommandSubstitution(_, script)
      | @parser.WordPart::BackQuoted(script) =>
        if script.items.length() > 0 {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn word_is_plain_double_quoted(word : @parser.Word) -> Array[@parser.WordPart]? {
  match word.parts {
    [@parser.WordPart::DoubleQuoted(parts)] => Some(parts)
    _ => None
  }
}

///|
fn word_is_plain_single_quoted(word : @parser.Word) -> Bool {
  match word.parts {
    [@parser.WordPart::SingleQuoted(_)] => true
    _ => false
  }
}

///|
fn word_would_have_been_glob(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some(text) => text.contains("*") || text.contains("?") || text.contains("[")
    None => false
  }
}

///|
fn word_single_top_level_substitution_script(
  word : @parser.Word,
) -> @parser.Script? {
  match word.parts {
    [@parser.WordPart::CommandSubstitution(script)]
    | [@parser.WordPart::BraceCommandSubstitution(_, script)]
    | [@parser.WordPart::BackQuoted(script)] => Some(script)
    _ => None
  }
}

///|
fn command_matches_exact_name(command : @parser.Command, name : String) -> Bool {
  @semantics.command_name(command) == Some(name) ||
  @semantics.builtin_command_name(command) == Some(name)
}

///|
fn command_matches_basename(command : @parser.Command, name : String) -> Bool {
  @semantics.command_basename(command) == Some(name)
}

///|
fn shell_is_one_of(
  shell : @semantics.ShellDialect,
  dialects : Array[@semantics.ShellDialect],
) -> Bool {
  dialects.any(fn(dialect) { dialect == shell })
}

///|
fn shell_is_posix_sh(shell : @semantics.ShellDialect) -> Bool {
  shell_is_one_of(shell, [
    @semantics.ShellDialect::Sh,
    @semantics.ShellDialect::Dash,
    @semantics.ShellDialect::BusyboxSh,
  ])
}

///|
fn word_is_just_command_output(word : @parser.Word) -> Bool {
  match word.parts {
    [@parser.WordPart::CommandSubstitution(script)]
    | [@parser.WordPart::BraceCommandSubstitution(_, script)]
    | [@parser.WordPart::BackQuoted(script)] =>
      substitution_script_has_named_command(script)
    [@parser.WordPart::DoubleQuoted(parts)]
    | [@parser.WordPart::DollarDoubleQuoted(parts)] =>
      quoted_parts_are_just_command_output(parts)
    _ => false
  }
}

///|
fn quoted_parts_are_just_command_output(
  parts : Array[@parser.WordPart],
) -> Bool {
  match parts {
    [@parser.WordPart::CommandSubstitution(script)]
    | [@parser.WordPart::BraceCommandSubstitution(_, script)]
    | [@parser.WordPart::BackQuoted(script)] =>
      substitution_script_has_named_command(script)
    _ => false
  }
}

///|
fn substitution_script_has_named_command(script : @parser.Script) -> Bool {
  first_command_name_in_script(script) is Some(_)
}

///|
fn first_command_in_script(script : @parser.Script) -> @parser.Command? {
  for item in script.items {
    if item.and_or.head.segments.length() > 0 {
      return Some(item.and_or.head.segments[0].command)
    }
    for pair in item.and_or.tail {
      let (_, pipeline) = pair
      if pipeline.segments.length() > 0 {
        return Some(pipeline.segments[0].command)
      }
    }
  }
  None
}

///|
fn first_command_name_in_script(script : @parser.Script) -> String? {
  match first_command_in_script(script) {
    Some(command) => @semantics.command_name(command)
    None => None
  }
}

///|
fn parameter_has_names_operator(expansion : @parser.ParameterExpansion) -> Bool {
  match expansion.operator {
    Some(@parser.ParameterOperator::Names(_)) => true
    _ => false
  }
}

///|
fn parameter_has_index(expansion : @parser.ParameterExpansion) -> Bool {
  expansion.index is Some(_)
}

///|
fn parameter_index_is(
  expansion : @parser.ParameterExpansion,
  raw : String,
) -> Bool {
  match expansion.index {
    Some(index) => index.raw == raw
    None => false
  }
}

///|
fn parameter_expansion_allows_unset(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  if expansion.indirect && parameter_has_names_operator(expansion) {
    return true
  }
  match expansion.operator {
    Some(@parser.ParameterOperator::DefaultValue(_))
    | Some(@parser.ParameterOperator::AssignDefault(_))
    | Some(@parser.ParameterOperator::ErrorValue(_))
    | Some(@parser.ParameterOperator::AlternateValue(_)) => true
    Some(@parser.ParameterOperator::Raw(text)) =>
      text.has_prefix("-") || text.has_prefix("?") || text.has_prefix("+")
    _ => false
  }
}

///|
fn fix_from_replacement(
  start : @parser.Position,
  end_ : @parser.Position,
  text : String,
) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      start,
      end_,
      text,
      0,
      @fixer.InsertionPoint::before(),
    ),
  ])
}

///|
fn replace_span_fix(span : @parser.Span, text : String) -> @fixer.Fix {
  fix_from_replacement(span.start, span.end, text)
}

///|
fn insert_before_position_fix(
  position : @parser.Position,
  text : String,
) -> @fixer.Fix {
  fix_from_replacement(position, position, text)
}

///|
fn span_prefix(span : @parser.Span, width : Int) -> @parser.Span {
  @parser.Span::new(
    span.start,
    @parser.Position::new(
      span.start.offset + width,
      span.start.line,
      span.start.column + width,
    ),
  )
}

///|
fn effective_command_span(command : @parser.Command) -> @parser.Span {
  match @semantics.effective_command_words(command).get(0) {
    Some(word) => word.span
    None => command.span
  }
}

///|
fn command_keyword_span(
  command : @parser.Command,
  keyword : String,
) -> @parser.Span {
  span_prefix(command.span, keyword[:].length())
}

///|
fn redirect_operator_span(redirect : @parser.Redirection) -> @parser.Span {
  span_prefix(redirect.span, redirection_operator_width(redirect))
}

///|
fn redirection_operator_width(redirect : @parser.Redirection) -> Int {
  let base = match redirect.op {
    @parser.RedirectionOperator::Read | @parser.RedirectionOperator::Write => 1
    @parser.RedirectionOperator::Append
    | @parser.RedirectionOperator::ReadWrite
    | @parser.RedirectionOperator::Clobber
    | @parser.RedirectionOperator::HereDoc
    | @parser.RedirectionOperator::DupInput
    | @parser.RedirectionOperator::DupOutput => 2
    @parser.RedirectionOperator::HereDocStrip
    | @parser.RedirectionOperator::HereString => 3
  }
  match redirect.source {
    Some(@parser.RedirectionSource::All) => base + 1
    _ => base
  }
}

///|
fn assignment_name_span(assignment : @parser.Assignment) -> @parser.Span {
  span_prefix(assignment.span, assignment.name[:].length())
}

///|
fn array_assignment_value_span(assignment : @parser.Assignment) -> @parser.Span {
  if assignment.indexes.length() > 0 {
    return assignment.span
  }
  let operator_width = if assignment.append { 2 } else { 1 }
  let value_offset = assignment.name[:].length() + operator_width
  @parser.Span::new(
    @parser.Position::new(
      assignment.span.start.offset + value_offset,
      assignment.span.start.line,
      assignment.span.start.column + value_offset,
    ),
    assignment.span.end,
  )
}
