///|
test "analytics batch j flags translated string variables and applies shellcheck-style quote swap fix" {
  let source =
    #|#!/bin/bash
    #|# shellcheck disable=SC2034,SC2209
    #|foo_bar2=val; $"foo_bar2"
    #|
  let diagnostics = check_source(source)

  assert_eq(count_code(diagnostics, 2256), 1)
  match first_code(diagnostics, 2256).fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 1)
      let replacement = fix.replacements[0]
      assert_eq(replacement.start.line, 3)
      assert_eq(replacement.start.column, 15)
      assert_eq(replacement.end.line, 3)
      assert_eq(replacement.end.column, 17)
      assert_eq(replacement.text, "\"$")
      assert_eq(replacement.precedence, 7)
      assert_true(replacement.insertion_point == @fixer.InsertionPoint::after())
      @test.assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2034,SC2209
            #|foo_bar2=val; "$foo_bar2"
            #|
          ),
        ),
      )
    }
    None => checks_fail("expected SC2256 fix")
  }
}

///|
test "analytics batch j flags leading x comparisons across test forms" {
  let source =
    #|#!/bin/bash
    #|# shellcheck disable=SC2154,SC2086
    #|[ x"$foo" = x'lol' ]
    #|test X$foo = Xbar
    #|
  let diagnostics = check_source(source)

  assert_eq(count_code(diagnostics, 2268), 2)
  match first_code(diagnostics, 2268).fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 2)
      let lhs = fix.replacements[0]
      assert_eq(lhs.start.line, 3)
      assert_eq(lhs.start.column, 3)
      assert_eq(lhs.end.line, 3)
      assert_eq(lhs.end.column, 4)
      assert_eq(lhs.text, "")
      assert_eq(lhs.precedence, 8)
      assert_true(lhs.insertion_point == @fixer.InsertionPoint::after())
      let rhs = fix.replacements[1]
      assert_eq(rhs.start.line, 3)
      assert_eq(rhs.start.column, 13)
      assert_eq(rhs.end.line, 3)
      assert_eq(rhs.end.column, 14)
      assert_eq(rhs.text, "")
      assert_eq(rhs.precedence, 8)
      assert_true(rhs.insertion_point == @fixer.InsertionPoint::after())
      @test.assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2154,SC2086
            #|[ "$foo" = 'lol' ]
            #|test X$foo = Xbar
            #|
          ),
        ),
      )
    }
    None => checks_fail("expected SC2268 fix")
  }
}

///|
test "analytics batch j flags second-arg comparison shapes" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2086,SC2046
      #|foo = $bar
      #|foo == $bar
      #|var += $(foo)
      #|var +=$(foo)
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2283), 1)
  assert_eq(count_code(diagnostics, 2284), 1)
  assert_eq(count_code(diagnostics, 2285), 2)
}
