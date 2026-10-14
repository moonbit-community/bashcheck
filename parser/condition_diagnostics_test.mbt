///|
test "condition diagnostics match ShellCheck for SC1014" {
  assert_parser_diagnostics_match(
    "SC1014",
    (
      #|[ grep foo ]
      #|
    ),
    [
      parser_error(
        1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
      ),
      parser_warning(
        1014, 1, 3, "Use 'if cmd; then ..' to check exit code, or 'if [[ $(cmd) == .. ]]' to check output.",
      ),
      parser_error(
        1072, 1, 8, "Expected test to end here (don't wrap commands in []/[[]]). Fix any mentioned problems and try again.",
      ),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1019" {
  assert_parser_diagnostics_match(
    "SC1019",
    (
      #|[ -n ]
      #|
    ),
    [
      parser_error(
        1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
      ),
      parser_error(
        1019, 1, 6, "Expected this to be an argument to the unary condition.",
      ),
      parser_error(
        1072, 1, 7, "Unexpected . Fix any mentioned problems and try again.",
      ),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1020" {
  assert_parser_diagnostics_match(
    "SC1020",
    (
      #|[ a = b]
      #|
    ),
    [
      parser_error(
        1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
      ),
      parser_error(1020, 1, 9, "You need a space before the ]."),
      parser_error(
        1072, 1, 9, "Missing space before ]. Fix any mentioned problems and try again.",
      ),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1021" {
  assert_parser_diagnostics_match(
    "SC1021",
    (
      #|[ foo\) ]
      #|
    ),
    [
      parser_error(
        1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
      ),
      parser_error(1021, 1, 8, "You need a space before the \\)"),
      parser_error(
        1072, 1, 8, "Missing space before ). Fix any mentioned problems and try again.",
      ),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1026" {
  assert_parser_diagnostics_match(
    "SC1026",
    (
      #|[ [ a = b ] ]
      #|
    ),
    [
      parser_error(
        1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
      ),
      parser_error(
        1026, 1, 3, "If grouping expressions inside [..], use \\( ..\\).",
      ),
      parser_error(
        1072, 1, 5, "Expected test to end here (don't wrap commands in []/[[]]). Fix any mentioned problems and try again.",
      ),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1027" {
  assert_parser_diagnostics_match(
    "SC1027",
    (
      #|[ foo = ]
      #|
    ),
    [
      parser_error(
        1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
      ),
      parser_error(1027, 1, 7, "Expected another argument for this operator."),
      parser_error(
        1072, 1, 10, "Unexpected . Fix any mentioned problems and try again.",
      ),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1028" {
  assert_parser_diagnostics_match(
    "SC1028",
    (
      #|[ ( a = b ) ]
      #|
    ),
    [
      parser_error(
        1028, 1, 3, "In [..] you have to escape \\( \\) or preferably combine [..] expressions.",
      ),
      parser_error(
        1028, 1, 11, "In [..] you have to escape \\( \\) or preferably combine [..] expressions.",
      ),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1029" {
  assert_parser_diagnostics_match(
    "SC1029",
    (
      #|[[ \( a = b \) ]]
      #|
    ),
    [
      parser_error(1029, 1, 4, "In [[..]] you shouldn't escape ( or )."),
      parser_error(1029, 1, 13, "In [[..]] you shouldn't escape ( or )."),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1033" {
  assert_parser_diagnostics_match(
    "SC1033",
    (
      #|[[ foo ]
      #|
    ),
    [
      parser_error(
        1033, 1, 8, "Test expression was opened with double [[ but closed with single ]. Make sure they match.",
      ),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1034" {
  assert_parser_diagnostics_match(
    "SC1034",
    (
      #|[ foo ]]
      #|
    ),
    [
      parser_error(
        1034, 1, 1, "Test expression was opened with single [ but closed with double ]]. Make sure they match.",
      ),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1076" {
  assert_parser_diagnostics_match(
    "SC1076",
    (
      #|[ 1 + 2 ]
      #|
    ),
    [
      parser_error(
        1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
      ),
      parser_error(
        1072, 1, 5, "Expected test to end here (don't wrap commands in []/[[]]). Fix any mentioned problems and try again.",
      ),
      parser_error(
        1076, 1, 5, "Trying to do math? Use e.g. [ $((i/2+7)) -ge 18 ].",
      ),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1100" {
  assert_parser_diagnostics_match(
    "SC1100",
    (
      #|[ foo －eq bar ]
      #|
    ),
    [
      parser_error(
        1100, 1, 7, "This is a unicode dash. Delete and retype as ASCII minus.",
      ),
    ],
  )
}

///|
test "condition diagnostics match ShellCheck for SC1108" {
  assert_parser_diagnostics_match(
    "SC1108",
    (
      #|[ foo= bar ]
      #|
    ),
    [
      parser_error(
        1073, 1, 1, "Couldn't parse this test expression. Fix to allow more checks.",
      ),
      parser_error(1108, 1, 3, "You need a space before and after the = ."),
      parser_error(
        1072, 1, 8, "Expected test to end here (don't wrap commands in []/[[]]). Fix any mentioned problems and try again.",
      ),
    ],
  )
}
