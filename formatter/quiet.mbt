///|
/// Quiet output intentionally renders nothing.
///
/// The driver still uses diagnostics to determine the exit code, but the
/// formatter itself discards all payload.
fn render_quiet(results : Array[@checker.CheckResult]) -> String {
  ignore(results)
  ""
}
