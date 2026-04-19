///|
async test "phase 3 dynamic json diff aligns subshell assignment diagnostics" {
  assert_shellcheck_json_matches(
    "SC2030-SC2031-pipeline",
    (
      #|#!/bin/bash
      #|cat foo | while read -r bar; do a=$bar; done
      #|echo "${a:-}"
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2030-SC2031-background",
    (
      #|#!/bin/bash
      #|read -r n & n=foo$n
      #|
    ),
  )
}
