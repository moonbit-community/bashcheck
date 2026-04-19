///|
async test "phase b dynamic json diff aligns char class trailing bracket and impossible comparison diagnostics" {
  assert_shellcheck_json_matches(
    "SC2101-SC2102-SC2171-SC2193",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2035,SC2203,SC2215
      #|ls *[:digit:].jpg
      #|ls [10-15]
      #|if -z n ]]; then true; fi
      #|[[ *.png == [a-z] ]]
      #|
    ),
  )
}

///|
async test "phase b dynamic json diff aligns loop keyword scope analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2104-SC2105-SC2106",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2043
      #|continue 2
      #|foo() { break; }
      #|if true; then continue; fi
      #|for f in a; do ( break; ); done
      #|while true; do true | { break; }; done
      #|
    ),
  )
}
