///|
test "analytics batch m flags unmatchable case diagnostics" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|case foo in bar) true; esac
      #|case foo-$bar in ??|*) true; esac
      #|case $f in cow) true;; bar|cow) false;; esac
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2194), 1)
  assert_eq(count_code(diagnostics, 2195), 1)
  assert_eq(count_code(diagnostics, 2221), 1)
  assert_eq(count_code(diagnostics, 2222), 1)
}

///|
test "analytics batch m ignores fallthrough separators in shadow checks" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|case $f in x) true;;& x) false;; esac
      #|case $f in y) true;& y) false;; esac
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2221))
  assert_true(!has_code(diagnostics, 2222))
}

///|
test "analytics batch m keeps shadow checks after constant case words" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|case foo in cow) true;; bar|cow) false;; esac
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2194), 1)
  assert_eq(count_code(diagnostics, 2221), 1)
  assert_eq(count_code(diagnostics, 2222), 1)
  assert_true(!has_code(diagnostics, 2195))
}
