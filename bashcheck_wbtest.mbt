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

  assert_true(help.action is ShowHelp)
  assert_true(optional.action is ListOptional)
  assert_true(version.action is ShowVersion)
}

///|
test "cli keeps the first meta action when multiple are present" {
  let help_first = cli_parse_ok(["--help", "--version"])
  let version_first = cli_parse_ok(["--version", "--help"])
  let list_first = cli_parse_ok(["--list-optional", "--help"])

  assert_true(help_first.action is ShowHelp)
  assert_true(version_first.action is ShowVersion)
  assert_true(list_first.action is ListOptional)
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
  @test.assert_eq(config.spec.shell_override, Some(Bash))
  assert_true(config.spec.min_severity is Warning)
  assert_eq(config.spec.include_codes, [2006, 2046])
  assert_eq(config.spec.exclude_codes, [2005])
  assert_true(!config.spec.optional_checks.contains("control-flow"))
  assert_true(
    config.spec.optional_checks.contains("check-extra-masked-returns"),
  )
  assert_eq(config.spec.source_paths, ["foo", "bar"])
  @test.assert_eq(config.spec.config_path_override, Some("config.rc"))
  assert_true(!config.spec.extended_analysis)
  assert_true(config.spec.extended_analysis_forced)
  assert_true(config.format is Diff)
  assert_eq(config.format_options.wiki_link_count, 0)
  assert_true(config.format_options.enable_color)
  assert_eq(config.files, ["script.sh"])
}

///|
test "cli keeps the first format and accepts unknown optional checks" {
  let config = cli_parse_ok([
    "--format", "json", "--format", "tty", "--enable", "bogus,all", "script.sh",
  ])

  assert_true(config.format is Json)
  assert_true(config.spec.optional_checks.contains("bogus"))
  assert_true(!config.spec.optional_checks.contains("control-flow"))
  assert_true(config.spec.optional_checks.contains("quote-safe-variables"))
}

///|
test "cli still accepts explicit control-flow as a bashcheck extension" {
  let config = cli_parse_ok(["--enable", "control-flow", "script.sh"])

  assert_true(config.spec.optional_checks.contains("control-flow"))
}

///|
test "cli accepts long inline values and short option bundles" {
  let config = cli_parse_ok([
    "--shell=bash", "--severity=info", "--include=SC2006,2046", "--exclude=SC2005",
    "--enable=control-flow", "--source-path=foo;bar", "--rcfile=config.rc", "--extended-analysis=false",
    "-axCnever", "-W0", "--format=json1", "script.sh",
  ])

  @test.assert_eq(config.spec.shell_override, Some(Bash))
  assert_true(config.spec.min_severity is Info)
  assert_eq(config.spec.include_codes, [2006, 2046])
  assert_eq(config.spec.exclude_codes, [2005])
  assert_eq(config.spec.optional_checks, ["control-flow"])
  assert_eq(config.spec.source_paths, ["foo", "bar"])
  @test.assert_eq(config.spec.config_path_override, Some("config.rc"))
  assert_true(!config.spec.extended_analysis)
  assert_true(config.spec.check_sourced)
  assert_true(config.spec.external_sources)
  assert_true(!config.format_options.enable_color)
  assert_eq(config.format_options.wiki_link_count, 0)
  assert_true(config.format is Json1)
}

///|
test "cli preserves positionals and uses stdin by default" {
  assert_eq(cli_parse_ok([]).files, ["-"])
  assert_eq(cli_parse_ok(["--help"]).files, [])
  let config = cli_parse_ok([
    "first.sh", "-ax", "-", "--format=quiet", "second.sh", "--", "--color", "-C",
    "--help", "--", "last.sh",
  ])

  assert_true(config.action is Run)
  assert_true(config.format is Quiet)
  assert_true(config.spec.check_sourced)
  assert_true(config.spec.external_sources)
  assert_eq(config.files, [
    "first.sh", "-", "second.sh", "--color", "-C", "--help", "--", "last.sh",
  ])
}

///|
test "cli bare color flags do not consume filenames or other options" {
  for flag in ["--color", "-C", "-axC"] {
    let config = cli_parse_ok([flag, "never", "--format=quiet"])
    assert_true(config.format_options.enable_color)
    assert_eq(config.files, ["never"])
    assert_true(config.format is Quiet)
  }
  let config = cli_parse_ok(["--color", "--color=never", "script.sh"])
  assert_true(!config.format_options.enable_color)
  assert_eq(config.files, ["script.sh"])
}

///|
test "cli leaves hyphenated option values untouched during normalization" {
  for
    args in [
      ["--rcfile", "--color"],
      ["-P", "-C"],
      ["--rcfile", "--", "-P", "--help"],
    ] {
    let config = cli_parse_ok(args)
    assert_true(config.action is Run)
    assert_eq(config.files, ["-"])
  }
  let config = cli_parse_ok(["--rcfile", "--color", "-P", "-C"])
  @test.assert_eq(config.spec.config_path_override, Some("--color"))
  assert_eq(config.spec.source_paths, ["-C"])
}

///|
test "cli repeats value options across aliases" {
  let config = cli_parse_ok([
    "-fgcc", "--format=unsupported", "--include=2006", "-i2046", "-e2005", "--exclude=2086",
    "-Pfoo:bar", "--source-path=baz", "-ssh", "--shell=bash", "--rcfile=first.rc",
    "--rcfile=last.rc", "-W1", "--wiki-link-count=2", "--extended-analysis=false",
    "--extended-analysis=true", "-oquote-safe-variables", "--enable=control-flow,quote-safe-variables",
    "script.sh",
  ])

  assert_true(config.format is Gcc)
  assert_eq(config.spec.include_codes, [2006, 2046])
  assert_eq(config.spec.exclude_codes, [2005, 2086])
  assert_eq(config.spec.source_paths, ["foo", "bar", "baz"])
  @test.assert_eq(config.spec.shell_override, Some(Bash))
  @test.assert_eq(config.spec.config_path_override, Some("last.rc"))
  assert_eq(config.format_options.wiki_link_count, 2)
  assert_true(config.spec.extended_analysis)
  assert_eq(config.spec.optional_checks, [
    "quote-safe-variables", "control-flow",
  ])
}

///|
test "cli adapts argparse syntax errors to usage errors" {
  for
    (args, message) in [
      (["--unknown=value"], "Unknown option: --unknown"),
      (["-axz"], "Unknown option: -z"),
      (["--format"], "Missing value for --format"),
      (["-axs"], "Missing value for -s"),
      (["--include"], "Missing value for --include"),
      (
        ["--extended-analysis", "maybe"],
        "Invalid boolean, expected true/false: maybe",
      ),
    ] {
    let error = cli_parse_err(args)
    assert_eq(cli_exit_code(error.kind), 3)
    assert_eq(error.message, message)
  }
}

///|
test "cli validates all repeated values and retains first meta action" {
  let color = cli_parse_err(["--color=bogus", "--color=never"])
  let shell = cli_parse_err(["-sbogus", "--shell=bash"])
  assert_eq(cli_exit_code(color.kind), 4)
  assert_eq(shell.message, "Unknown shell: bogus")
  assert_true(cli_parse_ok(["-axV", "--help", "-V"]).action is ShowVersion)
  assert_true(cli_parse_ok(["--list-optional", "-V"]).action is ListOptional)
  assert_true(cli_parse_ok(["--help", "-axV"]).action is ShowHelp)
}
