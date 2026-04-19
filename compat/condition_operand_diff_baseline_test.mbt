///|
async test "dynamic json diff aligns condition operand expansion diagnostics" {
  assert_shellcheck_json_matches(
    "SC2144-SC2198-SC2208-SC2255-bash",
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
}

///|
async test "dynamic json diff aligns ksh unary glob operand diagnostics" {
  assert_shellcheck_json_matches(
    "SC2245-ksh",
    (
      #|#!/bin/ksh
      #|[ -f *.mp3 ]
      #|
    ),
  )
}
