///|
test "analytics batch t flags deprecated dollar brackets and spurious expansion commands" {
  let diagnostics = check_source(
    (
      #|echo $[1+2]
      #|$((i++))
      #|$(foo)
      #|`foo`
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2007), 1)
  assert_eq(count_code(diagnostics, 2084), 1)
  assert_eq(count_code(diagnostics, 2091), 1)
  assert_eq(count_code(diagnostics, 2092), 1)
}

///|
test "analytics batch t flags spurious exec and command-like assignments" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|exec foo; true
      #|for f in *; do exec "$f"; done
      #|out=cat foo
      #|here=pwd
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2093), 2)
  assert_eq(count_code(diagnostics, 2209), 2)
}

///|
test "analytics batch t flags useless echo in command substitutions and skips exceptions" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2046,SC2006,SC2154
      #|cmd $(echo foo)
      #|cmd `echo bar`
      #|cmd "$(echo "$var")"
      #|cmd $(echo *.c)
      #|cmd $(echo -n foo)
      #|cmd $(echo "$(date)")
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2116), 3)
}

///|
test "analytics batch t flags redirecting through the same file in a pipeline" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|cat foo > foo
      #|cat lol | sed -e 's/a/b/g' > lol
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2094), 4)
}

///|
test "analytics batch t skips execfail cleanup and non-command assignments" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|shopt -s execfail
      #|exec foo; true
      #|exec bar; :
      #|out=ls -l
      #|PAGER="cat" grep bar
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2093), 0)
  assert_eq(count_code(diagnostics, 2209), 0)
  assert_eq(count_code(diagnostics, 2037), 1)
}

///|
test "analytics batch t skips harmless and special redirect pairs" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|printf x < foo > foo
      #|cat /dev/null > /dev/null
      #|cat foo > bar
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2094), 0)
  assert_eq(count_code(diagnostics, 2217), 1)
}
