///|
test "analytics batch v flags subshell assignments from pipelines and backgrounds" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|cat foo | while read -r bar; do a=$bar; done
      #|echo "$a"
      #|read -r n & n=foo$n
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2030), 2)
  assert_eq(count_code(diagnostics, 2031), 2)
}

///|
test "analytics batch v skips current-shell pipeline and in-subshell reads" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|shopt -s lastpipe
      #|echo a | read -r b
      #|echo "$b"
      #|( a=1; echo "$a"; )
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2030), 0)
  assert_eq(count_code(diagnostics, 2031), 0)
}

///|
test "analytics batch v honors ksh pipeline semantics" {
  let diagnostics = check_source(
    (
      #|#!/bin/ksh
      #|cat foo | while read -r bar; do a=$bar; done
      #|echo "$a"
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2030), 0)
  assert_eq(count_code(diagnostics, 2031), 0)
}

///|
test "analytics batch v anchors command-driven writes to variable operands" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|( typeset -a lol=a; ); echo $lol
      #|
    ),
  )

  let origin = first_code(diagnostics, 2030)
  let readback = first_code(diagnostics, 2031)
  assert_eq(origin.span.start.line, 2)
  assert_eq(origin.span.start.column, 14)
  assert_eq(origin.span.end.column, 17)
  assert_eq(readback.span.start.column, 29)
  assert_eq(readback.span.end.column, 33)
}
