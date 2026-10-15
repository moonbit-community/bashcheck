///|
fn parse_fixer_ok(source : String) -> @parser.Script {
  match test_parse_script(source) {
    Ok(script) => script
    Err(_) => panic()
  }
}

///|
fn command_span(source : String, index : Int32) -> @parser.Span {
  let script = parse_fixer_ok(source)
  script.items[index].and_or.head.segments[0].command.span
}

///|
test "fixer detects overlapping replacements" {
  let source =
    #|echo foo
    #|
  let span = command_span(source, 0)
  let lhs = @fixer.Replacement::new(
    "test.sh",
    span.start,
    span.end,
    "echo bar",
    0,
    @fixer.InsertionPoint::before(),
  )
  let rhs = lhs.with_text("echo baz")

  assert_true(@fixer.detect_overlap(lhs, rhs))
  assert_true(
    @fixer.merge_fixes([
      @fixer.Fix::from_replacements([lhs]),
      @fixer.Fix::from_replacements([rhs]),
    ])
    is None,
  )
}

///|
test "fixer applies sorted non-overlapping replacements" {
  let source =
    #|echo foo
    #|printf hi
    #|
  let first = command_span(source, 0)
  let second = command_span(source, 1)
  let first_replacement = @fixer.Replacement::new(
    "test.sh",
    first.start,
    first.end,
    "echo bar",
    1,
    @fixer.InsertionPoint::before(),
  )
  let second_replacement = @fixer.Replacement::new(
    "test.sh",
    second.start,
    second.end,
    "printf bye",
    1,
    @fixer.InsertionPoint::before(),
  )

  let fix = @fixer.Fix::from_replacements([
    second_replacement, first_replacement,
  ])
  @test.assert_eq(
    @fixer.apply_fix(fix, source),
    Some(
      (
        #|echo bar
        #|printf bye
        #|
      ),
    ),
  )
}

///|
test "fixer realigns tab-expanded columns" {
  let fix = @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "test.sh",
      @parser.Position::new(1, 1, 9),
      @parser.Position::new(4, 1, 12),
      "bar",
      0,
      @fixer.InsertionPoint::before(),
    ),
    @fixer.Replacement::new(
      "test.sh",
      @parser.Position::new(9, 2, 9),
      @parser.Position::new(12, 2, 12),
      "qux",
      0,
      @fixer.InsertionPoint::before(),
    ),
  ])

  let realigned = realign_columns_for_tabs(
    fix,
    (
      #|	foo
      #|bar	baz
      #|
    ),
  )
  assert_eq(realigned.replacements[0].start.column, 2)
  assert_eq(realigned.replacements[0].end.column, 5)
  assert_eq(realigned.replacements[1].start.column, 5)
  assert_eq(realigned.replacements[1].end.column, 8)
}

///|
test "fixer leaves out-of-range tab realignment untouched" {
  let fix = @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "test.sh",
      @parser.Position::new(0, 9, 4),
      @parser.Position::new(0, 9, 4),
      "x",
      0,
      @fixer.InsertionPoint::before(),
    ),
  ])

  let realigned = realign_columns_for_tabs(
    fix,
    (
      #|echo ok
      #|
    ),
  )
  assert_eq(realigned.replacements[0].start.column, 4)
  assert_eq(realigned.replacements[0].end.column, 4)
}
