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
