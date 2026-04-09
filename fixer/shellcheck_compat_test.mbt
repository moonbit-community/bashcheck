///|
fn compat_replacement(
  start_offset : Int,
  end_offset : Int,
  text : String,
  precedence : Int,
  insertion_point : InsertionPoint,
) -> Replacement {
  Replacement::new(
    "test.sh",
    @parser.Position::new(start_offset, 1, start_offset + 1),
    @parser.Position::new(end_offset, 1, end_offset + 1),
    text,
    precedence,
    insertion_point,
  )
}

///|
fn t_from_start(
  start_column : Int,
  end_column : Int,
  text : String,
  precedence : Int,
) -> Replacement {
  compat_replacement(
    start_column - 1,
    end_column - 1,
    text,
    precedence,
    InsertionPoint::after(),
  )
}

///|
fn t_from_end(
  start_column : Int,
  end_column : Int,
  text : String,
  precedence : Int,
) -> Replacement {
  compat_replacement(
    start_column - 1,
    end_column - 1,
    text,
    precedence,
    InsertionPoint::before(),
  )
}

///|
fn test_fix(replacements : Array[Replacement]) -> Fix {
  Fix::from_replacements(replacements)
}

///|
fn apply_fixes(fixes : Array[Fix], source : String) -> String? {
  match merge_fixes(fixes) {
    Some(merged) => apply_fix(merged, source)
    None => None
  }
}

///|
fn test_fixes(expected : String, original : String, fixes : Array[Fix]) -> Bool {
  apply_fixes(fixes, original) == Some(expected)
}

///|
fn assert_fixer_prop(label : String, value : Bool) -> Unit {
  if !value {
    abort("\{label}: expected true")
  }
}

///|
fn assert_fixer_eq(label : String, actual : String, expected : String) -> Unit {
  if actual != expected {
    abort("\{label}: expected \{expected}, got \{actual}")
  }
}

///|
fn do_replace(
  start_column : Int,
  end_column : Int,
  original : String,
  replacement : String,
) -> String {
  let start_offset = if start_column <= 0 { 0 } else { start_column - 1 }
  let end_offset = if end_column <= 0 { 0 } else { end_column - 1 }
  original.view(end_offset=start_offset).to_string() +
  replacement +
  original.view(start_offset=end_offset).to_string()
}

///|
fn compat_overlap(lhs : Replacement, rhs : Replacement) -> Bool {
  detect_overlap(lhs, rhs) && detect_overlap(rhs, lhs)
}

///|
fn compat_no_overlap(lhs : Replacement, rhs : Replacement) -> Bool {
  !detect_overlap(lhs, rhs) && !detect_overlap(rhs, lhs)
}

///|
fn ordered_pair(lhs : Int, rhs : Int) -> (Int, Int) {
  if lhs <= rhs {
    (lhs, rhs)
  } else {
    (rhs, lhs)
  }
}

///|
test "shellcheck fixer overlap props" {
  assert_fixer_prop(
    "prop_overlap_contiguous",
    compat_no_overlap(
      t_from_start(10, 12, "foo", 1),
      t_from_start(12, 14, "bar", 2),
    ),
  )
  assert_fixer_prop(
    "prop_overlap_adjacent_zerowidth",
    compat_no_overlap(
      t_from_start(3, 3, "foo", 1),
      t_from_start(3, 3, "bar", 2),
    ),
  )
  assert_fixer_prop(
    "prop_overlap_enclosed",
    compat_overlap(t_from_start(3, 5, "foo", 1), t_from_start(1, 10, "bar", 2)),
  )
  assert_fixer_prop(
    "prop_overlap_partial",
    compat_overlap(t_from_start(1, 5, "foo", 1), t_from_start(3, 7, "bar", 2)),
  )
}

///|
test "shellcheck fixer doReplace props" {
  assert_fixer_eq("prop_doReplace1", do_replace(0, 0, "1234", "A"), "A1234")
  assert_fixer_eq("prop_doReplace2", do_replace(1, 1, "1234", "A"), "A1234")
  assert_fixer_eq("prop_doReplace3", do_replace(1, 2, "1234", "A"), "A234")
  assert_fixer_eq("prop_doReplace4", do_replace(3, 3, "1234", "A"), "12A34")
  assert_fixer_eq("prop_doReplace5", do_replace(4, 4, "1234", "A"), "123A4")
  assert_fixer_eq("prop_doReplace6", do_replace(5, 5, "1234", "A"), "1234A")
}

