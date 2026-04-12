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
  check_unmatchable_cases(script, diagnostics)
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
  if text.has_prefix("[") {
    if exact {
      false
    } else {
      glob.push(PseudoGlob::Any)
      true
    }
  } else {
    for ch in text {
      if ch == '?' {
        glob.push(PseudoGlob::Any)
      } else if ch == '*' {
        glob.push(PseudoGlob::Many)
      } else if exact {
        return false
      } else {
        glob.push(PseudoGlob::Many)
        return true
      }
    }
    true
  }
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
