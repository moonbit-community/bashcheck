///|
fn append_analytics_batch_g_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_g_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_g_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2004,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Use $foo or ${foo} directly in arithmetic expressions.",
    },
    {
      code: 2017,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Prefer multiplying before dividing when the divisor repeats.",
    },
    {
      code: 2071,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "String-style comparison operators are being used for numeric comparisons.",
    },
    {
      code: 2072,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Decimals are not supported in shell numeric comparisons.",
    },
    {
      code: 2073,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Escape < and > in [ ] comparisons so they are not treated as redirections.",
    },
    {
      code: 2122,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Use numeric operators that match the shell's test syntax.",
    },
    {
      code: 2170,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Numeric test operators need numeric operands in single-bracket tests.",
    },
    {
      code: 2057,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Unknown binary condition operator.",
    },
    {
      code: 2058,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Unknown unary condition operator.",
    },
    {
      code: 2254,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Quote expansions in case patterns when literal matching is intended.",
    },
    {
      code: 2309,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Quoted or literal strings are being compared numerically.",
    },
  ]
}

///|
fn run_analytics_batch_g_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_valid_cond_ops(script, diagnostics)
  check_number_comparisons(script, shell, diagnostics)
  check_div_before_mult(script, diagnostics)
  check_arithmetic_deref(script, diagnostics)
  check_case_against_glob(script, diagnostics)
}

///|
fn check_valid_cond_ops(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        g_visit_condition_ops(condition.expr, diagnostics)
      _ => ()
    }
  })
}

///|
fn g_visit_condition_ops(
  expr : @parser.ConditionExpr,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match expr {
    @parser.ConditionExpr::Unary(op, op_span, _) =>
      if !@semantics.unary_test_operators().contains(op) {
        push_diagnostic(
          diagnostics,
          op_span,
          CheckSeverity::Warning,
          2058,
          "Unknown unary operator.",
        )
      }
    @parser.ConditionExpr::Binary(op, op_span, _, _) => {
      let normalized = g_normalize_cond_op(op)
      if !@semantics.binary_test_operators().contains(normalized) {
        push_diagnostic(
          diagnostics,
          op_span,
          CheckSeverity::Warning,
          2057,
          "Unknown binary operator.",
        )
      }
    }
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      g_visit_condition_ops(inner, diagnostics)
    @parser.ConditionExpr::And(lhs, rhs)
    | @parser.ConditionExpr::Or(lhs, rhs) => {
      g_visit_condition_ops(lhs, diagnostics)
      g_visit_condition_ops(rhs, diagnostics)
    }
    @parser.ConditionExpr::Empty | @parser.ConditionExpr::Word(_) => ()
  }
}

///|
fn check_number_comparisons(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        g_visit_condition_binaries(condition.expr, fn(op, lhs, rhs) {
          let op = g_normalize_cond_op(op)
          if g_is_numeric_test_op(op) {
            g_maybe_push_numeric_comparison_diagnostic(
              shell,
              condition.kind,
              op,
              lhs,
              rhs,
              diagnostics,
            )
          } else if g_is_string_comparison_op(op) {
            g_maybe_push_string_comparison_diagnostic(
              condition.kind,
              op,
              lhs,
              rhs,
              diagnostics,
            )
          }
        })
      _ => ()
    }
  })
}

///|
fn g_visit_condition_binaries(
  expr : @parser.ConditionExpr,
  visit : (String, @parser.Word, @parser.Word) -> Unit,
) -> Unit {
  match expr {
    @parser.ConditionExpr::Binary(op, _, lhs, rhs) => visit(op, lhs, rhs)
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      g_visit_condition_binaries(inner, visit)
    @parser.ConditionExpr::And(lhs, rhs)
    | @parser.ConditionExpr::Or(lhs, rhs) => {
      g_visit_condition_binaries(lhs, visit)
      g_visit_condition_binaries(rhs, visit)
    }
    _ => ()
  }
}

///|
fn g_normalize_cond_op(op : String) -> String {
  if op.has_prefix("\\") {
    op.view(start_offset=1).to_string()
  } else {
    op
  }
}

