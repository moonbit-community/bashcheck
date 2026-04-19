///|
async test "phase c dynamic json diff aligns cd-back analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2103",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2164
      #|for f in *; do cd "$f"; git pull; cd ..; done
      #|
    ),
  )
}

///|
async test "phase c dynamic json diff aligns stderr redirect order analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2069",
    (
      #|#!/bin/bash
      #|printf x 2>&1 > cow
      #|printf x | cat 2>&1 > /dev/null
      #|
    ),
  )
}

///|
async test "phase c dynamic json diff aligns ksh stderr pipe analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2118",
    (
      #|#!/bin/ksh
      #|foo|&bar
      #|
    ),
  )
}

///|
async test "phase c dynamic json diff aligns case fallthrough shell feature analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2127-case-fallthrough",
    (
      #|#!/bin/sh
      #|x=foo
      #|case "$x" in bar) baz ;& esac
      #|
    ),
  )
}

///|
async test "phase c dynamic json diff aligns bash-only case continue analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2127-case-continue",
    (
      #|#!/bin/ksh
      #|x=foo
      #|case "$x" in bar) baz ;;& esac
      #|
    ),
  )
}

///|
async test "phase c dynamic json diff aligns brace command expansion shell feature analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2127-brace-command-expansion",
    (
      #|#!/bin/dash
      #|: "${ ls; }"
      #|
    ),
  )
}

///|
async test "phase c dynamic json diff aligns append and grep-q analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2129-SC2143",
    (
      #|#!/bin/bash
      #|foo >> file; bar >> file; baz >> file;
      #|[[ $(foo | grep bar) ]]
      #|[ -z "$(foo | grep bar)" ]
      #|
    ),
  )
}

///|
async test "phase c dynamic json diff aligns set-e bang analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2251",
    (
      #|#!/bin/bash
      #|set -e
      #|while true; do ! true; done
      #|{ ! true; }
      #|! foo | bar
      #|! true
      #|rest
      #|
    ),
  )
}

///|
async test "phase c dynamic json diff aligns modified arithmetic redirection analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2257",
    (
      #|#!/bin/bash
      #|printf %s x > $((i++))
      #|printf %s x 2> $((i+=1))
      #|
    ),
  )
}

///|
async test "phase c dynamic json diff aligns bad test and-or analytics diagnostics" {
  assert_shellcheck_json_matches(
    "SC2265-SC2266",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2078
      #|a=$1
      #|[ "$a" ] & [ "$a" ]
      #|test -e foo & [ "$a" ]
      #|[ "$a" ] | [ "$a" ]
      #|
    ),
  )
}
