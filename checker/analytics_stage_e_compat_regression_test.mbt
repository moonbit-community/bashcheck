///|
test "compat regression covers phase e arithmetic analytics diagnostics" {
  assert_compat_case(
    "phase-e-arithmetic-analytics",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|foo=3
      #|echo $(( $foo + 1 ))
      #|echo $(( 3 / 2 * 100 ))
      #|
    ),
    [
      compat_style(
        2004, 4, 10, 14, "$/${} is unnecessary on arithmetic variables.",
      ),
      compat_info(
        2017, 5, 12, 13, "Increase precision by replacing a/b*c with a*c/b.",
      ),
    ],
  )
}

///|
test "compat regression covers phase e condition analytics diagnostics" {
  assert_compat_case(
    "phase-e-condition-analytics",
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
    [
      compat_error(
        2070, 3, 6, 10, "-n doesn't work with unquoted arguments. Quote or use [[ ]].",
      ),
      compat_error(
        2077, 4, 7, 9, "You need spaces around the comparison operator.",
      ),
      compat_error(2074, 6, 8, 10, "Can't use =~ in [ ]. Use [[..]] instead."),
      compat_error(
        2075, 8, 7, 9, "Escaping \\< is required in [..], but invalid in [[..]]",
      ),
    ],
  )
}

///|
test "compat regression covers phase e optional condition analytics diagnostics" {
  assert_compat_case(
    "phase-e-optional-condition-analytics",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|# shellcheck enable=avoid-nullary-conditions,avoid-negated-conditions
      #|! [ -n "$var" ]
      #|[[ $(cmd) ]]
      #|! [[ $var -gt 3 ]]
      #|
    ),
    [
      compat_style(2237, 4, 1, 2, "Use [ -z .. ] instead of ! [ -n .. ]."),
      compat_style(
        2243, 5, 4, 10, "Prefer explicit -n to check for output (or run command without [/[[ to check for success).",
      ),
      compat_style(
        2335, 6, 1, 2, "Use [[ a -le b ]] instead of ! [[ a -gt b ]].",
      ),
    ],
  )
}

///|
test "compat regression covers phase e set-e suppressed analytics diagnostics" {
  assert_compat_case(
    "phase-e-set-e-suppressed",
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
    [
      compat_info(
        2310, 5, 1, 2, "This function is invoked in an && condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.",
      ),
      compat_info(
        2310, 6, 4, 5, "This function is invoked in an 'if' condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.",
      ),
      compat_info(
        2310, 7, 7, 8, "This function is invoked in a 'while' condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.",
      ),
      compat_info(
        2310, 8, 3, 4, "This function is invoked in a ! condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.",
      ),
    ],
  )
}

///|
test "compat regression covers phase e malformed command name diagnostics" {
  assert_compat_case(
    "phase-e-malformed-command-name",
    (
      #|#!/bin/bash
      #|$'foo\tbar'
      #|
    ),
    [
      compat_error(
        2289, 2, 1, 12, "This is interpreted as a command name containing a tab. Double check syntax.",
      ),
    ],
  )
}

///|
test "compat regression covers phase e existing analytics baseline tail" {
  assert_compat_case(
    "phase-e-analytics-single-quoted-expression",
    (
      #|#!/bin/bash
      #|echo '$foo'
      #|
    ),
    [
      compat_info(
        2016, 2, 6, 12, "Expressions don't expand in single quotes, use double quotes for that.",
      ),
    ],
  )

  assert_compat_case(
    "phase-e-analytics-tilde-in-quotes",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|var="~/out.txt"
      #|
    ),
    [
      compat_warning(
        2088, 3, 6, 15, "Tilde does not expand in quotes. Use $HOME.",
      ),
    ],
  )

  assert_compat_case(
    "phase-e-analytics-for-in-trailing-commas",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|for f in foo, bar,; do true; done
      #|
    ),
    [
      compat_warning(
        2258, 3, 10, 14, "The trailing comma is part of the value, not a separator. Delete or quote it.",
      ),
      compat_warning(
        2258, 3, 15, 19, "The trailing comma is part of the value, not a separator. Delete or quote it.",
      ),
    ],
  )
}

///|
test "compat regression covers phase e constant nullary analytics baseline" {
  assert_compat_case(
    "phase-e-analytics-constant-nullary",
    (
      #|#!/bin/bash
      #|[ false ]
      #|[ 0 ]
      #|[ true ]
      #|[ 1 ]
      #|
    ),
    [
      compat_error(2158, 2, 3, 8, "[ false ] is true. Remove the brackets."),
      compat_error(2159, 3, 3, 4, "[ 0 ] is true. Use 'false' instead."),
      compat_style(2160, 4, 3, 7, "Instead of '[ true ]', just use 'true'."),
      compat_style(2161, 5, 3, 4, "Instead of '[ 1 ]', use 'true'."),
    ],
  )
}

///|
test "compat regression covers phase e loop variable override analytics baseline" {
  assert_compat_case(
    "phase-e-analytics-loop-variable-override",
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
    [
      compat_warning(
        2167, 3, 1, 4, "This parent loop has its index variable overridden.",
      ),
      compat_warning(
        2165, 4, 3, 6, "This nested loop overrides the index variable of its parent.",
      ),
    ],
  )
}

///|
test "compat regression covers phase e assignment-shaped command analytics baseline" {
  assert_compat_case(
    "phase-e-analytics-assignment-shaped-command",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2086
      #|$var==42
      #|var${x}/=value
      #|
    ),
    [
      compat_error(
        2272, 3, 1, 9, "Command name contains ==. For comparison, use [ \"$var\" = value ].",
      ),
      compat_error(
        2276, 4, 1, 15, "This is interpreted as a command name containing '='. Bad assignment or comparison?",
      ),
    ],
  )
}
