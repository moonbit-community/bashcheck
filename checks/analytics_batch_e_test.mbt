///|
test "analytics batch e flags unquoted -n in single-bracket tests" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[ -n $foo ]
      #|[ -n $cow -o -t 1 ]
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2070), 2)
}

///|
test "analytics batch e avoids quoted and double-bracket -n false positives" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[[ -n $foo ]]
      #|[ -n "$@" ]
      #|[ 3 \> 2 ]
      #|[ foo = bar ]
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2070))
}

///|
test "analytics batch e flags literal-breaking and constant nullary tests" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[ $foo=3 ]
      #|[ -z foo ]
      #|[ "$(true) " ]
      #|[[ ! cmd ]]
      #|[ false ]
      #|[ 0 ]
      #|[[ true ]]
      #|[ 1 ]
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2077))
  assert_eq(count_code(diagnostics, 2157), 2)
  assert_true(has_code(diagnostics, 2078))
  assert_true(has_code(diagnostics, 2158))
  assert_true(has_code(diagnostics, 2159))
  assert_true(has_code(diagnostics, 2160))
  assert_true(has_code(diagnostics, 2161))
}

///|
test "analytics batch e avoids literal-breaking false positives for dynamic tests" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[ -z $(true) ]
      #|[ $(true)$(true) ]
      #|if [ "$foo" = bar ]; then
      #|  :
      #|fi
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2077))
  assert_true(!has_code(diagnostics, 2157))
  assert_true(!has_code(diagnostics, 2078))
}

///|
test "analytics batch e flags arithmetic literals with invalid octal digits" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|(( 0192 ))
      #|value=$((018))
      #|(( 0x192 ))
      #|(( 1 ^ 0777 ))
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2080), 2)
}
