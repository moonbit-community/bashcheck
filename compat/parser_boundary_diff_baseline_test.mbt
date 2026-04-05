///|
test "phase 1 parser boundary diagnostics align with shellcheck" {
  assert_parser_diagnostics_match("SC1038", "cat << (foo)\n", [
    shellcheck_info(
      1009, 1, 1, "The mentioned syntax error was in this simple command.",
    ),
    shellcheck_error(
      1038, 1, 5, "Shells are space sensitive. Use '< <(cmd)', not '<< (cmd)'.",
    ),
    shellcheck_error(
      1073, 1, 5, "Couldn't parse this here document. Fix to allow more checks.",
    ),
    shellcheck_error(1072, 1, 8, " Fix any mentioned problems and try again."),
  ])

  assert_parser_diagnostics_match("SC1064", "foo() echo hi\n", [
    shellcheck_error(
      1073, 1, 1, "Couldn't parse this function. Fix to allow more checks.",
    ),
    shellcheck_error(
      1064, 1, 7, "Expected a { to open the function definition.",
    ),
    shellcheck_error(1072, 1, 7, " Fix any mentioned problems and try again."),
  ])

  assert_parser_diagnostics_match("SC1084", "!#/bin/bash\necho hi\n", [
    shellcheck_error(1084, 1, 1, "Use #!, not !#, for the shebang."),
  ])

  let source_depth_files : Array[(String, String)] = []
  for i in 0..<101 {
    source_depth_files.push(("f\{i}.sh", "source f\{i + 1}.sh\n"))
  }
  source_depth_files.push(("f101.sh", "echo ok\n"))
  assert_parser_diagnostics_match_with_options(
    "SC1092",
    "source f1.sh\n",
    [shellcheck_error(1092, 1, 8, "Stopping at 100 'source' frames :O")],
    sourced_bash_parser_options("f0.sh", source_depth_files),
  )

  assert_parser_diagnostics_match("SC1104", "!/bin/bash\necho hi\n", [
    shellcheck_error(1104, 1, 1, "Use #!, not just !, for the shebang."),
  ])

  assert_parser_diagnostics_match("SC1113", "#/bin/bash\necho hi\n", [
    shellcheck_error(1113, 1, 2, "Use #!, not just #, for the shebang."),
  ])

  assert_parser_diagnostics_match("SC1114", " #!/bin/bash\necho hi\n", [
    shellcheck_error(1114, 1, 1, "Remove leading spaces before the shebang."),
  ])

  assert_parser_diagnostics_match("SC1115", "# !/bin/bash\necho hi\n", [
    shellcheck_error(
      1115, 1, 2, "Remove spaces between # and ! in the shebang.",
    ),
  ])

  assert_parser_diagnostics_match(
    "SC1128",
    "# comment\n#!/bin/bash\necho hi\n",
    [
      shellcheck_error(
        1128, 2, 1, "The shebang must be on the first line. Delete blanks and move comments.",
      ),
    ],
  )

  assert_diagnostics_match(
    "SC1134",
    "echo hi\n",
    [
      shellcheck_error(
        1134, 1, 1, "Failed to process compat/testdata/bad.rc, line 1: Expected '=' after directive key. Fix any mentioned problems and try again.",
      ),
    ],
    spec=bash_shell_spec_with_config("compat/testdata/bad.rc", "bogus line\n"),
  )
}
