///|
async test "phase e dynamic json diff aligns arithmetic analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2004-SC2017",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|foo=3
      #|echo $(( $foo + 1 ))
      #|echo $(( 3 / 2 * 100 ))
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns condition analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2070-SC2074-SC2075-SC2077",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2086,SC2154
      #|[ -n $foo ]
      #|[ $foo=3 ]
      #|# shellcheck disable=SC1014,SC2050,SC2154
      #|[ "$a" =~ foo ]
      #|# shellcheck disable=SC2050,SC2071,SC2154
      #|[[ $a \< $b ]]
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns constant nullary analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2158-SC2159-SC2160-SC2161",
    (
      #|#!/bin/bash
      #|[ false ]
      #|[ 0 ]
      #|[ true ]
      #|[ 1 ]
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns loop variable override analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2165-SC2167",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2043
      #|for i in a; do
      #|  for ((i = 0; i < 3; i++)); do
      #|    :
      #|  done
      #|done
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns command assignment shape analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2272-SC2276",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2086
      #|$var==42
      #|var${x}/=value
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns optional condition analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2237-SC2243-SC2335",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|# shellcheck enable=avoid-nullary-conditions,avoid-negated-conditions
      #|! [ -n "$var" ]
      #|[[ $(cmd) ]]
      #|! [[ $var -gt 3 ]]
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns set-e suppressed analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2310",
    (
      #|#!/bin/bash
      #|# shellcheck enable=check-set-e-suppressed
      #|set -e
      #|f(){ false; }
      #|f && echo ok
      #|if f; then :; fi
      #|while f; do :; done
      #|! f
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns malformed command name diagnostics" {
  assert_shellcheck_json_matches(
    "SC2289",
    (
      #|#!/bin/bash
      #|$'foo\tbar'
      #|
    ),
  )
}
