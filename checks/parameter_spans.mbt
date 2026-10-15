///|
fn control_flow_parameter_text(cfg : @cfg.CFG, id : @cfg.CfgAstId) -> String? {
  match @cfg.ast_ref_of(cfg, id) {
    Some(WordPart(Parameter(name) | SpecialParameter(name))) => Some("$" + name)
    Some(ParameterExpansion(expansion)) => Some("${\{expansion.raw}}")
    _ => None
  }
}

///|
fn control_flow_word_parameters(
  cfg : @cfg.CFG,
  id : @cfg.CfgAstId,
  needle : String,
  occurrences : Array[@cfg.CfgAstId],
) -> Unit {
  if control_flow_parameter_text(cfg, id) == Some(needle) {
    occurrences.push(id)
  }
  match @cfg.ast_ref_of(cfg, id) {
    Some(Word(_))
    | Some(
      WordPart(DoubleQuoted(_) | DollarDoubleQuoted(_) | BracedParameter(_))
    ) =>
      for child in @cfg.ast_children_of(cfg, id) {
        control_flow_word_parameters(cfg, child, needle, occurrences)
      }
    _ => () // Nested scripts and expansion operands own separate words.
  }
}

///|
/// Scan shell syntax, ignoring quoted literals, escaped dollars and nested
/// substitutions. Consume whole names so $foo never matches $foobar.
fn control_flow_parameter_range(
  source : String,
  needle : String,
  ordinal : Int32,
) -> (Int32, Int32)? {
  let text = source[:]
  let mut i = 0
  let mut quoted = false
  let mut remaining = ordinal
  while i < text.length() {
    if text[i] == '\\' && i + 1 < text.length() {
      // In double quotes a backslash only escapes these shell characters.
      if !quoted ||
        text[i + 1] == '$' ||
        text[i + 1] == '`' ||
        text[i + 1] == '"' ||
        text[i + 1] == '\\' ||
        text[i + 1] == '\n' {
        i += 2
        continue
      }
    }
    if text[i] == '"' {
      quoted = !quoted
      i += 1
      continue
    }
    if !quoted &&
      (
        text[i] == '\'' ||
        (text[i] == '$' && i + 1 < text.length() && text[i + 1] == '\'')
      ) {
      let ansi = text[i] == '$'
      i += if ansi { 2 } else { 1 }
      while i < text.length() && text[i] != '\'' {
        if ansi && text[i] == '\\' && i + 1 < text.length() {
          i += 1
        }
        i += 1
      }
      i += 1
      continue
    }
    if !quoted &&
      (text[i] == '<' || text[i] == '>') &&
      i + 1 < text.length() &&
      text[i + 1] == '(' {
      let rest = source.view(start_offset=i).to_owned()
      let prefix = source.view(start_offset=i, end_offset=i + 2).to_owned()
      i += analytics_prefixed_balanced_width(rest, prefix, '(', ')')
      continue
    }
    if text[i] == '`' {
      i += analytics_backquoted_width(source.view(start_offset=i).to_owned())
      continue
    }
    if text[i] != '$' || i + 1 >= text.length() {
      i += 1
      continue
    }
    let start = i
    let rest = source.view(start_offset=i).to_owned()
    if !quoted && text[i + 1] == '"' {
      i += 1
      continue
    }
    if text[i + 1] == '[' {
      i += analytics_prefixed_balanced_width(rest, "$[", '[', ']')
      continue
    }
    if text[i + 1] == '(' {
      i += analytics_command_substitution_width(rest)
      continue
    }
    if text[i + 1] == '{' {
      i += analytics_prefixed_balanced_width(rest, "${", '{', '}')
    } else if is_identifier_start(text[i + 1].unsafe_to_char()) {
      i += 2
      while i < text.length() &&
            is_identifier_continue(text[i].unsafe_to_char()) {
        i += 1
      }
    } else {
      i += 2
    }
    if source.view(start_offset=start, end_offset=i).to_owned() == needle {
      if remaining == 0 {
        return Some((start, i))
      }
      remaining -= 1
    }
  }
  None
}

///|
fn control_flow_word_position(
  word : @parser.Word,
  offset : Int32,
) -> @parser.Position {
  let mut line = word.span.start.line
  let mut column = word.span.start.column
  for ch in word.source.view(end_offset=offset) {
    if ch == '\n' {
      line += 1
      column = 1
    } else {
      column += ch.to_string().length()
    }
  }
  @parser.Position::new(
    word.span.start.offset + offset,
    line,
    column,
    source_id=word.span.start.source_id,
  )
}
