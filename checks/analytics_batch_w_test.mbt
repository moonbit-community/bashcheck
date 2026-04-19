///|
test "analytics batch w flags indirection assignment and default assignment gaps" {
  let diagnostics = check_source(
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

  assert_eq(count_code(diagnostics, 2082), 1)
  assert_eq(count_code(diagnostics, 2124), 1)
  assert_eq(count_code(diagnostics, 2125), 1)
  assert_eq(count_code(diagnostics, 2223), 1)
}

///|
test "analytics batch w ignores valid indirection quoted defaults and scalar-safe assignments" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2086,SC2154
      #|a=$*
      #|b=${arr[*]}
      #|echo ${!name}
      #|: "${x=*}"
      #|: ${x:-*}
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2082))
  assert_true(!has_code(diagnostics, 2124))
  assert_true(!has_code(diagnostics, 2125))
  assert_true(!has_code(diagnostics, 2223))
}

///|
test "analytics batch w prefers SC2223 over SC2086 for colon default assignments" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|: ${x=*}
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2223), 1)
  assert_true(!has_code(diagnostics, 2086))
}

///|
test "analytics batch w flags subshelled tests with shellcheck-style buckets" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2078
      #|( [ a ] )
      #|if ( [ a ] ); then :; fi
      #|( [ a ] && [ b ] )
      #|f() ( [ a ] )
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2233), 1)
  assert_eq(count_code(diagnostics, 2234), 1)
  assert_eq(count_code(diagnostics, 2235), 2)
}

///|
test "analytics batch w suppresses subshell style warnings when tests mutate state" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|( [[ ${var:=x} = y ]] )
      #|( [[ $((i++)) = 10 ]] )
      #|( [[ $((i+=1)) = 10 ]] )
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2233))
  assert_true(!has_code(diagnostics, 2234))
  assert_true(!has_code(diagnostics, 2235))
}
