///|
fn append_analytics_batch_r_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_r_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_r_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2331,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "For file existence, prefer standard -e over legacy -a.",
    },
  ]
}

///|
fn run_analytics_batch_r_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_unary_test_a(script, diagnostics)
}

///|
fn check_unary_test_a(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        r_visit_condition_unary_test_a(condition.expr, 0, diagnostics)
      _ => ()
    }
  })
}

///|
fn r_visit_condition_unary_test_a(
  expr : @parser.ConditionExpr,
  nesting_depth : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match expr {
    @parser.ConditionExpr::Unary(op, op_span, _) =>
      if op == "-a" {
        push_diagnostic_with_fix(
          diagnostics,
          op_span,
          CheckSeverity::Style,
          2331,
          "For file existence, prefer standard -e over legacy -a.",
          r_replace_span_fix(op_span, "-e", 6 + nesting_depth),
        )
      }
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      r_visit_condition_unary_test_a(inner, nesting_depth + 1, diagnostics)
    @parser.ConditionExpr::And(_, lhs, rhs)
    | @parser.ConditionExpr::Or(_, lhs, rhs) => {
      r_visit_condition_unary_test_a(lhs, nesting_depth + 1, diagnostics)
      r_visit_condition_unary_test_a(rhs, nesting_depth + 1, diagnostics)
    }
    @parser.ConditionExpr::Empty
    | @parser.ConditionExpr::Word(_)
    | @parser.ConditionExpr::Binary(_, _, _, _) => ()
  }
}

///|
fn r_replace_span_fix(
  span : @parser.Span,
  text : String,
  precedence : Int,
) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      span.start,
      span.end,
      text,
      precedence,
      @fixer.InsertionPoint::after(),
    ),
  ])
}
