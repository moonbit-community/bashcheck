///|
test "compat regression covers shell support RANDOM and pipe portability diagnostics" {
  assert_compat_case(
    "shell-support-random-and-pipe-portability",
    (
      #|#!/bin/sh
      #|RANDOM=9
      #|echo $RANDOM
      #|echo foo|&cat
      #|
    ),
    [
      compat_warning(3028, 3, 6, 13, "In POSIX sh, RANDOM is undefined."),
      compat_warning(
        3029, 4, 9, 11, "In POSIX sh, |& in place of 2>&1 | is undefined.",
      ),
    ],
  )
}

///|
test "compat regression covers shell support echo and let portability diagnostics" {
  assert_compat_case(
    "shell-support-echo-and-let-portability",
    (
      #|#!/bin/dash
      #|# shellcheck disable=SC2034
      #|echo -ne foo
      #|let x=1
      #|
    ),
    [
      compat_error(
        3036, 3, 6, 9, "In dash, echo flags besides -n not supported.",
      ),
      compat_error(3039, 4, 1, 8, "In dash, 'let' is not supported."),
    ],
  )
}

///|
test "compat regression covers shell support sh builtin portability diagnostics" {
  assert_compat_case(
    "shell-support-sh-builtin-portability",
    (
      #|#!/bin/sh
      #|set -B
      #|local
      #|declare
      #|read -r
      #|
    ),
    [
      compat_warning(3041, 2, 5, 7, "In POSIX sh, set flag -B is undefined."),
      compat_warning(3043, 3, 1, 6, "In POSIX sh, 'local' is undefined."),
      compat_warning(3044, 4, 1, 8, "In POSIX sh, 'declare' is undefined."),
      compat_warning(
        3061, 5, 1, 5, "In POSIX sh, read without a variable is undefined.",
      ),
    ],
  )
}

///|
test "compat regression covers shell support bash-specific baseline diagnostics" {
  assert_compat_case(
    "shell-support-echo-sed-rewrite",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2154
      #|FOO=$(echo "$cow" | sed 's/foo/bar/g')
      #|
    ),
    [
      compat_style(
        2001, 3, 7, 38, "See if you can use ${variable//search/replace} instead.",
      ),
    ],
  )

  assert_compat_case(
    "shell-support-ps1-escape-baseline",
    (
      #|#!/bin/bash
      #|PS1='\\033[1;35m\\$ '
      #|
    ),
    [
      compat_info(
        2025, 2, 5, 22, "Make sure all escape sequences are enclosed in \\[..\\] to prevent line wrapping issues",
      ),
    ],
  )

  assert_compat_case(
    "shell-support-brace-range-baselines",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2086,SC2154
      #|echo {1..$n}
      #|eval echo DSC{0001..$n}.jpg
      #|
    ),
    [
      compat_warning(
        2051, 3, 6, 13, "Bash doesn't support variables in brace range expansions.",
      ),
      compat_style(
        2175, 4, 14, 24, "Quote this invalid brace expansion since it should be passed literally to eval.",
      ),
    ],
  )

  assert_compat_case(
    "shell-support-multidimensional-array-baseline",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2086,SC2154
      #|echo ${foo[1][2]}
      #|
    ),
    [
      compat_warning(
        2180, 3, 6, 18, "Bash does not support multidimensional arrays. Use 1D or associative arrays.",
      ),
    ],
  )
}

///|
test "compat regression covers shell support pipeline bang baseline diagnostics" {
  assert_compat_case(
    "shell-support-posix-multiple-bangs",
    (
      #|#!/bin/sh
      #|! ! true
      #|
    ),
    [
      compat_error(
        2325, 2, 1, 2, "Multiple ! in front of pipelines are a bash/ksh extension. Use only 0 or 1.",
      ),
    ],
  )

  assert_compat_case(
    "shell-support-mid-pipeline-bang",
    (
      #|#!/bin/bash
      #|true | ! true
      #|
    ),
    [
      compat_error(
        2326, 2, 8, 9, "! is not allowed in the middle of pipelines. Use command group as in cmd | { ! cmd; } if necessary.",
      ),
    ],
  )
}