///|
fn g_is_numeric_test_op(op : String) -> Bool {
  ["-eq", "-ne", "-lt", "-le", "-gt", "-ge"].contains(op)
}

///|
fn g_is_string_comparison_op(op : String) -> Bool {
  ["<", ">", "<=", ">=", "\\<", "\\>", "\\<=", "\\>="].contains(op)
}

///|
fn g_maybe_push_numeric_comparison_diagnostic(
  shell : @semantics.ShellDialect,
  kind : @parser.ConditionKind,
  op : String,
  lhs : @parser.Word,
  rhs : @parser.Word,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  ignore(op)
  if g_word_looks_decimal(lhs) || g_word_looks_decimal(rhs) {
    push_diagnostic(
      diagnostics,
      lhs.span,
      CheckSeverity::Error,
      2072,
      "Decimals are not supported in shell numeric comparisons.",
    )
    return
  }

  if g_condition_kind_is_single_bracket(kind) &&
    g_numeric_comparison_uses_plain_string_operand(lhs, rhs) {
    push_diagnostic(
      diagnostics,
      rhs.span,
      CheckSeverity::Error,
      2170,
      "Invalid number for this test operator. Use a string comparison instead.",
    )
    return
  }

  if g_condition_kind_is_double_bracket(kind) &&
    g_numeric_comparison_uses_plain_string_operand(lhs, rhs) {
    push_diagnostic(
      diagnostics,
      rhs.span,
      CheckSeverity::Warning,
      2309,
      "Quoted or literal strings are being compared numerically.",
    )
  }
}

///|
fn g_maybe_push_string_comparison_diagnostic(
  kind : @parser.ConditionKind,
  op : String,
  lhs : @parser.Word,
  rhs : @parser.Word,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if g_condition_kind_is_single_bracket(kind) {
    push_diagnostic(
      diagnostics,
      rhs.span,
      CheckSeverity::Error,
      2073,
      "Escape < and > in [ ] comparisons so they are not treated as redirections.",
    )
    return
  }

  if (op == "<=" || op == ">=") && g_condition_kind_is_double_bracket(kind) {
    push_diagnostic(
      diagnostics,
      rhs.span,
      CheckSeverity::Error,
      2122,
      g_invalid_numeric_operator_message(op),
    )
    return
  }

  if g_word_is_numeric_like(lhs) || g_word_is_numeric_like(rhs) {
    push_diagnostic(
      diagnostics,
      rhs.span,
      CheckSeverity::Error,
      2071,
      g_numeric_operator_message(op),
    )
  }
}

///|
fn g_numeric_operator_message(op : String) -> String {
  match op {
    "<" => "< is for string comparisons. Use -lt instead."
    ">" => "> is for string comparisons. Use -gt instead."
    "<=" => "<= is not a valid operator. Use -le instead."
    ">=" => ">= is not a valid operator. Use -ge instead."
    _ => "Use the numeric comparison operator that matches your intent."
  }
}

///|
fn g_invalid_numeric_operator_message(op : String) -> String {
  match op {
    "<=" => "<= is not a valid operator. Use '! a > b' instead."
    ">=" => ">= is not a valid operator. Use '! a < b' instead."
    _ => "Use the numeric comparison operator that matches your intent."
  }
}

///|
fn g_word_looks_decimal(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some(text) => text.contains(".") && g_string_contains_digit(text)
    None => false
  }
}

///|
fn g_word_is_numeric_like(word : @parser.Word) -> Bool {
  if g_word_looks_decimal(word) {
    return true
  }
  match @semantics.literal_text(word) {
    Some(text) => text != "" && g_string_is_all_digits(text)
    None =>
      match word.parts {
        [@parser.WordPart::ArithmeticExpansion(_)]
        | [@parser.WordPart::DollarBracket(_)] => true
        _ => false
      }
  }
}

///|
fn g_word_is_plain_literal(word : @parser.Word) -> Bool {
  match word.parts {
    [@parser.WordPart::Literal(_)]
    | [@parser.WordPart::SingleQuoted(_)]
    | [@parser.WordPart::DollarSingleQuoted(_)] => true
    _ => false
  }
}

