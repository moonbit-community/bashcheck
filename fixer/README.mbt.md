# bashcheck/fixer

`Replacement` and `Fix` carry positions and filenames from lint diagnostics. `merge_fixes` rejects incompatible edits, and `apply_fix` applies a single file’s edits using source offsets. Formatters group edits by file before applying them. Position-mapping and tab-realignment convenience tools are local to tests.

```mbt check
///|
test "doc fixer production entry point" {
  let replacement = @fixer.Replacement::new(
    "example.sh",
    @parser.Position::new(5, 1, 6),
    @parser.Position::new(8, 1, 9),
    "bar",
    0,
    @fixer.InsertionPoint::before(),
  )
  let fix = @fixer.Fix::from_replacements([replacement])
  assert_eq(@fixer.apply_fix(fix, "echo foo\n"), Some("echo bar\n"))
}
```
