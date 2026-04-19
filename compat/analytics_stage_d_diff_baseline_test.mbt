///|
async test "phase d dynamic json diff aligns assignment and indirection analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2082-SC2124-SC2125-SC2223",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2086,SC2154
      #|echo ${foo$n}
      #|a="$@"
      #|b=*.png
      #|: ${x=*}
      #|
    ),
  )
}

///|
async test "phase d dynamic json diff aligns subshell style analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2233-SC2234-SC2235",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2078
      #|( [ a ] )
      #|if ( [ a ] ); then :; fi
      #|( [ a ] && [ b ] )
      #|
    ),
  )
}

///|
async test "phase d dynamic json diff aligns shebang parameter analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2096",
    (
      #|#!/usr/bin/env bash -x
      #|echo ok
      #|
    ),
  )
}