///|
fn g_numeric_comparison_uses_plain_string_operand(
  lhs : @parser.Word,
  rhs : @parser.Word,
) -> Bool {
  (g_word_is_plain_literal(lhs) && !g_word_is_numeric_like(lhs)) ||
  (g_word_is_plain_literal(rhs) && !g_word_is_numeric_like(rhs))
}

///|
fn check_div_before_mult(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    g_visit_command_arithmetic_exprs(command, fn(expr, span) {
      g_maybe_push_div_before_mult_diagnostic(expr, span, diagnostics)
    })
  })
}

///|
fn check_div_before_mult_expr(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  g_maybe_push_div_before_mult_diagnostic(expr, span, diagnostics)
}

///|
fn check_arithmetic_deref_expr(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  g_maybe_push_arithmetic_deref_diagnostic(expr, span, diagnostics)
}

///|
fn g_visit_command_arithmetic_exprs(
  command : @parser.Command,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  g_visit_direct_words_in_command(command, fn(word, _) {
    g_visit_word_arithmetic_exprs(word, visit)
  })
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      for assignment in simple.assignments {
        g_visit_assignment_index_arithmetic_exprs(assignment, visit)
      }
    @parser.CommandKind::Source(source) =>
      for assignment in source.assignments {
        g_visit_assignment_index_arithmetic_exprs(assignment, visit)
      }
    @parser.CommandKind::Arithmetic(arithmetic) =>
      visit(arithmetic.expr, command.span)
    @parser.CommandKind::ForArithmetic(clause) => {
      visit(clause.init, command.span)
      visit(clause.condition, command.span)
      visit(clause.step, command.span)
    }
    _ => ()
  }
}

///|
fn g_visit_direct_words_in_command(
  command : @parser.Command,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  match command.kind {
    @parser.CommandKind::Simple(simple) => {
      for assignment in simple.assignments {
        g_visit_assignment_value_words(assignment.value, visit)
      }
      if simple.words.length() > 0 {
        visit(simple.words[0], WordPlace::CommandName)
      }
      let mut i = 1
      while i < simple.words.length() {
        visit(simple.words[i], WordPlace::CommandArgument)
        i += 1
      }
    }
    @parser.CommandKind::Source(source) => {
      for assignment in source.assignments {
        g_visit_assignment_value_words(assignment.value, visit)
      }
      for option in source.options {
        visit(option, WordPlace::SourceOption)
      }
      visit(source.path, WordPlace::SourcePath)
      for arg in source.args {
        visit(arg, WordPlace::SourceArgument)
      }
    }
    @parser.CommandKind::Time(clause) =>
      for flag in clause.flags {
        visit(flag, WordPlace::TimeFlag)
      }
    @parser.CommandKind::ForIn(clause) =>
      for value in clause.values {
        visit(value, WordPlace::ForValue)
      }
    @parser.CommandKind::Select(clause) =>
      for value in clause.values {
        visit(value, WordPlace::SelectValue)
      }
    @parser.CommandKind::Case(clause) => {
      visit(clause.word, WordPlace::CaseWord)
      for item in clause.items {
        for pattern in item.patterns {
          visit(pattern, WordPlace::CasePattern)
        }
      }
    }
    @parser.CommandKind::Condition(condition) =>
      g_visit_condition_expr_words(condition.expr, condition.kind, visit)
    @parser.CommandKind::Arithmetic(command) =>
      g_visit_arithmetic_expr_words(command.expr, visit)
    @parser.CommandKind::ForArithmetic(clause) => {
      g_visit_arithmetic_expr_words(clause.init, visit)
      g_visit_arithmetic_expr_words(clause.condition, visit)
      g_visit_arithmetic_expr_words(clause.step, visit)
    }
    @parser.CommandKind::CoProc(clause) =>
      match clause.name {
        Some(name) => visit(name, WordPlace::CoProcName)
        None => ()
      }
    @parser.CommandKind::Subshell(_)
    | @parser.CommandKind::BraceGroup(_)
    | @parser.CommandKind::If(_)
    | @parser.CommandKind::While(_)
    | @parser.CommandKind::Until(_)
    | @parser.CommandKind::Function(_)
    | @parser.CommandKind::BatsTest(_) => ()
  }
  for redirect in command.redirects {
    match redirect.target {
      @parser.RedirectionTarget::Word(word) =>
        visit(word, WordPlace::RedirectionTarget)
      @parser.RedirectionTarget::HereDoc(_) => ()
    }
  }
}

