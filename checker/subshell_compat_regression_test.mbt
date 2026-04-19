///|
test "compat regression covers subshell assignment diagnostics" {
  let spec = @checker.CheckSpec::default().with_include_codes([2030, 2031])

  assert_compat_case_with_spec(
    "subshell-assignment-pipeline",
    (
      #|#!/bin/bash
      #|cat foo | while read -r bar; do a=$bar; done
      #|echo "${a:-}"
      #|
    ),
    [
      compat_info(
        2030, 2, 33, 34, "Modification of a is local (to subshell caused by pipeline).",
      ),
      compat_info(
        2031, 3, 7, 13, "a was modified in a subshell. That change might be lost.",
      ),
    ],
    spec,
  )

  assert_compat_case_with_spec(
    "subshell-assignment-background",
    (
      #|#!/bin/bash
      #|read -r n & n=foo$n
      #|
    ),
    [
      compat_info(
        2030, 2, 9, 10, "Modification of n is local (to subshell caused by backgrounding &).",
      ),
      compat_info(
        2031, 2, 18, 20, "n was modified in a subshell. That change might be lost.",
      ),
    ],
    spec,
  )
}
