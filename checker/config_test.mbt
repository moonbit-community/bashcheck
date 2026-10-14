///|
test "invalid rc config reports the complete SC1134 diagnostic" {
  let result = @checker.check_script(
    "echo hi\n",
    spec=@checker.CheckSpec::default()
      .with_shell_override(Some(Bash))
      .with_config_path_override(Some("checker/testdata/bad.rc"))
      .with_config_files([("checker/testdata/bad.rc", "bogus line\n")]),
  )
  assert_checker_diagnostics(result.diagnostics, [
    (
      "error",
      Some(1134),
      1,
      1,
      "Failed to process checker/testdata/bad.rc, line 1: Expected '=' after directive key. Fix any mentioned problems and try again.",
    ),
  ])
}
