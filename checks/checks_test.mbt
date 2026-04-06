///|
test "script directives disable matching checks" {
  let diagnostics = check_source(
    (
      #|# shellcheck disable=SC2006
      #|printf '%s' `foo`
      #|
    ),
  )
  assert_true(!has_code(diagnostics, 2006))
}

///|
test "range disables suppress matching diagnostics" {
  let diagnostics = check_source(
    (
      #|# shellcheck disable=SC2000-SC2100
      #|for f in "$(ls)"; do :; done
      #|
    ),
  )
  assert_true(!has_code(diagnostics, 2066))
}

///|
test "list item directives only suppress the annotated command" {
  let diagnostics = check_source(
    (
      #|echo ok
      #|# shellcheck disable=SC2046
      #|rm $(ls)
      #|printf '%s' $(date)
      #|
    ),
  )
  assert_true(count_code(diagnostics, 2046) == 1)
  let remaining = first_code(diagnostics, 2046)
  assert_eq(remaining.span.start.line, 4)
}

///|
test "nested list item directives suppress diagnostics inside compound commands" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|if true; then
      #|# shellcheck disable=SC2046
      #|rm $(date)
      #|fi
      #|
    ),
  )
  assert_true(!has_code(diagnostics, 2046))
}

///|
test "checks are returned in source order" {
  let diagnostics = check_source(
    (
      #|printf '%s' $(date)
      #|printf '%s' `foo`
      #|
    ),
  )
  assert_eq(diagnostics[0].span.start.line, 1)
}
