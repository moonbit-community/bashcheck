///|
test "compat regression covers command formatting diagnostics" {
  assert_compat_case(
    "commands-formatting-diagnostics",
    (
      #|#!/bin/bash
      #|fmt=%s
      #|printf "$fmt" foo
      #|tr [a-f] [A-F]
      #|grep '*foo*' file
      #|
    ),
    [
      compat_info(
        2059, 3, 8, 14, "Don't use variables in the printf format string. Use printf '..%s..' \"$foo\".",
      ),
      compat_warning(
        2060, 4, 4, 9, "Quote parameters to tr to prevent glob expansion.",
      ),
      compat_warning(
        2060, 4, 10, 15, "Quote parameters to tr to prevent glob expansion.",
      ),
      compat_warning(
        2063, 5, 6, 13, "Grep uses regex, but this looks like a glob.",
      ),
    ],
  )
}

///|
test "compat regression covers command status diagnostics" {
  assert_compat_case(
    "commands-status-diagnostics",
    (
      #|#!/bin/bash
      #|f(){ return -1; }
      #|f
      #|exit 1 2
      #|
    ),
    [
      compat_error(
        2152, 2, 13, 15, "Can only return 0-255. Other data should be written to stdout.",
      ),
      compat_error(
        2241, 4, 6, 7, "The exit status can only be one integer 0-255. Use stdout for other data.",
      ),
    ],
  )
}

///|
test "compat regression covers command tr and find diagnostics" {
  assert_compat_case(
    "commands-tr-find-diagnostics",
    (
      #|#!/bin/bash
      #|tr foo bar
      #|tr '[a-z]' '[A-Z]'
      #|find . -exec echo {} > file \;
      #|
    ),
    [
      compat_info(
        2020, 2, 4, 7, "tr replaces sets of chars, not words (mentioned due to duplicates).",
      ),
      compat_info(
        2021, 3, 4, 11, "Don't use [] around classes in tr, it replaces literal square brackets.",
      ),
      compat_info(
        2021, 3, 12, 19, "Don't use [] around classes in tr, it replaces literal square brackets.",
      ),
      compat_warning(
        2227, 4, 22, 28, "Redirection applies to the find command itself. Rewrite to work per action (or move to end).",
      ),
    ],
  )
}

///|
test "compat regression covers expr compatibility diagnostics" {
  assert_compat_case(
    "commands-expr-diagnostics",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2003
      #|expr match foo bar
      #|expr foo : fo*
      #|expr 5 -3
      #|
    ),
    [
      compat_info(
        2308, 3, 6, 11, "'expr match' has unspecified results. Prefer 'expr str : regex'.",
      ),
      compat_warning(
        2305, 4, 12, 15, "Quote regex argument to expr to avoid it expanding as a glob.",
      ),
      compat_warning(
        2307, 5, 1, 10, "'expr' expects 3+ arguments, but sees 2. Make sure each operator/operand is a separate argument, and escape <>&|.",
      ),
    ],
  )
}

///|
test "compat regression covers expr glob argument diagnostics" {
  assert_compat_case(
    "commands-expr-glob-argument-diagnostics",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2003,SC2035
      #|expr 1 + 2 *
      #|expr 1 + 2 *.txt
      #|
    ),
    [
      compat_warning(
        2306, 3, 12, 13, "Escape glob characters in arguments to expr to avoid pathname expansion.",
      ),
      compat_warning(
        2306, 4, 12, 17, "Escape glob characters in arguments to expr to avoid pathname expansion.",
      ),
    ],
  )
}
