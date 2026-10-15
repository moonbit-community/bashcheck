# bashcheck/parser

The CLI parser is pure. `parse_script_with_options` returns an AST, diagnostics, a directory of parse instances and filesystem requests. The driver supplies canonical aliases, permitted input files, cached text and read failures, then reparses until every request is satisfied. `Position.source_id` identifies a parse instance, including its parent include location. Source paths search the direct name, CLI paths and directives; use `SCRIPTDIR` to search beside the current script. AST dumps are test helpers.

```mbt check
///|
test "doc parser production entry point" {
  let report = @parser.parse_script_report("#!/bin/bash\necho hi\n")
  assert_true(report.script is Some(_))
  assert_eq(report.sources.length(), 1)
  assert_true(report.requests.is_empty())
}
```
