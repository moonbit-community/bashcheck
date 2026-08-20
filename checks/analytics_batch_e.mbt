///|
fn append_analytics_batch_e_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_e_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_e_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2070,
      severity: Error,
      category: "analytics",
      summary: "-n requires quoting or [[ ]] when arguments may split.",
    },
    {
      code: 2077,
      severity: Error,
      category: "analytics",
      summary: "Missing spaces around test comparison operators change parsing.",
    },
    {
      code: 2078,
      severity: Error,
      category: "analytics",
      summary: "Nullary test expressions are constant and likely missing $.",
    },
    {
      code: 2080,
      severity: Error,
      category: "analytics",
      summary: "Leading-zero arithmetic literals are parsed as octal.",
    },
    {
      code: 2157,
      severity: Error,
      category: "analytics",
      summary: "Literal strings make this test expression always true or false.",
    },
    {
      code: 2158,
      severity: Error,
      category: "analytics",
      summary: "[ false ] is true because test sees a non-empty string.",
    },
    {
      code: 2159,
      severity: Error,
      category: "analytics",
      summary: "[ 0 ] is true because test sees a non-empty string.",
    },
    {
      code: 2160,
      severity: Style,
      category: "analytics",
      summary: "Use true directly instead of [ true ].",
    },
    {
      code: 2161,
      severity: Style,
      category: "analytics",
      summary: "Use true directly instead of [ 1 ].",
    },
  ]
}

///|
fn run_analytics_batch_e_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_unquoted_n(script, diagnostics)
  check_literal_breaking_tests(script, diagnostics)
  check_constant_nullary_conditions(script, diagnostics)
  check_arithmetic_bad_octal(script, diagnostics)
}

///|
fn check_unquoted_n(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      Condition(condition) =>
        match condition.kind {
          SingleBracket => visit_unquoted_n_nodes(condition.expr, diagnostics)
          DoubleBracket => ()
        }
      _ => ()
    }
  })
}

///|
fn visit_unquoted_n_nodes(
  expr : @parser.ConditionExpr,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match expr {
    Unary("-n", _, word) =>
      if word_may_expand_to_multiple(word) &&
        !analytics_word_has_any_array_expansion(word) {
        push_diagnostic(
          diagnostics,
          word.span,
          Error,
          2070,
          "-n doesn't work with unquoted arguments. Quote or use [[ ]].",
        )
      }
    Group(inner) | Not(inner) => visit_unquoted_n_nodes(inner, diagnostics)
    And(_, lhs, rhs) | Or(_, lhs, rhs) => {
      visit_unquoted_n_nodes(lhs, diagnostics)
      visit_unquoted_n_nodes(rhs, diagnostics)
    }
    Empty | Word(_) | Unary(_, _, _) | Binary(_, _, _, _) => ()
  }
}

///|
fn analytics_word_has_any_array_expansion(word : @parser.Word) -> Bool {
  let mut found = false
  walk_word_deep(word, fn(part) {
    if found {
      return
    }
    match part {
      SpecialParameter(name) => if name == "@" || name == "*" { found = true }
      BracedParameter(expansion) =>
        if analytics_parameter_is_any_array_expansion(expansion) {
          found = true
        }
      _ => ()
    }
  })
  found
}

///|
fn analytics_parameter_is_any_array_expansion(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  if expansion.length_prefix {
    return false
  }
  match expansion.index {
    Some(index) => index.raw == "@" || index.raw == "*"
    None =>
      match expansion.name {
        Some("@") | Some("*") => true
        _ => false
      }
  }
}

///|
fn check_literal_breaking_tests(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      Condition(condition) =>
        visit_literal_breaking_nodes(condition.expr, diagnostics)
      _ => ()
    }
  })
}

///|
fn visit_literal_breaking_nodes(
  expr : @parser.ConditionExpr,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match expr {
    Word(word) =>
      maybe_push_nullary_literal_breaking_diagnostic(word, diagnostics)
    Unary(op, _, word) =>
      maybe_push_unary_literal_breaking_diagnostic(op, word, diagnostics)
    Group(inner) | Not(inner) =>
      visit_literal_breaking_nodes(inner, diagnostics)
    And(_, lhs, rhs) | Or(_, lhs, rhs) => {
      visit_literal_breaking_nodes(lhs, diagnostics)
      visit_literal_breaking_nodes(rhs, diagnostics)
    }
    Empty | Binary(_, _, _, _) => ()
  }
}

