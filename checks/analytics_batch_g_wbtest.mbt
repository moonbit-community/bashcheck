///|
fn[A] batch_g_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn parse_batch_g_ok(source : String) -> @parser.Script {
  match @parser.parse_script(source) {
    Ok(script) => script
    Err(error) => batch_g_fail(error.to_string())
  }
}

///|
fn batch_g_has_code(diagnostics : Array[CheckDiagnostic], code : Int) -> Bool {
  diagnostics.any(fn(diagnostic) { diagnostic.code == code })
}

///|
fn batch_g_count_code(diagnostics : Array[CheckDiagnostic], code : Int) -> Int {
  let mut count = 0
  for diagnostic in diagnostics {
    if diagnostic.code == code {
      count += 1
    }
  }
  count
}

///|
fn batch_g_diagnostics(source : String) -> Array[CheckDiagnostic] {
  let script = parse_batch_g_ok(source)
  let diagnostics : Array[CheckDiagnostic] = []
  run_analytics_batch_g_checks(
    script,
    @semantics.ShellDialect::Bash,
    diagnostics,
  )
  diagnostics
}

///|
fn check_div_before_mult_expr(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  g_maybe_push_div_before_mult_diagnostic(
    expr,
    span,
    Some(expr.raw),
    diagnostics,
  )
}

///|
fn check_arithmetic_deref_expr(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  g_maybe_push_arithmetic_deref_diagnostic(
    expr,
    span,
    Some(expr.raw),
    diagnostics,
  )
}

///|
test "analytics batch g flags div-before-mult from arithmetic expressions" {
  let diagnostics : Array[CheckDiagnostic] = []
  let expr = @parser.parse_arithmetic_expr("3 / 2 * 100")
  let span = @parser.Span::new(
    @parser.Position::new(0, 1, 1),
    @parser.Position::new(11, 1, 12),
  )
  check_div_before_mult_expr(expr, span, diagnostics)

  assert_eq(batch_g_count_code(diagnostics, 2017), 1)
}

///|
test "analytics batch g flags arithmetic deref from arithmetic expressions" {
  let diagnostics : Array[CheckDiagnostic] = []
  let expr = @parser.parse_arithmetic_expr("$foo")
  let span = @parser.Span::new(
    @parser.Position::new(0, 1, 1),
    @parser.Position::new(4, 1, 5),
  )
  check_arithmetic_deref_expr(expr, span, diagnostics)

  assert_eq(batch_g_count_code(diagnostics, 2004), 1)
}

///|
test "analytics batch g flags numeric comparison issues" {
  let diagnostics = batch_g_diagnostics(
    (
      #|#!/bin/bash
      #|[[ 10 < 3 ]]
      #|[[ 3.14 -eq 2 ]]
      #|[[ foo <= bar ]]
      #|[ foo \> bar ]
      #|[ foo -eq bar ]
      #|[[ foo -eq bar ]]
      #|
    ),
  )

  assert_eq(batch_g_count_code(diagnostics, 2071), 1)
  assert_eq(batch_g_count_code(diagnostics, 2072), 1)
  assert_eq(batch_g_count_code(diagnostics, 2073), 1)
  assert_eq(batch_g_count_code(diagnostics, 2122), 1)
  assert_eq(batch_g_count_code(diagnostics, 2170), 1)
  assert_eq(batch_g_count_code(diagnostics, 2309), 1)
}

///|
test "analytics batch g flags case patterns with quoteable expansions" {
  let diagnostics = batch_g_diagnostics(
    (
      #|#!/bin/bash
      #|case foo in
      #|  $bar) :;;
      #|  *$bar*) :;;
      #|esac
      #|
    ),
  )

  assert_eq(batch_g_count_code(diagnostics, 2254), 1)
}

///|
test "analytics batch g flags unknown condition operators after parser preserves them" {
  let diagnostics = batch_g_diagnostics(
    (
      #|#!/bin/bash
      #|[ -abc a ]
      #|[[ a -xyz b ]]
      #|[ 3 \> 2 ]
      #|[[ ! -v foo ]]
      #|
    ),
  )

  assert_eq(batch_g_count_code(diagnostics, 2057), 1)
  assert_eq(batch_g_count_code(diagnostics, 2058), 1)
  assert_true(!batch_g_has_code(diagnostics, 1073))
}

///|
test "analytics batch g ignores dash-prefixed non-operators" {
  let diagnostics = batch_g_diagnostics(
    (
      #|#!/bin/bash
      #|[ -1 ]
      #|[ -- ]
      #|[ -. ]
      #|
    ),
  )

  assert_true(!batch_g_has_code(diagnostics, 2057))
  assert_true(!batch_g_has_code(diagnostics, 2058))
}

///|
test "analytics batch g avoids false positives for safe forms" {
  let diagnostics = batch_g_diagnostics(
    (
      #|#!/bin/bash
      #|[[ foo == bar ]]
      #|[[ a != x || b != y ]]
      #|[[ a = x && b = y ]]
      #|[ foo = bar ] && [ baz = qux ]
      #|
    ),
  )

  assert_true(!batch_g_has_code(diagnostics, 2071))
  assert_true(!batch_g_has_code(diagnostics, 2072))
  assert_true(!batch_g_has_code(diagnostics, 2073))
  assert_true(!batch_g_has_code(diagnostics, 2122))
  assert_true(!batch_g_has_code(diagnostics, 2170))
  assert_true(!batch_g_has_code(diagnostics, 2254))
  assert_true(!batch_g_has_code(diagnostics, 2309))
}
