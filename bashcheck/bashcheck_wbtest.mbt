///|
fn cli_parse_ok(args : Array[String]) -> CliConfig {
  match parse_cli_args(args) {
    Ok(config) => config
    Err(error) => abort(error.message)
  }
}

///|
fn cli_parse_err(args : Array[String]) -> CliError {
  match parse_cli_args(args) {
    Ok(_) => abort("expected cli parse error")
    Err(error) => error
  }
}

///|
test "cli parses help list-optional and version actions" {
  let help = cli_parse_ok(["--help"])
  let optional = cli_parse_ok(["--list-optional"])
  let version = cli_parse_ok(["--version"])

  assert_true(help.action is @driver.CliAction::ShowHelp)
  assert_true(optional.action is @driver.CliAction::ListOptional)
  assert_true(version.action is @driver.CliAction::ShowVersion)
}

///|
test "cli keeps the first meta action when multiple are present" {
  let help_first = cli_parse_ok(["--help", "--version"])
  let version_first = cli_parse_ok(["--version", "--help"])
  let list_first = cli_parse_ok(["--list-optional", "--help"])

  assert_true(help_first.action is @driver.CliAction::ShowHelp)
  assert_true(version_first.action is @driver.CliAction::ShowVersion)
  assert_true(list_first.action is @driver.CliAction::ListOptional)
}

///|
test "cli uses shellcheck-style error classes" {
  let severity = cli_parse_err(["--severity", "bogus"])
  let include_outcome = cli_parse_err(["--include", "wat"])
  let format = cli_parse_err(["--format", "bogus"])

  assert_eq(cli_exit_code(severity.kind), 4)
  assert_true(severity.message.contains("Unknown value for --severity"))
  assert_eq(cli_exit_code(include_outcome.kind), 3)
  assert_true(include_outcome.message.contains("Invalid number"))
  assert_eq(cli_exit_code(format.kind), 4)
  assert_true(format.message.contains("Unknown format bogus"))
}

///|
test "cli accumulates flags and parses short options" {
  let config = cli_parse_ok([
    "-a", "-sbash", "-Swarning", "-i", "SC2006", "-iSC2046", "-eSC2005", "-oall",
    "-P", "foo:bar", "-Calways", "-W0", "-fdiff", "--norc", "--rcfile", "config.rc",
    "--extended-analysis", "false", "script.sh",
  ])

  assert_true(config.spec.check_sourced)
  assert_true(config.spec.ignore_rc)
  assert_eq(config.spec.shell_override, Some(@semantics.ShellDialect::Bash))
  assert_true(config.spec.min_severity is @checker.DiagnosticSeverity::Warning)
  assert_eq(config.spec.include_codes, [2006, 2046])
  assert_eq(config.spec.exclude_codes, [2005])
  assert_true(!config.spec.optional_checks.contains("control-flow"))
  assert_true(
    config.spec.optional_checks.contains("check-extra-masked-returns"),
  )
  assert_eq(config.spec.source_paths, ["foo", "bar"])
  assert_eq(config.spec.config_path_override, Some("config.rc"))
  assert_true(!config.spec.extended_analysis)
  assert_true(config.spec.extended_analysis_forced)
  assert_true(config.format is @formatter.OutputFormat::Diff)
  assert_eq(config.format_options.wiki_link_count, 0)
  assert_true(config.format_options.enable_color)
  assert_eq(config.files, ["script.sh"])
}

///|
test "cli keeps the first format and accepts unknown optional checks" {
  let config = cli_parse_ok([
    "--format", "json", "--format", "tty", "--enable", "bogus,all", "script.sh",
  ])

  assert_true(config.format is @formatter.OutputFormat::Json)
  assert_true(config.spec.optional_checks.contains("bogus"))
  assert_true(!config.spec.optional_checks.contains("control-flow"))
  assert_true(config.spec.optional_checks.contains("quote-safe-variables"))
}

///|
test "cli still accepts explicit control-flow as a bashcheck extension" {
  let config = cli_parse_ok(["--enable", "control-flow", "script.sh"])

  assert_true(config.spec.optional_checks.contains("control-flow"))
}
