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
