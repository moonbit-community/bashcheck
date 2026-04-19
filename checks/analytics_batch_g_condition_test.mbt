///|
test "analytics batch g flags condition operand expansion diagnostics" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2068,SC2154,SC2157
      #|[ -f *.mp3 ]
      #|[[ -n ${arr[@]} ]]
      #|[ -n ${arr[@]} ]
      #|[ -n {a,b} ]
      #|[[ -n {a,b} ]]
      #|[ *.mp3 ]
      #|[[ *.mp3 ]]
      #|[ 6 -eq 2*3 ]
      #|[ -v *.mp3 ]
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2144), 1)
  assert_eq(count_code(diagnostics, 2198), 1)
  assert_eq(count_code(diagnostics, 2199), 1)
  assert_eq(count_code(diagnostics, 2200), 1)
  assert_eq(count_code(diagnostics, 2201), 1)
  assert_eq(count_code(diagnostics, 2202), 1)
  assert_eq(count_code(diagnostics, 2203), 1)
  assert_eq(count_code(diagnostics, 2208), 1)
  assert_eq(count_code(diagnostics, 2255), 1)
  assert_eq(count_code(diagnostics, 2070), 1)
}

///|
test "analytics batch g uses ksh-specific unary glob warning" {
  let diagnostics = check_source(
    (
      #|#!/bin/ksh
      #|[ -f *.mp3 ]
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2245), 1)
  assert_true(!has_code(diagnostics, 2144))
}

///|
test "analytics batch g avoids false positives on safe condition operands" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|[[ foo = *.mp3 ]]
      #|[[ -v foo ]]
      #|[ -n "$foo" ]
      #|[[ $((6)) -eq 6 ]]
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2144))
  assert_true(!has_code(diagnostics, 2198))
  assert_true(!has_code(diagnostics, 2199))
  assert_true(!has_code(diagnostics, 2200))
  assert_true(!has_code(diagnostics, 2201))
  assert_true(!has_code(diagnostics, 2202))
  assert_true(!has_code(diagnostics, 2203))
  assert_true(!has_code(diagnostics, 2208))
  assert_true(!has_code(diagnostics, 2245))
  assert_true(!has_code(diagnostics, 2255))
}
