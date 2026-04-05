///|
fn[A] checks_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn parse_checks_ok(source : String) -> @parser.Script {
  match @parser.parse_script(source) {
    Ok(script) => script
    Err(error) => checks_fail(error.to_string())
  }
}

///|
fn check_source(source : String) -> Array[CheckDiagnostic] {
  check_script(parse_checks_ok(source))
}

///|
fn has_code(diagnostics : Array[CheckDiagnostic], code : Int) -> Bool {
  diagnostics.any(fn(diagnostic) { diagnostic.code == code })
}

///|
fn count_code(diagnostics : Array[CheckDiagnostic], code : Int) -> Int {
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
  diagnostics : Array[CheckDiagnostic],
  code : Int,
) -> CheckDiagnostic {
  for diagnostic in diagnostics {
    if diagnostic.code == code {
      return diagnostic
    }
  }
  checks_fail("missing diagnostic code \{code}")
}
