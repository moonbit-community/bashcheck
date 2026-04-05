///|
/// Wraps the flat JSON comment array in the legacy `{"comments": ...}` shape.
fn render_json1(results : Array[@checker.CheckResult]) -> String {
  "{\"comments\":" + render_json(results) + "}"
}
