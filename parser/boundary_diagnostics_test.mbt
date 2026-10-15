///|
test "boundary diagnostics match ShellCheck for SC1038" {
  assert_parser_diagnostics_match(
    "SC1038",
    (
      #|cat << (foo)
      #|
    ),
    [
      parser_info(
        1009, 1, 1, "The mentioned syntax error was in this simple command.",
      ),
      parser_error(
        1038, 1, 5, "Shells are space sensitive. Use '< <(cmd)', not '<< (cmd)'.",
      ),
      parser_error(
        1073, 1, 5, "Couldn't parse this here document. Fix to allow more checks.",
      ),
      parser_error(1072, 1, 8, " Fix any mentioned problems and try again."),
    ],
  )
}

///|
test "boundary diagnostics match ShellCheck for SC1064" {
  assert_parser_diagnostics_match(
    "SC1064",
    (
      #|foo() echo hi
      #|
    ),
    [
      parser_error(
        1073, 1, 1, "Couldn't parse this function. Fix to allow more checks.",
      ),
      parser_error(1064, 1, 7, "Expected a { to open the function definition."),
      parser_error(1072, 1, 7, " Fix any mentioned problems and try again."),
    ],
  )
}

///|
test "boundary diagnostics match ShellCheck for SC1084" {
  assert_parser_diagnostics_match(
    "SC1084",
    (
      #|!#/bin/bash
      #|echo hi
      #|
    ),
    [parser_error(1084, 1, 1, "Use #!, not !#, for the shebang.")],
  )
}

///|
test "boundary diagnostics match ShellCheck for SC1093" {
  let source_depth_files : Array[(String, String)] = []
  for i in 0..<101 {
    source_depth_files.push(
      (
        "f\{i}.sh",
        (
          $|source f\{i + 1}.sh
          $|
        ),
      ),
    )
  }
  source_depth_files.push(
    (
      "f101.sh",
      (
        #|echo ok
        #|
      ),
    ),
  )
  assert_parser_diagnostics_match_with_options(
    "SC1093",
    (
      #|source f1.sh
      #|
    ),
    [
      parser_info(
        1093, 1, 8, "This file appears to be recursively sourced. Ignoring.",
      ),
    ],
    sourced_bash_parser_options("f0.sh", source_depth_files),
  )
}

///|
test "boundary diagnostics match ShellCheck for SC1104" {
  assert_parser_diagnostics_match(
    "SC1104",
    (
      #|!/bin/bash
      #|echo hi
      #|
    ),
    [parser_error(1104, 1, 1, "Use #!, not just !, for the shebang.")],
  )
}

///|
test "boundary diagnostics match ShellCheck for SC1113" {
  assert_parser_diagnostics_match(
    "SC1113",
    (
      #|#/bin/bash
      #|echo hi
      #|
    ),
    [parser_error(1113, 1, 2, "Use #!, not just #, for the shebang.")],
  )
}

///|
test "boundary diagnostics match ShellCheck for SC1114" {
  assert_parser_diagnostics_match(
    "SC1114",
    (
      #| #!/bin/bash
      #|echo hi
      #|
    ),
    [parser_error(1114, 1, 1, "Remove leading spaces before the shebang.")],
  )
}

///|
test "boundary diagnostics match ShellCheck for SC1115" {
  assert_parser_diagnostics_match(
    "SC1115",
    (
      #|# !/bin/bash
      #|echo hi
      #|
    ),
    [parser_error(1115, 1, 2, "Remove spaces between # and ! in the shebang.")],
  )
}

///|
test "boundary diagnostics match ShellCheck for SC1128" {
  assert_parser_diagnostics_match(
    "SC1128",
    (
      #|# comment
      #|#!/bin/bash
      #|echo hi
      #|
    ),
    [
      parser_error(
        1128, 2, 1, "The shebang must be on the first line. Delete blanks and move comments.",
      ),
    ],
  )
}
