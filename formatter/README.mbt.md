# bashcheck/formatter

`render_results` provides tty, JSON, JSON1, GCC, Checkstyle, quiet and unified diff output. Diagnostics are grouped by their actual source filename, and source excerpts and fixes use that file’s cached text. This includes files reached through source directives when `-a` is enabled.

```mbt check
///|
test "doc formatter production entry point" {
  let spec = @checker.CheckSpec::default().with_ignore_rc(true)
  let source = "#!/bin/bash\necho $1\n"
  let report = @checker.prepare_script(source, spec~)
  let result = @checker.check_prepared_script(source, report, spec~)
  let rendered = @formatter.render_results(
    [result],
    @formatter.parse_output_format("gcc").unwrap(),
  )
  assert_true(rendered.contains("SC2086"))
}
```
