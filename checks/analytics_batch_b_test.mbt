///|
test "analytics batch b flags char class range and trailing bracket diagnostics" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2035,SC2215
      #|ls *[:digit:].jpg
      #|ls [10-15]
      #|if -z n ]]; then true; fi
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2101), 1)
  assert_eq(count_code(diagnostics, 2102), 1)
  assert_eq(count_code(diagnostics, 2171), 1)
}

///|
test "analytics batch b avoids char class and trailing bracket false positives" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|ls *[[:digit:]].jpg
      #|ls [a-zA-Z]
      #|tr -d [aa]
      #|run [ foo ]
      #|run bar ']'
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2101))
  assert_true(!has_code(diagnostics, 2102))
  assert_true(!has_code(diagnostics, 2171))
}
