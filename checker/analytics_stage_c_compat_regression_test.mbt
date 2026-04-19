///|
test "compat regression covers phase c cd-back analytics diagnostics" {
  assert_compat_case(
    "phase-c-cd-back-analytics",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2164
      #|for f in *; do cd "$f"; git pull; cd ..; done
      #|
    ),
    [
      compat_info(
        2103, 3, 35, 40, "Use a ( subshell ) to avoid having to cd back.",
      ),
    ],
  )
}

///|
test "compat regression covers phase c stderr redirect order analytics diagnostics" {
  assert_compat_case(
    "phase-c-stderr-redirect-order-analytics",
    (
      #|#!/bin/bash
      #|printf x 2>&1 > cow
      #|printf x | cat 2>&1 > /dev/null
      #|
    ),
    [
      compat_warning(
        2069, 2, 10, 14, "To redirect stdout+stderr, 2>&1 must be last (or use '{ cmd > file; } 2>&1' to clarify).",
      ),
      compat_warning(
        2069, 3, 16, 20, "To redirect stdout+stderr, 2>&1 must be last (or use '{ cmd > file; } 2>&1' to clarify).",
      ),
    ],
  )
}

///|
test "compat regression covers phase c ksh stderr pipe analytics diagnostics" {
  assert_compat_case(
    "phase-c-ksh-stderr-pipe-analytics",
    (
      #|#!/bin/ksh
      #|foo|&bar
      #|
    ),
    [compat_error(2118, 2, 4, 6, "Ksh does not support |&. Use 2>&1 |.")],
  )
}

///|
test "compat regression covers phase c unsupported shell feature analytics diagnostics" {
  assert_compat_case(
    "phase-c-unsupported-shell-feature-analytics",
    (
      #|#!/bin/sh
      #|x=foo
      #|case "$x" in bar) baz ;& esac
      #|
    ),
    [
      compat_error(
        2127, 3, 1, 30, "To use cases with ;&, specify #!/usr/bin/env bash or ksh",
      ),
    ],
  )
  assert_compat_case(
    "phase-c-bash-only-case-continue-analytics",
    (
      #|#!/bin/ksh
      #|x=foo
      #|case "$x" in bar) baz ;;& esac
      #|
    ),
    [
      compat_error(
        2127, 3, 1, 31, "To use cases with ;;&, specify #!/usr/bin/env bash",
      ),
    ],
  )
  assert_compat_case(
    "phase-c-brace-command-expansion-analytics",
    (
      #|#!/bin/dash
      #|: "${ ls; }"
      #|
    ),
    [
      compat_error(
        2127, 2, 4, 12, "To use ${ ..; } command expansion, specify #!/usr/bin/env bash or ksh",
      ),
    ],
  )
}

///|
test "compat regression covers phase c append and grep-q analytics diagnostics" {
  assert_compat_case(
    "phase-c-append-and-grep-q-analytics",
    (
      #|#!/bin/bash
      #|foo >> file; bar >> file; baz >> file;
      #|[[ $(foo | grep bar) ]]
      #|[ -z "$(foo | grep bar)" ]
      #|
    ),
    [
      compat_style(
        2129, 2, 1, 12, "Consider using { cmd1; cmd2; } >> file instead of individual redirects.",
      ),
      compat_style(
        2143, 3, 4, 22, "Use grep -q instead of comparing output with [ -n .. ].",
      ),
      compat_style(
        2143, 4, 3, 5, "Use ! grep -q instead of comparing output with [ -z .. ].",
      ),
    ],
  )
}

///|
test "compat regression covers phase c set-e bang analytics diagnostics" {
  assert_compat_case(
    "phase-c-set-e-bang-analytics",
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
    [
      compat_info(
        2251, 3, 16, 17, "This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked.",
      ),
      compat_info(
        2251, 4, 3, 4, "This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked.",
      ),
      compat_info(
        2251, 5, 1, 2, "This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked.",
      ),
      compat_info(
        2251, 6, 1, 2, "This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked.",
      ),
    ],
  )
}

///|
test "compat regression covers phase c modified arithmetic redirection analytics diagnostics" {
  assert_compat_case(
    "phase-c-modified-arithmetic-redirection-analytics",
    (
      #|#!/bin/bash
      #|printf %s x > $((i++))
      #|printf %s x 2> $((i+=1))
      #|
    ),
    [
      compat_warning(
        2257, 2, 19, 21, "Arithmetic modifications in command redirections may be discarded. Do them separately.",
      ),
      compat_warning(
        2257, 3, 20, 22, "Arithmetic modifications in command redirections may be discarded. Do them separately.",
      ),
    ],
  )
}

///|
test "compat regression covers phase c bad test and-or analytics diagnostics" {
  assert_compat_case(
    "phase-c-bad-test-and-or-analytics",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2078
      #|a=$1
      #|[ "$a" ] & [ "$a" ]
      #|test -e foo & [ "$a" ]
      #|[ "$a" ] | [ "$a" ]
      #|
    ),
    [
      compat_error(
        2265, 4, 10, 11, "Use && for logical AND. Single & will background and return true.",
      ),
      compat_error(
        2265, 5, 13, 14, "Use && for logical AND. Single & will background and return true.",
      ),
      compat_warning(
        2266, 6, 10, 11, "Use || for logical OR. Single | will pipe.",
      ),
    ],
  )
}