///|
fn g_visit_assignment_value_words(
  value : @parser.AssignmentValue,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  match value {
    @parser.AssignmentValue::Empty => ()
    @parser.AssignmentValue::Word(word) =>
      visit(word, WordPlace::AssignmentValue)
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      for element in elements {
        g_visit_array_element_words(element, visit)
      }
  }
}

///|
fn g_visit_array_element_words(
  element : @parser.ArrayElement,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  g_visit_assignment_value_words(element.value, visit)
}

///|
fn g_visit_condition_expr_words(
  expr : @parser.ConditionExpr,
  kind : @parser.ConditionKind,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  let place = match kind {
    @parser.ConditionKind::SingleBracket => WordPlace::ConditionSingleBracket
    @parser.ConditionKind::DoubleBracket => WordPlace::ConditionDoubleBracket
  }
  match expr {
    @parser.ConditionExpr::Empty => ()
    @parser.ConditionExpr::Word(word) => visit(word, place)
    @parser.ConditionExpr::Unary(_, _, word) => visit(word, place)
    @parser.ConditionExpr::Binary(_, _, lhs, rhs) => {
      visit(lhs, place)
      visit(rhs, place)
    }
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      g_visit_condition_expr_words(inner, kind, visit)
    @parser.ConditionExpr::And(lhs, rhs)
    | @parser.ConditionExpr::Or(lhs, rhs) => {
      g_visit_condition_expr_words(lhs, kind, visit)
      g_visit_condition_expr_words(rhs, kind, visit)
    }
  }
}

///|
fn g_visit_arithmetic_expr_words(
  expr : @parser.ArithmeticExpr,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  for token in expr.tokens {
    match token {
      @parser.ArithmeticToken::Expansion(word) =>
        visit(word, WordPlace::ArithmeticWord)
      @parser.ArithmeticToken::Group(inner) =>
        g_visit_arithmetic_expr_words(inner, visit)
      _ => ()
    }
  }
}

///|
fn g_visit_assignment_index_arithmetic_exprs(
  assignment : @parser.Assignment,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  for index in assignment.indexes {
    g_visit_array_index_arithmetic_exprs(index, assignment.span, visit)
  }
  match assignment.value {
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      for element in elements {
        g_visit_array_element_index_arithmetic_exprs(
          element,
          assignment.span,
          visit,
        )
      }
    @parser.AssignmentValue::Word(_) | @parser.AssignmentValue::Empty => ()
  }
}

///|
fn g_visit_array_element_index_arithmetic_exprs(
  element : @parser.ArrayElement,
  span : @parser.Span,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  for index in element.indexes {
    g_visit_array_index_arithmetic_exprs(index, span, visit)
  }
  match element.value {
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      for nested in elements {
        g_visit_array_element_index_arithmetic_exprs(nested, span, visit)
      }
    @parser.AssignmentValue::Word(_) | @parser.AssignmentValue::Empty => ()
  }
}

///|
fn g_visit_array_index_arithmetic_exprs(
  index : @parser.ArrayIndex,
  span : @parser.Span,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  match index.arithmetic {
    Some(expr) => visit(expr, span)
    None => ()
  }
  for part in index.parts {
    g_visit_word_part_arithmetic_exprs(part, span, visit)
  }
}

///|
fn g_visit_word_arithmetic_exprs(
  word : @parser.Word,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  for part in word.parts {
    g_visit_word_part_arithmetic_exprs(part, word.span, visit)
  }
}

