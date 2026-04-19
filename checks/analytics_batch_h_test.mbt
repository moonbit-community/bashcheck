///|
test "analytics batch h flags globs as options" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|rm *.txt
      #|ls ??.*
      #|rm -- *.txt
      #|echo 'Files:' *.txt
      #|printf '%s\n' *
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2035), 2)
}

///|
test "analytics batch h flags suspicious IFS values" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|IFS="\n"
      #|IFS=' \t\n'
      #|IFS=$'\t'
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2141), 2)
}

///|
test "analytics batch h flags overriding PATH assignments" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|PATH="$var/$foo"
      #|PATH="mydir"
      #|PATH=/cow/foo
      #|PATH='/bin:/sbin'
      #|PATH=$OLDPATH
      #|PATH=$PATH:/stuff
      #|PATH="$var/$foo" cmd
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2123), 3)
}

///|
test "analytics batch h flags quoted tildes in PATH" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|PATH="$PATH:~/bin"
      #|PATH='~foo/bin'
      #|PATH=~/bin
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2147), 2)
}
