# bashcheck/fixer

`fixer` provides the replacement primitives used by diagnostics that can offer
automated edits. It is intentionally small: one replacement model, one fix
model, and helpers for merging and applying them safely.

## Describe One Or More Edits Against Source Text

The basic model is: `Replacement` describes one edit, `InsertionPoint` controls
how zero-width edits attach to a range, and `Fix` is the container that groups
replacements intended to be applied together.

```mbt check
///|
test "doc fixer models one replacement as one fix" {
  let fix = @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "script.sh",
      @parser.Position::new(5, 1, 6),
      @parser.Position::new(8, 1, 9),
      "bar",
      0,
      @fixer.InsertionPoint::before(),
    ),
  ])

  assert_eq(@fixer.apply_fix(fix, "echo foo\n"), Some("echo bar\n"))
}
```

## Merge Compatible Fixes And Reject Conflicts

`detect_overlap` and `merge_fixes` are the safety rails around automated edits.
If two replacements touch the same source range, the merge fails and the caller
can decide how to recover.

```mbt check
///|
test "doc fixer merges non-overlapping replacements and rejects overlaps" {
  let overlap_lhs = @fixer.Replacement::new(
    "script.sh",
    @parser.Position::new(5, 1, 6),
    @parser.Position::new(8, 1, 9),
    "bar",
    0,
    @fixer.InsertionPoint::before(),
  )
  let overlap_rhs = overlap_lhs.with_text("baz")
  assert_true(@fixer.detect_overlap(overlap_lhs, overlap_rhs))
  assert_true(
    @fixer.merge_fixes([
      @fixer.Fix::from_replacements([overlap_lhs]),
      @fixer.Fix::from_replacements([overlap_rhs]),
    ])
    is None,
  )

  let merged = match
    @fixer.merge_fixes([
      @fixer.Fix::from_replacements([
        @fixer.Replacement::new(
          "script.sh",
          @parser.Position::new(5, 1, 6),
          @parser.Position::new(8, 1, 9),
          "bar",
          0,
          @fixer.InsertionPoint::before(),
        ),
      ]),
      @fixer.Fix::from_replacements([
        @fixer.Replacement::new(
          "script.sh",
          @parser.Position::new(16, 2, 8),
          @parser.Position::new(18, 2, 10),
          "bye",
          0,
          @fixer.InsertionPoint::before(),
        ),
      ]),
    ]) {
    Some(fix) => fix
    None => abort("expected merged fix")
  }

  assert_eq(
    @fixer.apply_fix(merged, "echo foo\nprintf hi\n"),
    Some("echo bar\nprintf bye\n"),
  )
}
```

## Remap Positions For Consumers That Use Different Coordinates

`map_positions` is useful when another layer wants to shift or normalize edit
coordinates, and `realign_columns_for_tabs` exists for consumers that report
visual columns instead of raw character columns.

```mbt check
///|
test "doc fixer can remap and realign replacement coordinates" {
  let fix = @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "script.sh",
      @parser.Position::new(1, 1, 9),
      @parser.Position::new(4, 1, 12),
      "bar",
      0,
      @fixer.InsertionPoint::before(),
    ),
  ])
  let shifted = @fixer.map_positions(fix, fn(position) {
    @parser.Position::new(
      position.offset + 1,
      position.line,
      position.column + 1,
    )
  })
  let realigned = @fixer.realign_columns_for_tabs(fix, "\tfoo\n")

  assert_eq(shifted.replacements[0].start.offset, 2)
  assert_eq(shifted.replacements[0].start.column, 10)
  assert_eq(realigned.replacements[0].start.column, 2)
}
```
