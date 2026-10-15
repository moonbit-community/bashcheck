///|
struct TestCheckOptions {
  shell_override : @semantics.ShellDialect?
  filename : String?
  extended_analysis : Bool
  optional_checks : Array[String]
}

///|
fn TestCheckOptions::default() -> TestCheckOptions {
  {
    shell_override: None,
    filename: None,
    extended_analysis: false,
    optional_checks: [],
  }
}

///|
fn TestCheckOptions::with_extended_analysis(
  self : TestCheckOptions,
  extended_analysis : Bool,
) -> TestCheckOptions {
  { ..self, extended_analysis, }
}

///|
fn TestCheckOptions::with_optional_checks(
  self : TestCheckOptions,
  optional_checks : Array[String],
) -> TestCheckOptions {
  { ..self, optional_checks, }
}

///|
fn test_check_parsed_script(
  script : @parser.Script,
  options~ : TestCheckOptions = TestCheckOptions::default(),
) -> Array[@checks.CheckDiagnostic] {
  let shell = @semantics.determine_shell(
    script,
    options.shell_override,
    options.filename,
  )
  @checks.run_checks_with_shell(
    script,
    shell,
    options.extended_analysis,
    options.optional_checks,
  )
}

///|
fn test_parse_script(source : String) -> Result[@parser.Script, String] {
  let report = @parser.parse_script_report(source)
  for diagnostic in report.diagnostics {
    if diagnostic.severity is Error {
      return Err(
        "\{diagnostic.span.start.line}:\{diagnostic.span.start.column}: \{diagnostic.message}",
      )
    }
  }
  match report.script {
    Some(script) => Ok(script)
    None => Err("parse failed")
  }
}
