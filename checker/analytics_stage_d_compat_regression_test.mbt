///|
test "compat regression covers phase d assignment analytics diagnostics" {
  assert_compat_case(
    "phase-d-assignment-analytics",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2086,SC2154
      #|echo ${foo$n}
      #|a="$@"
      #|b=*.png
      #|: ${x=*}
      #|
    ),
    [
      compat_error(
        2082, 3, 6, 14, "To expand via indirection, use arrays, ${!name} or (for sh only) eval.",
      ),
      compat_warning(
        2124, 4, 3, 7, "Assigning an array to a string! Assign as array, or use * instead of @ to concatenate.",
      ),
      compat_warning(
        2125, 5, 3, 8, "Brace expansions and globs are literal in assignments. Quote it or use an array.",
      ),
      compat_info(
        2223, 6, 3, 9, "This default assignment may cause DoS due to globbing. Quote it.",
      ),
    ],
  )
}

///|
test "compat regression covers phase d subshell style analytics diagnostics" {
  assert_compat_case(
    "phase-d-subshell-style-analytics",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2078
      #|( [ a ] )
      #|if ( [ a ] ); then :; fi
      #|( [ a ] && [ b ] )
      #|
    ),
    [
      compat_style(
        2234, 3, 1, 10, "Remove superfluous (..) around test command to avoid subshell overhead.",
      ),
      compat_style(
        2233, 4, 4, 13, "Remove superfluous (..) around condition to avoid subshell overhead.",
      ),
      compat_style(
        2235, 5, 1, 19, "Use { ..; } instead of (..) to avoid subshell overhead.",
      ),
    ],
  )
}

///|
test "compat regression covers phase d shebang parameter analytics diagnostics" {
  assert_compat_case(
    "phase-d-shebang-parameter-analytics",
    (
      #|#!/usr/bin/env bash -x
      #|echo ok
      #|
    ),
    [
      compat_error(
        2096, 1, 1, 23, "On most OS, shebangs can only specify a single parameter.",
      ),
    ],
  )
}
