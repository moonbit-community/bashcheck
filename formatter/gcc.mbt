///|
/// Renders diagnostics in the classic `file:line:col:` GCC style.
fn render_gcc(results : Array[@checker.CheckResult]) -> String {
  let lines : Array[String] = []
  for result in results {
    for diagnostic in result.diagnostics {
      lines.push(
        "\{diagnostic.filename}:\{diagnostic.span.start.line}:\{diagnostic.span.start.column}: \{gcc_level(diagnostic)}: \{diagnostic.message} [\{code_text(diagnostic)}]",
      )
    }
  }
  lines.join("\n")
}

///|
/// Maps checker severities to GCC-style levels.
fn gcc_level(diagnostic : @checker.PositionedDiagnostic) -> String {
  match diagnostic.severity {
    @checker.DiagnosticSeverity::Error => "error"
    @checker.DiagnosticSeverity::Warning => "warning"
    _ => "note"
  }
}
