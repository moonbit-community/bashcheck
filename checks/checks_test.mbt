///|
test "script directives disable matching checks" {
  let diagnostics = check_source(
    "# shellcheck disable=SC2006\nprintf '%s' `foo`\n",
  )
  assert_true(!has_code(diagnostics, 2006))
}

///|
test "range disables suppress matching diagnostics" {
  let diagnostics = check_source(
    "# shellcheck disable=SC2000-SC2100\nfor f in \"$(ls)\"; do :; done\n",
  )
  assert_true(!has_code(diagnostics, 2066))
}

///|
test "list item directives only suppress the annotated command" {
  let diagnostics = check_source(
    "echo ok\n# shellcheck disable=SC2046\nrm $(ls)\nprintf '%s' $(date)\n",
  )
  assert_true(count_code(diagnostics, 2046) == 1)
  let remaining = first_code(diagnostics, 2046)
  assert_eq(remaining.span.start.line, 4)
}

///|
test "nested list item directives suppress diagnostics inside compound commands" {
  let diagnostics = check_source(
    "#!/bin/bash\nif true; then\n# shellcheck disable=SC2046\nrm $(date)\nfi\n",
  )
  assert_true(!has_code(diagnostics, 2046))
}

///|
test "checks are returned in source order" {
  let diagnostics = check_source("printf '%s' $(date)\nprintf '%s' `foo`\n")
  assert_eq(diagnostics[0].span.start.line, 1)
}