///|
fn maybe_push_nullary_literal_breaking_diagnostic(
  word : @parser.Word,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard !analytics_condition_word_is_constant(word) else { return }
  if analytics_condition_parts_contain_equals(word.parts) {
    let diagnostic_span = match string_index_of(word.source, "=") {
      Some(offset) =>
        analytics_span_offset(word.span, offset, word.source.length() - offset)
      None => word.span
    }
    push_diagnostic(
      diagnostics,
      diagnostic_span,
      Error,
      2077,
      "You need spaces around the comparison operator.",
    )
    return
  }
  guard analytics_condition_parts_have_non_empty_literal(word.parts) else {
    return
  }
  push_diagnostic(
    diagnostics,
    word.span,
    Error,
    2157,
    "Argument to implicit -n is always true due to literal strings.",
  )
}

///|
fn maybe_push_unary_literal_breaking_diagnostic(
  op : String,
  word : @parser.Word,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard op == "-n" || op == "-z" else { return }
  guard analytics_condition_parts_have_non_empty_literal(word.parts) else {
    return
  }
  push_diagnostic(
    diagnostics,
    word.span,
    Error,
    2157,
    if op == "-n" {
      "Argument to -n is always true due to literal strings."
    } else {
      "Argument to -z is always false due to literal strings."
    },
  )
}