///|
fn g_visit_word_part_arithmetic_exprs(
  part : @parser.WordPart,
  span : @parser.Span,
  visit : (@parser.ArithmeticExpr, @parser.Span) -> Unit,
) -> Unit {
  match part {
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      for nested in parts {
        g_visit_word_part_arithmetic_exprs(nested, span, visit)
      }
    @parser.WordPart::BracedParameter(expansion) => {
      match expansion.index {
        Some(index) => g_visit_array_index_arithmetic_exprs(index, span, visit)
        None => ()
      }
      match expansion.operator {
        Some(@parser.ParameterOperator::Slice(offset, length)) => {
          visit(@parser.parse_arithmetic_expr(offset), span)
          match length {
            Some(length) => visit(@parser.parse_arithmetic_expr(length), span)
            None => ()
          }
        }
        _ => ()
      }
    }
    @parser.WordPart::ArithmeticExpansion(expr)
    | @parser.WordPart::DollarBracket(expr) => visit(expr, span)
    @parser.WordPart::ExtGlob(pattern) =>
      for alternative in pattern.alternatives {
        g_visit_word_arithmetic_exprs(alternative, visit)
      }
    @parser.WordPart::BraceExpansion(expansion) =>
      for element in expansion.elements {
        g_visit_word_arithmetic_exprs(element, visit)
      }
    _ => ()
  }
}

///|
fn g_maybe_push_div_before_mult_diagnostic(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let terms : Array[String] = []
  let ops : Array[String] = []
  let mut current : Array[@parser.ArithmeticToken] = []
  for token in expr.tokens {
    match token {
      @parser.ArithmeticToken::Operator(op) if op == "/" || op == "*" => {
        terms.push(g_arithmetic_tokens_signature(current))
        current = []
        ops.push(op)
      }
      _ => current.push(token)
    }
  }
  terms.push(g_arithmetic_tokens_signature(current))

  if ops.length() < 2 {
    return
  }
  let mut i = 0
  while i + 1 < ops.length() {
    if ops[i] == "/" && ops[i + 1] == "*" && terms[i + 1] != terms[i + 2] {
      push_diagnostic(
        diagnostics,
        span,
        CheckSeverity::Info,
        2017,
        "Increase precision by multiplying before dividing when the divisor repeats.",
      )
      return
    }
    i += 1
  }
}

///|
fn g_arithmetic_tokens_signature(
  tokens : Array[@parser.ArithmeticToken],
) -> String {
  let buf = StringBuilder::new()
  for token in tokens {
    buf.write_string(g_arithmetic_token_signature(token))
    buf.write_char('|')
  }
  buf.to_string()
}

///|
fn g_arithmetic_token_signature(token : @parser.ArithmeticToken) -> String {
  match token {
    @parser.ArithmeticToken::Literal(text) => "L:" + text
    @parser.ArithmeticToken::Operator(op) => "O:" + op
    @parser.ArithmeticToken::Variable(name, indexes) => {
      let buf = StringBuilder::new()
      buf.write_string("V:")
      buf.write_string(name)
      for index in indexes {
        buf.write_char('[')
        buf.write_string(index.raw)
        buf.write_char(']')
      }
      buf.to_string()
    }
    @parser.ArithmeticToken::Expansion(word) => "E:" + word.source
    @parser.ArithmeticToken::Group(expr) => "G:" + expr.raw
  }
}

///|
fn check_arithmetic_deref(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    g_visit_command_arithmetic_exprs(command, fn(expr, span) {
      g_maybe_push_arithmetic_deref_diagnostic(expr, span, diagnostics)
    })
  })
}

///|
fn g_maybe_push_arithmetic_deref_diagnostic(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let tokens = expr.tokens
  let mut i = 0
  while i < tokens.length() {
    match tokens[i] {
      @parser.ArithmeticToken::Expansion(word) =>
        if !g_token_is_base_prefix(tokens, i) &&
          g_word_is_arithmetic_deref(word) {
          push_diagnostic(
            diagnostics,
            span,
            CheckSeverity::Style,
            2004,
            "$foo or ${foo} is unnecessary on arithmetic variables.",
          )
          return
        }
      @parser.ArithmeticToken::Variable(_, indexes) =>
        for index in indexes {
          if g_array_index_is_arithmetic_deref(index) {
            push_diagnostic(
              diagnostics,
              span,
              CheckSeverity::Style,
              2004,
              "$foo or ${foo} is unnecessary on arithmetic variables.",
            )
            return
          }
        }
      @parser.ArithmeticToken::Group(inner) =>
        g_maybe_push_arithmetic_deref_diagnostic(inner, span, diagnostics)
      _ => ()
    }
    i += 1
  }
}

