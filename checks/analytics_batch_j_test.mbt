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
    Some(fix) =>
      assert_eq(
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
    Some(fix) =>
      assert_eq(
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
