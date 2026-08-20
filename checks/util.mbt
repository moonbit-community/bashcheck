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
    DoubleQuoted(parts) | DollarDoubleQuoted(parts) =>
      walk_word_parts_deep(parts, visit)
    BracedParameter(expansion) =>
      walk_parameter_expansion_parts(expansion, visit)
    ArithmeticExpansion(expr) | DollarBracket(expr) =>
      walk_arithmetic_expr_word_parts(expr, visit)
    ExtGlob(pattern) =>
      for alternative in pattern.alternatives {
        walk_word_deep(alternative, visit)
      }
    BraceExpansion(expansion) =>
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
    Some(Slice(offset, length)) => {
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
    Some(Replace(_, pattern, replacement)) => {
      walk_word_deep(@parser.parse_text_as_word(pattern), visit)
      match replacement {
        Some(replacement) =>
          walk_word_deep(@parser.parse_text_as_word(replacement), visit)
        None => ()
      }
    }
    Some(CaseModify(_, Some(pattern))) =>
      walk_word_deep(@parser.parse_text_as_word(pattern), visit)
    Some(DefaultValue(text))
    | Some(AssignDefault(text))
    | Some(ErrorValue(text))
    | Some(AlternateValue(text))
    | Some(RemoveShortestPrefix(text))
    | Some(RemoveLongestPrefix(text))
    | Some(RemoveShortestSuffix(text))
    | Some(RemoveLongestSuffix(text))
    | Some(Transform(text))
    | Some(Raw(text)) => walk_word_deep(@parser.parse_text_as_word(text), visit)
    Some(Names(_)) | Some(CaseModify(_, None)) | None => ()
  }
}

///|
fn walk_arithmetic_expr_word_parts(
  expr : @parser.ArithmeticExpr,
  visit : (@parser.WordPart) -> Unit,
) -> Unit {
  for token in expr.tokens {
    match token {
      Expansion(word) => walk_word_deep(word, visit)
      Group(inner) => walk_arithmetic_expr_word_parts(inner, visit)
      Variable(_, indexes) =>
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
      BackQuoted(script) if script.items.length() > 0 => found = true
      _ => ()
    }
  })
  found
}

///|
fn word_has_top_level_command_substitution(word : @parser.Word) -> Bool {
  for part in word.parts {
    match part {
      CommandSubstitution(script)
      | BraceCommandSubstitution(_, script)
      | BackQuoted(script) => if script.items.length() > 0 { return true }
      _ => ()
    }
  }
  false
}

///|
fn word_is_plain_double_quoted(word : @parser.Word) -> Array[@parser.WordPart]? {
  match word.parts {
    [DoubleQuoted(parts)] => Some(parts)
    _ => None
  }
}

///|
fn word_is_plain_single_quoted(word : @parser.Word) -> Bool {
  match word.parts {
    [SingleQuoted(_)] => true
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
    [CommandSubstitution(script)]
    | [BraceCommandSubstitution(_, script)]
    | [BackQuoted(script)] => Some(script)
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
  shell_is_one_of(shell, [Sh, Dash, BusyboxSh])
}

///|
fn word_is_just_command_output(word : @parser.Word) -> Bool {
  match word.parts {
    [CommandSubstitution(script)]
    | [BraceCommandSubstitution(_, script)]
    | [BackQuoted(script)] => substitution_script_has_named_command(script)
    [DoubleQuoted(parts)] | [DollarDoubleQuoted(parts)] =>
      quoted_parts_are_just_command_output(parts)
    _ => false
  }
}

///|
fn quoted_parts_are_just_command_output(
  parts : Array[@parser.WordPart],
) -> Bool {
  match parts {
    [CommandSubstitution(script)]
    | [BraceCommandSubstitution(_, script)]
    | [BackQuoted(script)] => substitution_script_has_named_command(script)
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
    Some(Names(_)) => true
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
    Some(DefaultValue(_))
    | Some(AssignDefault(_))
    | Some(ErrorValue(_))
    | Some(AlternateValue(_)) => true
    Some(Raw(text)) =>
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
fn shellcheck_position_offset(
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
fn shellcheck_surround_span_fix(
  span : @parser.Span,
  text : String,
  precedence : Int,
) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      span.start,
      span.start,
      text,
      precedence,
      @fixer.InsertionPoint::after(),
    ),
    @fixer.Replacement::new(
      "",
      span.end,
      span.end,
      text,
      precedence,
      @fixer.InsertionPoint::before(),
    ),
  ])
}

///|
fn shellcheck_brace_parameter_span_fix(
  span : @parser.Span,
  precedence : Int,
) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      span.start,
      shellcheck_position_offset(span.start, 1),
      "${",
      precedence,
      @fixer.InsertionPoint::after(),
    ),
    @fixer.Replacement::new(
      "",
      span.end,
      span.end,
      "}",
      precedence,
      @fixer.InsertionPoint::before(),
    ),
  ])
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
fn span_suffix(span : @parser.Span, width : Int) -> @parser.Span {
  @parser.Span::new(
    @parser.Position::new(
      span.end.offset - width,
      span.end.line,
      span.end.column - width,
    ),
    span.end,
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
  match (redirect.op, redirect.target) {
    (HereDoc | HereDocStrip, HereDoc(doc)) =>
      return span_suffix(redirect.span, here_doc_delimiter_width(doc))
    _ => ()
  }
  span_prefix(redirect.span, redirection_operator_width(redirect))
}

///|
fn here_doc_delimiter_width(doc : @parser.HereDoc) -> Int {
  if doc.quoted {
    doc.delimiter.length() + 2
  } else {
    doc.delimiter.length()
  }
}

///|
fn redirection_operator_width(redirect : @parser.Redirection) -> Int {
  let base = match redirect.op {
    Read | Write => 1
    Append | ReadWrite | Clobber | HereDoc | DupInput | DupOutput => 2
    HereDocStrip | HereString => 3
  }
  match redirect.source {
    Some(All) => base + 1
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
