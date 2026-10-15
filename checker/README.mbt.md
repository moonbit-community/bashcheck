# bashcheck/checker

The CLI calls `prepare_script` to apply rc settings before resolving includes, and `check_prepared_script` once after all filesystem requests have been satisfied. Source files participate in analysis regardless of `check_sourced`; that flag only controls which diagnostics are reported. Results retain source text and include context for every parse instance. Only CLI configuration and the interfaces required by downstream packages are exported.

```mbt check
///|
test "doc checker production entry point" {
  let spec = @checker.CheckSpec::default().with_ignore_rc(true)
  let source = "#!/bin/bash\necho $1\n"
  let report = @checker.prepare_script(source, spec~)
  let result = @checker.check_prepared_script(source, report, spec~)
  assert_true(
    result.diagnostics.any(diagnostic => diagnostic.code == Some(2086)),
  )
}
```
