///|
fn assert_checker_diagnostics(
  diagnostics : Array[@checker.PositionedDiagnostic],
  expected : Array[(String, Int32?, Int32, Int32, String)],
) -> Unit raise {
  let actual = diagnostics.map(fn(diagnostic) {
    (
      compat_severity_name(diagnostic.severity),
      diagnostic.code,
      diagnostic.span.start.line,
      diagnostic.span.start.column,
      diagnostic.message,
    )
  })
  @test.assert_eq(actual, expected)
}
