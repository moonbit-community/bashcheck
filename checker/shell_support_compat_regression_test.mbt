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
