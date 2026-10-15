# bashcheck/checks

`run_checks_with_shell` runs the registered rule suites over a parsed script and its includes. Optional-check metadata remains available for `--list-optional`; general rule-description tables and library convenience options have been removed. The checker owns final severity, include-scope and sourced-file filtering.

```mbt check
///|
test "doc checks production entry point" {
  let script = @parser.parse_script_report("echo $1\n").script.unwrap()
  let diagnostics = @checks.run_checks_with_shell(
    script,
    @semantics.ShellDialect::Bash,
    true,
    [],
  )
  assert_true(diagnostics.any(diagnostic => diagnostic.code == 2086))
  assert_true(@checks.supported_optional_check_infos().length() > 0)
}
```
