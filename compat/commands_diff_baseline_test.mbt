///|
async test "phase e dynamic json diff aligns command formatting diagnostics" {
  assert_shellcheck_json_matches(
    "SC2059-SC2060-SC2063",
    (
      #|#!/bin/bash
      #|fmt=%s
      #|printf "$fmt" foo
      #|tr [a-f] [A-F]
      #|grep '*foo*' file
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns command status diagnostics" {
  assert_shellcheck_json_matches(
    "SC2152-SC2241",
    (
      #|#!/bin/bash
      #|f(){ return -1; }
      #|f
      #|exit 1 2
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns command tr and find diagnostics" {
  assert_shellcheck_json_matches(
    "SC2020-SC2021-SC2227",
    (
      #|#!/bin/bash
      #|tr foo bar
      #|tr '[a-z]' '[A-Z]'
      #|find . -exec echo {} > file \;
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns expr compatibility diagnostics" {
  assert_shellcheck_json_matches(
    "SC2305-SC2307-SC2308",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2003
      #|expr match foo bar
      #|expr foo : fo*
      #|expr 5 -3
      #|
    ),
  )
}

///|
async test "phase e dynamic json diff aligns expr glob argument diagnostics" {
  assert_shellcheck_json_matches(
    "SC2306",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2003,SC2035
      #|expr 1 + 2 *
      #|expr 1 + 2 *.txt
      #|
    ),
  )
}
