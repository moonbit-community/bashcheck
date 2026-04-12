///|
fn[A] batch_f_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn parse_batch_f_ok(source : String) -> @parser.Script {
  match @parser.parse_script(source) {
    Ok(script) => script
    Err(error) => batch_f_fail(error.to_string())
  }
}

///|
fn batch_f_count_code(diagnostics : Array[CheckDiagnostic], code : Int) -> Int {
  let mut count = 0
  for diagnostic in diagnostics {
    if diagnostic.code == code {
      count += 1
    }
  }
  count
}

///|
fn batch_f_diagnostics(source : String) -> Array[CheckDiagnostic] {
  let script = parse_batch_f_ok(source)
  let diagnostics : Array[CheckDiagnostic] = []
  run_analytics_batch_f_checks(
    script,
    @semantics.ShellDialect::Bash,
    diagnostics,
  )
  diagnostics
}

///|
test "analytics batch f flags shorthand if when rhs is not a safe fallback" {
  let diagnostics = batch_f_diagnostics(
    (
      #|#!/bin/bash
      #|foo && bar || baz
      #|foo && bar || true
      #|foo && echo ok || baz
      #|foo && [ -n x ] || baz
      #|
    ),
  )

  assert_eq(batch_f_count_code(diagnostics, 2015), 2)
}

///|
test "analytics batch f flags repeated inequality comparisons" {
  let diagnostics = batch_f_diagnostics(
    (
      #|#!/bin/bash
      #|[[ $a != x || $a != y ]]
      #|[ $a != x -o $a != y ]
      #|[ $a != x ] || [ $a != y ]
      #|(( a!=1 || a!=2 ))
      #|[[ $a != */x/* || $a != y ]]
      #|[ $a != x ] || [ $b != y ]
      #|
    ),
  )

  assert_eq(batch_f_count_code(diagnostics, 2055), 1)
  assert_eq(batch_f_count_code(diagnostics, 2056), 2)
  assert_eq(batch_f_count_code(diagnostics, 2252), 1)
}

///|
test "analytics batch f flags repeated equality comparisons" {
  let diagnostics = batch_f_diagnostics(
    (
      #|#!/bin/bash
      #|[[ a = x && a = y ]]
      #|[ $a = x ] && [ $a = y ]
      #|[ a = x -a a = y ]
      #|[ 1 -eq $x ] && [ $x -eq 2 ]
      #|(( a==1 && a==2 ))
      #|[[ a = x && b = y ]]
      #|[ a = x ] && [ b = y ]
      #|[ $a = $b ] && [ $a = $c ]
      #|(( a==1 && b==2 ))
      #|
    ),
  )

  assert_eq(batch_f_count_code(diagnostics, 2333), 4)
  assert_eq(batch_f_count_code(diagnostics, 2334), 1)
}
