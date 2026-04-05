///|
fn parse_fixer_ok(source : String) -> @parser.Script {
  match @parser.parse_script(source) {
    Ok(script) => script
    Err(_) => panic()
  }
}

///|
fn command_span(source : String, index : Int) -> @parser.Span {
  let script = parse_fixer_ok(source)
  script.items[index].and_or.head.segments[0].command.span
}

///|
test "fixer detects overlapping replacements" {
  let source = "echo foo\n"
  let span = command_span(source, 0)
  let lhs = Replacement::new(
    "test.sh",
    span.start,
    span.end,
    "echo bar",
    0,
    InsertionPoint::before(),
  )
  let rhs = lhs.with_text("echo baz")

  assert_true(detect_overlap(lhs, rhs))
  assert_true(
    merge_fixes([Fix::from_replacements([lhs]), Fix::from_replacements([rhs])])
    is None,
  )
}

///|
test "fixer applies sorted non-overlapping replacements" {
  let source = "echo foo\nprintf hi\n"
  let first = command_span(source, 0)
  let second = command_span(source, 1)
  let first_replacement = Replacement::new(
    "test.sh",
    first.start,
    first.end,
    "echo bar",
    1,
    InsertionPoint::before(),
  )
  let second_replacement = Replacement::new(
    "test.sh",
    second.start,
    second.end,
    "printf bye",
    1,
    InsertionPoint::before(),
  )

  let fix = Fix::from_replacements([second_replacement, first_replacement])
  assert_eq(apply_fix(fix, source), Some("echo bar\nprintf bye\n"))
}

///|
test "fixer realigns tab-expanded columns" {
  let fix = Fix::from_replacements([
    Replacement::new(
      "test.sh",
      @parser.Position::new(1, 1, 9),
      @parser.Position::new(4, 1, 12),
      "bar",
      0,
      InsertionPoint::before(),
    ),
    Replacement::new(
      "test.sh",
      @parser.Position::new(9, 2, 9),
      @parser.Position::new(12, 2, 12),
      "qux",
      0,
      InsertionPoint::before(),
    ),
  ])

  let realigned = realign_columns_for_tabs(fix, "\tfoo\nbar\tbaz\n")
  assert_eq(realigned.replacements[0].start.column, 2)
  assert_eq(realigned.replacements[0].end.column, 5)
  assert_eq(realigned.replacements[1].start.column, 5)
  assert_eq(realigned.replacements[1].end.column, 8)
}

///|
test "fixer leaves out-of-range tab realignment untouched" {
  let fix = Fix::from_replacements([
    Replacement::new(
      "test.sh",
      @parser.Position::new(0, 9, 4),
      @parser.Position::new(0, 9, 4),
      "x",
      0,
      InsertionPoint::before(),
    ),
  ])

  let realigned = realign_columns_for_tabs(fix, "echo ok\n")
  assert_eq(realigned.replacements[0].start.column, 4)
  assert_eq(realigned.replacements[0].end.column, 4)
}
