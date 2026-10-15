///|
fn[A] checks_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn parse_checks_ok(source : String) -> @parser.Script {
  match test_parse_script(source) {
    Ok(script) => script
    Err(error) => checks_fail(Show::to_string(error))
  }
}

///|
fn check_source(source : String) -> Array[@checks.CheckDiagnostic] {
  test_check_parsed_script(parse_checks_ok(source))
}

///|
fn has_code(diagnostics : Array[@checks.CheckDiagnostic], code : Int32) -> Bool {
  diagnostics.any(fn(diagnostic) { diagnostic.code == code })
}

///|
fn count_code(
  diagnostics : Array[@checks.CheckDiagnostic],
  code : Int32,
) -> Int32 {
  let mut count = 0
  for diagnostic in diagnostics {
    if diagnostic.code == code {
      count += 1
    }
  }
  count
}

///|
fn first_code(
  diagnostics : Array[@checks.CheckDiagnostic],
  code : Int32,
) -> @checks.CheckDiagnostic {
  for diagnostic in diagnostics {
    if diagnostic.code == code {
      return diagnostic
    }
  }
  checks_fail("missing diagnostic code \{code}")
}

///|
fn assert_check_diagnostics(
  diagnostics : Array[@checks.CheckDiagnostic],
  expected : Array[(String, Int32, Int32, Int32, String)],
) -> Unit raise {
  let actual = diagnostics.map(fn(diagnostic) {
    (
      match diagnostic.severity {
        Error => "error"
        Warning => "warning"
        Info => "info"
        Style => "style"
      },
      diagnostic.code,
      diagnostic.span.start.line,
      diagnostic.span.start.column,
      diagnostic.message,
    )
  })
  @test.assert_eq(actual, expected)
}
