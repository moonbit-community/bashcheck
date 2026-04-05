///|
test "phase 1 parser condition diagnostics align with shellcheck" {
  assert_parser_diagnostics_match("SC1014", "[ grep foo ]\n", [
    shellcheck_error(
      1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
    ),
    shellcheck_warning(
      1014, 1, 3, "Use 'if cmd; then ..' to check exit code, or 'if [[ $(cmd) == .. ]]' to check output.",
    ),
    shellcheck_error(
      1072, 1, 8, "Expected test to end here (don't wrap commands in []/[[]]). Fix any mentioned problems and try again.",
    ),
  ])

  assert_parser_diagnostics_match("SC1019", "[ -n ]\n", [
    shellcheck_error(
      1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
    ),
    shellcheck_error(
      1019, 1, 6, "Expected this to be an argument to the unary condition.",
    ),
    shellcheck_error(
      1072, 1, 7, "Unexpected . Fix any mentioned problems and try again.",
    ),
  ])

  assert_parser_diagnostics_match("SC1020", "[ a = b]\n", [
    shellcheck_error(
      1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
    ),
    shellcheck_error(1020, 1, 9, "You need a space before the ]."),
    shellcheck_error(
      1072, 1, 9, "Missing space before ]. Fix any mentioned problems and try again.",
    ),
  ])

  assert_parser_diagnostics_match("SC1021", "[ foo\\) ]\n", [
    shellcheck_error(
      1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
    ),
    shellcheck_error(1021, 1, 8, "You need a space before the \\)"),
    shellcheck_error(
      1072, 1, 8, "Missing space before ). Fix any mentioned problems and try again.",
    ),
  ])

  assert_parser_diagnostics_match("SC1026", "[ [ a = b ] ]\n", [
    shellcheck_error(
      1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
    ),
    shellcheck_error(
      1026, 1, 3, "If grouping expressions inside [..], use \\( ..\\).",
    ),
    shellcheck_error(
      1072, 1, 5, "Expected test to end here (don't wrap commands in []/[[]]). Fix any mentioned problems and try again.",
    ),
  ])

  assert_parser_diagnostics_match("SC1027", "[ foo = ]\n", [
    shellcheck_error(
      1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
    ),
    shellcheck_error(1027, 1, 7, "Expected another argument for this operator."),
    shellcheck_error(
      1072, 1, 10, "Unexpected . Fix any mentioned problems and try again.",
    ),
  ])

  assert_parser_diagnostics_match("SC1028", "[ ( a = b ) ]\n", [
    shellcheck_error(
      1028, 1, 3, "In [..] you have to escape \\( \\) or preferably combine [..] expressions.",
    ),
    shellcheck_error(
      1028, 1, 11, "In [..] you have to escape \\( \\) or preferably combine [..] expressions.",
    ),
  ])

  assert_parser_diagnostics_match("SC1029", "[[ \\( a = b \\) ]]\n", [
    shellcheck_error(1029, 1, 4, "In [[..]] you shouldn't escape ( or )."),
    shellcheck_error(1029, 1, 13, "In [[..]] you shouldn't escape ( or )."),
  ])

  assert_parser_diagnostics_match("SC1076", "[ 1 + 2 ]\n", [
    shellcheck_error(
      1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
    ),
    shellcheck_error(
      1072, 1, 5, "Expected test to end here (don't wrap commands in []/[[]]). Fix any mentioned problems and try again.",
    ),
    shellcheck_error(
      1076, 1, 5, "Trying to do math? Use e.g. [ $((i/2+7)) -ge 18 ].",
    ),
  ])

  assert_parser_diagnostics_match("SC1100", "[ foo \uFF0Deq bar ]\n", [
    shellcheck_error(
      1100, 1, 7, "This is a unicode dash. Delete and retype as ASCII minus.",
    ),
  ])

  assert_parser_diagnostics_match("SC1108", "[ foo= bar ]\n", [
    shellcheck_error(
      1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
    ),
    shellcheck_error(1108, 1, 3, "You need a space before and after the = ."),
    shellcheck_error(
      1072, 1, 8, "Expected test to end here (don't wrap commands in []/[[]]). Fix any mentioned problems and try again.",
    ),
  ])
}
