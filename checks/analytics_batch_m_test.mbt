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
test "analytics batch m flags comma-separated array literals" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|a=(1, 2)
      #|a+=(1,2,3)
      #|a=(1 "foo,bar" 3)
      #|a=('one,' 'two')
      #|a=([a]=b,[c]=d,[e]=f)
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2054), 3)
}

///|
test "analytics batch m flags array index assignment confusion" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2102,SC2154,SC2206
      #|declare -A foo; foo=(bar)
      #|arr=( [foo]= bar )
      #|declare -A map; map=( var=value )
      #|arr=( 1=value )
      #|arr=( $a=value )
      #|arr=( [foo] = bar )
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2190), 2)
  assert_eq(count_code(diagnostics, 2191), 3)
  assert_eq(count_code(diagnostics, 2192), 1)
}

///|
test "analytics batch m quotes literal equals fragments for SC2191" {
  let source =
    #|#!/bin/bash
    #|# shellcheck disable=SC2154,SC2206
    #|arr=( $a=value )
    #|
  let diagnostics = check_source(source)

  match first_code(diagnostics, 2191).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2154,SC2206
            #|arr=( $a"=value" )
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2191 fix")
  }
}

///|
test "analytics batch m does not double-report associative values after SC2192" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|declare -A assoc
      #|assoc=( [foo]= bar )
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2192), 1)
  assert_true(!has_code(diagnostics, 2190))
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