///|
fn analytics_condition_parts_have_non_empty_literal(
  parts : Array[@parser.WordPart],
) -> Bool {
  for part in parts {
    match part {
      Literal(text) | SingleQuoted(text) | DollarSingleQuoted(text) =>
        if text != "" {
          return true
        }
      DoubleQuoted(nested) | DollarDoubleQuoted(nested) =>
        if analytics_condition_parts_have_non_empty_literal(nested) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn analytics_condition_parts_contain_equals(
  parts : Array[@parser.WordPart],
) -> Bool {
  for part in parts {
    match part {
      Literal(text) | SingleQuoted(text) | DollarSingleQuoted(text) =>
        if text.contains("=") {
          return true
        }
      DoubleQuoted(nested) | DollarDoubleQuoted(nested) =>
        if analytics_condition_parts_contain_equals(nested) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn check_constant_nullary_conditions(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      Condition(condition) =>
        visit_constant_nullary_nodes(condition.expr, diagnostics)
      _ => ()
    }
  })
}

///|
fn visit_constant_nullary_nodes(
  expr : @parser.ConditionExpr,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match expr {
    Word(word) => maybe_push_constant_nullary_diagnostic(word, diagnostics)
    Group(inner) | Not(inner) =>
      visit_constant_nullary_nodes(inner, diagnostics)
    And(_, lhs, rhs) | Or(_, lhs, rhs) => {
      visit_constant_nullary_nodes(lhs, diagnostics)
      visit_constant_nullary_nodes(rhs, diagnostics)
    }
    Empty | Unary(_, _, _) | Binary(_, _, _, _) => ()
  }
}

///|
fn maybe_push_constant_nullary_diagnostic(
  word : @parser.Word,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard analytics_condition_word_is_constant(word) else { return }
  let text = match @semantics.literal_text(word) {
    Some(text) => text
    None => return
  }
  let (severity, code, message) = match text {
    "false" =>
      (CheckSeverity::Error, 2158, "[ false ] is true. Remove the brackets.")
    "0" => (Error, 2159, "[ 0 ] is true. Use 'false' instead.")
    "true" => (Style, 2160, "Instead of '[ true ]', just use 'true'.")
    "1" => (Style, 2161, "Instead of '[ 1 ]', use 'true'.")
    _ =>
      (
        Error,
        2078,
        "This expression is constant. Did you forget a $ somewhere?",
      )
  }
  push_diagnostic(diagnostics, word.span, severity, code, message)
}

///|
fn check_arithmetic_bad_octal(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_command_arithmetic_exprs(command, fn(expr, span) {
      maybe_push_arithmetic_bad_octal_diagnostic(expr, span, diagnostics)
    })
  })
}

///|
fn visit_command_arithmetic_exprs(
  command : @parser.Command,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  visit_direct_words_in_command(command, fn(word, _) {
    visit_word_arithmetic_exprs(word, visit)
  })
  match command.kind {
    Simple(simple) =>
      for assignment in simple.assignments {
        visit_assignment_index_arithmetic_exprs(assignment, visit)
      }
    Source(source) =>
      for assignment in source.assignments {
        visit_assignment_index_arithmetic_exprs(assignment, visit)
      }
    Arithmetic(arithmetic) => visit(arithmetic.expr, command.span)
    ForArithmetic(clause) => {
      visit(clause.init, command.span)
      visit(clause.condition, command.span)
      visit(clause.step, command.span)
    }
    _ => ()
  }
}

///|
fn visit_assignment_index_arithmetic_exprs(
  assignment : @parser.Assignment,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  for index in assignment.indexes {
    visit_array_index_arithmetic_exprs(index, assignment.span, visit)
  }
  match assignment.value {
    ArrayLiteral(elements) =>
      for element in elements {
        visit_array_element_index_arithmetic_exprs(
          element,
          assignment.span,
          visit,
        )
      }
    Word(_) | Empty => ()
  }
}

///|
fn visit_array_element_index_arithmetic_exprs(
  element : @parser.ArrayElement,
  span : @parser.Span,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  for index in element.indexes {
    visit_array_index_arithmetic_exprs(index, span, visit)
  }
  match element.value {
    ArrayLiteral(elements) =>
      for nested in elements {
        visit_array_element_index_arithmetic_exprs(nested, span, visit)
      }
    Word(_) | Empty => ()
  }
}

///|
fn visit_array_index_arithmetic_exprs(
  index : @parser.ArrayIndex,
  span : @parser.Span,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  match index.arithmetic {
    Some(expr) => visit(expr, span)
    None => ()
  }
  for part in index.parts {
    visit_word_part_arithmetic_exprs(part, span, visit)
  }
}

///|
fn visit_word_arithmetic_exprs(
  word : @parser.Word,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  for part in word.parts {
    visit_word_part_arithmetic_exprs(part, word.span, visit)
  }
}

///|
fn visit_word_part_arithmetic_exprs(
  part : @parser.WordPart,
  span : @parser.Span,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  match part {
    DoubleQuoted(parts) | DollarDoubleQuoted(parts) =>
      for nested in parts {
        visit_word_part_arithmetic_exprs(nested, span, visit)
      }
    BracedParameter(expansion) => {
      match expansion.index {
        Some(index) => visit_array_index_arithmetic_exprs(index, span, visit)
        None => ()
      }
      match expansion.operator {
        Some(Slice(offset, length)) => {
          visit(@parser.parse_arithmetic_expr(offset), span)
          match length {
            Some(length) => visit(@parser.parse_arithmetic_expr(length), span)
            None => ()
          }
        }
        _ => ()
      }
    }
    ArithmeticExpansion(expr) | DollarBracket(expr) => visit(expr, span)
    ExtGlob(pattern) =>
      for alternative in pattern.alternatives {
        visit_word_arithmetic_exprs(alternative, visit)
      }
    BraceExpansion(expansion) =>
      for element in expansion.elements {
        visit_word_arithmetic_exprs(element, visit)
      }
    _ => ()
  }
}

///|
fn maybe_push_arithmetic_bad_octal_diagnostic(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for token in expr.tokens {
    match token {
      Literal(text) =>
        if arithmetic_literal_has_bad_octal(text) {
          push_diagnostic(
            diagnostics,
            span,
            Error,
            2080,
            "Numbers with leading 0 are considered octal.",
          )
        }
      Variable(_, indexes) =>
        for index in indexes {
          visit_array_index_arithmetic_exprs(index, span, fn(
            inner,
            inner_span,
          ) {
            maybe_push_arithmetic_bad_octal_diagnostic(
              inner, inner_span, diagnostics,
            )
          })
        }
      Expansion(word) =>
        visit_word_arithmetic_exprs(word, fn(inner, inner_span) {
          maybe_push_arithmetic_bad_octal_diagnostic(
            inner, inner_span, diagnostics,
          )
        })
      Group(inner) =>
        maybe_push_arithmetic_bad_octal_diagnostic(inner, span, diagnostics)
      Operator(_) => ()
    }
  }
}

///|
fn arithmetic_literal_has_bad_octal(text : String) -> Bool {
  let view = text[:]
  guard view.length() >= 2 else { return false }
  guard view[0] == '0' else { return false }
  if view.length() >= 2 && (view[1] == 'x' || view[1] == 'X') {
    return false
  }
  let mut i = 1
  let mut saw_digit = false
  while i < view.length() {
    let ch = view[i]
    if ch >= '0' && ch <= '7' {
      saw_digit = true
      i += 1
      continue
    }
    if ch == '8' || ch == '9' {
      return saw_digit || i > 1
    }
    return false
  }
  false
}
