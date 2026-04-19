///|
async test "phase e dynamic json diff aligns shell-support RANDOM and pipe portability diagnostics" {
  assert_shellcheck_json_matches(
    "SC3028-SC3029",
    (
      #|#!/bin/sh
      #|RANDOM=9
      #|echo $RANDOM
      #|echo foo|&cat
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns shell-support echo and let portability diagnostics" {
  assert_shellcheck_json_matches(
    "SC3036-SC3039",
    (
      #|#!/bin/dash
      #|# shellcheck disable=SC2034
      #|echo -ne foo
      #|let x=1
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns shell-support sh builtin portability diagnostics" {
  assert_shellcheck_json_matches(
    "SC3041-SC3043-SC3044-SC3061",
    (
      #|#!/bin/sh
      #|set -B
      #|local
      #|declare
      #|read -r
      #|
    ),
  )
}
