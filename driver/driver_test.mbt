///|
async fn default_driver_outcome(action : CliAction) -> CliOutcome {
  run_cli(
    action,
    [],
    @checker.CheckSpec::default(),
    @formatter.OutputFormat::default(),
    @formatter.FormatOptions::default(),
  )
}

///|
async test "driver renders help list-optional and version actions" {
  let help = default_driver_outcome(CliAction::ShowHelp)
  let optional = default_driver_outcome(CliAction::ListOptional)
  let version = default_driver_outcome(CliAction::ShowVersion)

  assert_eq(help.exit_code, 0)
  assert_true(help.output.contains("Usage: bashcheck"))
  assert_true(
    help.output.contains(
      "Prefer the specified configuration file over searching for one",
    ),
  )
  assert_eq(optional.exit_code, 0)
  assert_true(optional.output.contains("name:    add-default-case"))
  assert_true(optional.output.contains("quote-safe-variables"))
  assert_true(!optional.output.contains("control-flow"))
  assert_eq(version.exit_code, 0)
  assert_true(version.output.contains("bashcheck"))
}