///|
test "shellcheck fixer fixed replacement props" {
  assert_fixer_prop(
    "prop_simpleFix1",
    test_fixes("hello world", "hell world", [
      test_fix([t_from_end(5, 5, "o", 1)]),
    ]),
  )
  assert_fixer_prop(
    "prop_anchorsLeft",
    test_fixes("-->foobar<--", "--><--", [
      test_fix([t_from_start(4, 4, "foo", 1), t_from_start(4, 4, "bar", 2)]),
    ]),
  )
  assert_fixer_prop(
    "prop_anchorsRight",
    test_fixes("-->foobar<--", "--><--", [
      test_fix([t_from_end(4, 4, "bar", 1), t_from_end(4, 4, "foo", 2)]),
    ]),
  )
  assert_fixer_prop(
    "prop_anchorsBoth1",
    test_fixes("-->foobar<--", "--><--", [
      test_fix([t_from_start(4, 4, "bar", 2), t_from_end(4, 4, "foo", 1)]),
    ]),
  )
  assert_fixer_prop(
    "prop_anchorsBoth2",
    test_fixes("-->foobar<--", "--><--", [
      test_fix([t_from_end(4, 4, "foo", 2), t_from_start(4, 4, "bar", 1)]),
    ]),
  )
  assert_fixer_prop(
    "prop_composeFixes1",
    test_fixes("cd \"$1\" || exit", "cd $1", [
      test_fix([t_from_start(4, 4, "\"", 10), t_from_end(6, 6, "\"", 10)]),
      test_fix([t_from_end(6, 6, " || exit", 5)]),
    ]),
  )
  assert_fixer_prop(
    "prop_composeFixes2",
    test_fixes("$(\"$1\")", "`$1`", [
      test_fix([t_from_start(1, 2, "$(", 5), t_from_end(4, 5, ")", 5)]),
      test_fix([t_from_start(2, 2, "\"", 10), t_from_end(4, 4, "\"", 10)]),
    ]),
  )
  assert_fixer_prop(
    "prop_composeFixes3",
    test_fixes("(x)[x]", "xx", [
      test_fix([
        t_from_start(1, 1, "(", 4),
        t_from_end(2, 2, ")", 3),
        t_from_start(2, 2, "[", 2),
        t_from_end(3, 3, "]", 1),
      ]),
    ]),
  )
  assert_fixer_prop(
    "prop_composeFixes4",
    test_fixes("(x)[x]", "xx", [
      test_fix([
        t_from_start(1, 1, "(", 4),
        t_from_start(2, 2, "[", 3),
        t_from_end(2, 2, ")", 2),
        t_from_end(3, 3, "]", 1),
      ]),
    ]),
  )
  assert_fixer_prop(
    "prop_composeFixes5",
    test_fixes("\"$(x)\"", "`x`", [
      test_fix([
        t_from_start(1, 2, "$(", 2),
        t_from_end(3, 4, ")", 2),
        t_from_start(1, 1, "\"", 1),
        t_from_end(4, 4, "\"", 1),
      ]),
    ]),
  )
}

///|
test "shellcheck fixer quickcheck overlap commutes" {
  let offset = @qc.int_range(0, 12)
  @qc.quick_check(
    @qc.forall(@qc.quad(offset, offset, offset, offset), fn(
      sample : (Int, Int, Int, Int),
    ) {
      let (a, b, c, d) = sample
      let lhs = ordered_pair(a, b)
      let rhs = ordered_pair(c, d)
      let left = compat_replacement(
        lhs.0,
        lhs.1,
        "x",
        1,
        InsertionPoint::after(),
      )
      let right = compat_replacement(
        rhs.0,
        rhs.1,
        "y",
        2,
        InsertionPoint::after(),
      )
      detect_overlap(left, right) == detect_overlap(right, left)
    }),
    max_success=200,
  )
}