///|
fn g_token_is_base_prefix(
  tokens : Array[@parser.ArithmeticToken],
  index : Int,
) -> Bool {
  if index == 0 {
    return false
  }
  match tokens[index - 1] {
    @parser.ArithmeticToken::Literal(text) => text.has_suffix("#")
    _ => false
  }
}

///|
fn g_word_is_arithmetic_deref(word : @parser.Word) -> Bool {
  match word.parts {
    [@parser.WordPart::Parameter(name)] => !g_is_special_parameter(name)
    [@parser.WordPart::SpecialParameter(name)] => !g_is_special_parameter(name)
    [@parser.WordPart::BracedParameter(expansion)] =>
      g_braced_parameter_is_arithmetic_deref(expansion)
    _ => false
  }
}

///|
fn g_braced_parameter_is_arithmetic_deref(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  if expansion.length_prefix || expansion.indirect {
    return false
  }
  if expansion.index is Some(_) || expansion.operator is Some(_) {
    return false
  }
  match expansion.name {
    Some(name) => !g_is_special_parameter(name)
    None => false
  }
}

///|
fn g_is_special_parameter(name : String) -> Bool {
  if g_string_is_all_digits(name) {
    return true
  }
  ["@", "*", "#", "?", "-", "$", "!"].contains(name)
}

///|
fn g_array_index_is_arithmetic_deref(index : @parser.ArrayIndex) -> Bool {
  if index.parts.length() != 1 {
    return false
  }
  match index.parts[0] {
    @parser.WordPart::Parameter(name) => !g_is_special_parameter(name)
    @parser.WordPart::SpecialParameter(name) => !g_is_special_parameter(name)
    @parser.WordPart::BracedParameter(expansion) =>
      g_braced_parameter_is_arithmetic_deref(expansion)
    _ => false
  }
}

///|
fn check_case_against_glob(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Case(clause) =>
        for item in clause.items {
          for pattern in item.patterns {
            if !@semantics.is_glob_word(pattern) &&
              g_word_contains_quoteable_expansion(pattern) {
              push_diagnostic(
                diagnostics,
                pattern.span,
                CheckSeverity::Warning,
                2254,
                "Quote expansions in case patterns to match literally rather than as a glob.",
              )
            }
          }
        }
      _ => ()
    }
  })
}

///|
fn g_word_contains_quoteable_expansion(word : @parser.Word) -> Bool {
  let mut found = false
  walk_word_deep(word, fn(part) {
    if found {
      return
    }
    match part {
      @parser.WordPart::Parameter(_)
      | @parser.WordPart::SpecialParameter(_)
      | @parser.WordPart::BracedParameter(_)
      | @parser.WordPart::CommandSubstitution(_)
      | @parser.WordPart::BraceCommandSubstitution(_, _)
      | @parser.WordPart::BackQuoted(_)
      | @parser.WordPart::ArithmeticExpansion(_)
      | @parser.WordPart::DollarBracket(_)
      | @parser.WordPart::DollarSingleQuoted(_) => found = true
      _ => ()
    }
  })
  found
}

///|
fn g_condition_kind_is_single_bracket(kind : @parser.ConditionKind) -> Bool {
  match kind {
    @parser.ConditionKind::SingleBracket => true
    @parser.ConditionKind::DoubleBracket => false
  }
}

///|
fn g_condition_kind_is_double_bracket(kind : @parser.ConditionKind) -> Bool {
  match kind {
    @parser.ConditionKind::SingleBracket => false
    @parser.ConditionKind::DoubleBracket => true
  }
}

///|
fn g_string_contains_digit(text : String) -> Bool {
  for ch in text {
    if ch >= '0' && ch <= '9' {
      return true
    }
  }
  false
}

///|
fn g_string_is_all_digits(text : String) -> Bool {
  guard text != "" else { return false }
  for ch in text {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}
