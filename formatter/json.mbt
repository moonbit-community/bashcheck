///|
/// Renders diagnostics as a flat JSON array of comment objects.
fn render_json(results : Array[@checker.CheckResult]) -> String {
  let diagnostics : Array[String] = []
  for result in results {
    for diagnostic in result.diagnostics {
      diagnostics.push(render_comment_json(diagnostic))
    }
  }
  "[" + diagnostics.join(",") + "]"
}
