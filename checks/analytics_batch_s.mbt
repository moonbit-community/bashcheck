///|
fn append_analytics_batch_s_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_s_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_s_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2336,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "cp -r behavior is implementation-defined.",
    },
  ]
}

///|
fn run_analytics_batch_s_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  visit_script_commands(script, fn(command) {
    check_cp_legacy_r(command, diagnostics)
  })
}

///|
fn check_cp_legacy_r(
  command : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard command_matches_exact_name(command, "cp") else { return }
  for argument in @semantics.command_arguments(command) {
    let text = match @semantics.literal_text(argument) {
      Some(text) => text
      None => continue
    }
    if text == "--" {
      break
    }
    guard short_option_cluster_contains(text, 'r') else { continue }
    push_diagnostic_with_fix(
      diagnostics,
      argument.span,
      CheckSeverity::Warning,
      2336,
      "cp -r behavior is implementation-defined",
      s_replace_span_fix(argument.span, "-R"),
    )
    return
  }
}

///|
fn s_replace_span_fix(span : @parser.Span, text : String) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      span.start,
      span.end,
      text,
      0,
      @fixer.InsertionPoint::after(),
    ),
  ])
}
