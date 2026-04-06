///|
fn find_diagnostic(diagnostics : Array[Diagnostic], code : Int) -> Diagnostic? {
  for diagnostic in diagnostics {
    if diagnostic.code == Some(code) {
      return Some(diagnostic)
    }
  }
  None
}

///|
fn count_diagnostics(diagnostics : Array[Diagnostic], code : Int) -> Int {
  let mut count = 0
  for diagnostic in diagnostics {
    if diagnostic.code == Some(code) {
      count += 1
    }
  }
  count
}

///|
fn expect_diagnostic(
  diagnostics : Array[Diagnostic],
  code : Int,
  line : Int,
  column : Int,
  message : String,
) -> Unit {
  match find_diagnostic(diagnostics, code) {
    Some(diagnostic) => {
      if diagnostic.span.start.line != line {
        abort(
          "diagnostic \{code}: expected line \{line}, got \{diagnostic.span.start.line}",
        )
      }
      if diagnostic.span.start.column != column {
        abort(
          "diagnostic \{code}: expected column \{column}, got \{diagnostic.span.start.column}",
        )
      }
      if diagnostic.message != message {
        abort(
          "diagnostic \{code}: expected message \{message}, got \{diagnostic.message}",
        )
      }
    }
    None => abort("missing diagnostic \{code}")
  }
}

///|
fn expect_diagnostic_at(
  diagnostics : Array[Diagnostic],
  code : Int,
  line : Int,
  column : Int,
  message : String,
) -> Unit {
  for diagnostic in diagnostics {
    if diagnostic.code == Some(code) &&
      diagnostic.span.start.line == line &&
      diagnostic.span.start.column == column &&
      diagnostic.message == message {
      return
    }
  }
  abort(
    "missing diagnostic \{code} at \{line}:\{column} with message \{message}",
  )
}

///|
test "condition trailing tokens include shellcheck parse-stop diagnostic" {
  let report = parse_script_report("[[ x ]] foo")
  match report.script {
    Some(_) => ()
    None => fail("expected recoverable parse")
  }
  expect_diagnostic(
    report.diagnostics,
    1140,
    1,
    9,
    "Unexpected parameters after condition. Missing &&/||, or bad expression?",
  )
  expect_diagnostic(
    report.diagnostics,
    1070,
    1,
    9,
    "Parsing stopped here. Mismatched keywords or invalid parentheses?",
  )
}

///|
test "quote diagnostics use shellcheck positions and wording" {
  let double_report = parse_script_report(
    (
      #|"foo
      #|bar"foo
    ),
  )
  expect_diagnostic(
    double_report.diagnostics,
    1078,
    1,
    1,
    "Did you forget to close this double quoted string?",
  )
  expect_diagnostic(
    double_report.diagnostics,
    1079,
    2,
    4,
    "This is actually an end quote, but due to next char it looks suspect.",
  )

  let single_report = parse_script_report("echo 'it's")
  expect_diagnostic(
    single_report.diagnostics,
    1011,
    1,
    9,
    "This apostrophe terminated the single quoted string!",
  )

  let backtick_report = parse_script_report(
    (
      #|echo `foo
      #|echo `bar
    ),
  )
  expect_diagnostic(
    backtick_report.diagnostics,
    1079,
    2,
    6,
    "This is actually an end quote, but due to next char it looks suspect.",
  )
}

///|
test "here documents surface nested parse errors with here-doc context" {
  let report = parse_script_report(
    (
      #|cat << foo
      #|`
      #|foo
    ),
  )
  match report.script {
    Some(_) => ()
    None => fail("expected recoverable parse")
  }
  expect_diagnostic(
    report.diagnostics,
    1009,
    1,
    5,
    "The mentioned syntax error was in this here document.",
  )
  expect_diagnostic(
    report.diagnostics,
    1073,
    2,
    1,
    "Couldn't parse this backtick expansion. Fix to allow more checks.",
  )
  expect_diagnostic(
    report.diagnostics,
    1072,
    3,
    1,
    " Fix any mentioned problems and try again.",
  )
}

///|
test "trap handlers preserve nested diagnostic offsets" {
  let report = parse_script_report("trap 'foo\"bar' INT")
  expect_diagnostic(
    report.diagnostics,
    1009,
    1,
    6,
    "The mentioned syntax error was in this simple command.",
  )
  expect_diagnostic(
    report.diagnostics,
    1073,
    1,
    9,
    "Couldn't parse this double quoted string. Fix to allow more checks.",
  )
  expect_diagnostic(
    report.diagnostics,
    1072,
    1,
    13,
    "Expected end of double quoted string. Fix any mentioned problems and try again.",
  )
}

///|
test "shellcheck compatibility diagnostics stay aligned" {
  let brace_report = parse_script_report("{foo;}")
  expect_diagnostic(
    brace_report.diagnostics,
    1054,
    1,
    2,
    "You need a space after the '{'.",
  )

  let if_report = parse_script_report(
    "if false; then true; else if true; then echo lol; fi; fi",
  )
  expect_diagnostic(
    if_report.diagnostics,
    1075,
    1,
    22,
    "Use 'elif' instead of 'else if' (or put 'if' on new line if nesting).",
  )

  let annotation_report = parse_script_report(
    (
      #|# shellcheck cats=dogs disable=SC1234
      #|
    ),
  )
  expect_diagnostic(
    annotation_report.diagnostics,
    1107,
    1,
    14,
    "This directive is unknown. It will be ignored.",
  )

  let nbsp_report = parse_script_report(
    (
      #|#!/bin/bash
      #|echo hello world
    ),
  )
  expect_diagnostic(
    nbsp_report.diagnostics,
    1018,
    2,
    11,
    "This is a unicode non-breaking space. Delete and retype it.",
  )

  let literal_brace_report = parse_script_report("echo ${x}}")
  expect_diagnostic(
    literal_brace_report.diagnostics,
    1083,
    1,
    10,
    "This } is literal. Check expression (missing ;/\\n?) or quote it.",
  )
}

///|
test "phase 1 condition diagnostics use shellcheck codes positions and wording" {
  let command_report = parse_script_report(
    (
      #|[ grep foo ]
      #|
    ),
  )
  expect_diagnostic(
    command_report.diagnostics,
    1073,
    1,
    1,
    "Couldn't parse this test expression. Fix to allow more checks.",
  )
  expect_diagnostic(
    command_report.diagnostics,
    1014,
    1,
    3,
    "Use 'if cmd; then ..' to check exit code, or 'if [[ $(cmd) == .. ]]' to check output.",
  )
  expect_diagnostic(
    command_report.diagnostics,
    1072,
    1,
    8,
    "Expected test to end here (don't wrap commands in []/[[]]). Fix any mentioned problems and try again.",
  )

  let unary_report = parse_script_report(
    (
      #|[ -n ]
      #|
    ),
  )
  expect_diagnostic(
    unary_report.diagnostics,
    1019,
    1,
    6,
    "Expected this to be an argument to the unary condition.",
  )

  let spacing_report = parse_script_report(
    (
      #|[ a = b]
      #|
    ),
  )
  expect_diagnostic(
    spacing_report.diagnostics,
    1020,
    1,
    9,
    "You need a space before the ].",
  )
  expect_diagnostic(
    spacing_report.diagnostics,
    1072,
    1,
    9,
    "Missing space before ]. Fix any mentioned problems and try again.",
  )

  let paren_spacing_report = parse_script_report(
    (
      #|[ foo\) ]
      #|
    ),
  )
  expect_diagnostic(
    paren_spacing_report.diagnostics,
    1021,
    1,
    8,
    "You need a space before the \\)",
  )

  let grouping_report = parse_script_report(
    (
      #|[ [ a = b ] ]
      #|
    ),
  )
  expect_diagnostic(
    grouping_report.diagnostics,
    1026,
    1,
    3,
    "If grouping expressions inside [..], use \\( ..\\).",
  )

  let rhs_report = parse_script_report(
    (
      #|[ foo = ]
      #|
    ),
  )
  expect_diagnostic(
    rhs_report.diagnostics,
    1027,
    1,
    7,
    "Expected another argument for this operator.",
  )

  let single_group_report = parse_script_report(
    (
      #|[ ( a = b ) ]
      #|
    ),
  )
  if count_diagnostics(single_group_report.diagnostics, 1028) != 2 {
    abort("expected two SC1028 diagnostics")
  }
  expect_diagnostic_at(
    single_group_report.diagnostics,
    1028,
    1,
    3,
    "In [..] you have to escape \\( \\) or preferably combine [..] expressions.",
  )
  expect_diagnostic_at(
    single_group_report.diagnostics,
    1028,
    1,
    11,
    "In [..] you have to escape \\( \\) or preferably combine [..] expressions.",
  )

  let double_group_report = parse_script_report(
    (
      #|[[ \( a = b \) ]]
      #|
    ),
  )
  if count_diagnostics(double_group_report.diagnostics, 1029) != 2 {
    abort("expected two SC1029 diagnostics")
  }
  expect_diagnostic_at(
    double_group_report.diagnostics,
    1029,
    1,
    4,
    "In [[..]] you shouldn't escape ( or ).",
  )
  expect_diagnostic_at(
    double_group_report.diagnostics,
    1029,
    1,
    13,
    "In [[..]] you shouldn't escape ( or ).",
  )

  let arithmetic_report = parse_script_report(
    (
      #|[ 1 + 2 ]
      #|
    ),
  )
  expect_diagnostic(
    arithmetic_report.diagnostics,
    1076,
    1,
    5,
    "Trying to do math? Use e.g. [ $((i/2+7)) -ge 18 ].",
  )

  let unicode_dash_report = parse_script_report(
    (
      #|[ foo －eq bar ]
      #|
    ),
  )
  expect_diagnostic(
    unicode_dash_report.diagnostics,
    1100,
    1,
    7,
    "This is a unicode dash. Delete and retype as ASCII minus.",
  )

  let tight_operator_report = parse_script_report(
    (
      #|[ foo= bar ]
      #|
    ),
  )
  expect_diagnostic(
    tight_operator_report.diagnostics,
    1108,
    1,
    3,
    "You need a space before and after the = .",
  )
}

///|
test "phase 1 parser boundary diagnostics use shellcheck codes positions and wording" {
  let heredoc_report = parse_script_report(
    (
      #|cat << (foo)
      #|
    ),
  )
  expect_diagnostic(
    heredoc_report.diagnostics,
    1009,
    1,
    1,
    "The mentioned syntax error was in this simple command.",
  )
  expect_diagnostic(
    heredoc_report.diagnostics,
    1038,
    1,
    5,
    "Shells are space sensitive. Use '< <(cmd)', not '<< (cmd)'.",
  )
  expect_diagnostic(
    heredoc_report.diagnostics,
    1073,
    1,
    5,
    "Couldn't parse this here document. Fix to allow more checks.",
  )
  expect_diagnostic(
    heredoc_report.diagnostics,
    1072,
    1,
    8,
    " Fix any mentioned problems and try again.",
  )

  let function_report = parse_script_report(
    (
      #|foo() echo hi
      #|
    ),
  )
  expect_diagnostic(
    function_report.diagnostics,
    1064,
    1,
    7,
    "Expected a { to open the function definition.",
  )

  expect_diagnostic(
    parse_script_report(
      (
        #|!#/bin/bash
        #|echo hi
        #|
      ),
    ).diagnostics,
    1084,
    1,
    1,
    "Use #!, not !#, for the shebang.",
  )
  expect_diagnostic(
    parse_script_report(
      (
        #|!/bin/bash
        #|echo hi
        #|
      ),
    ).diagnostics,
    1104,
    1,
    1,
    "Use #!, not just !, for the shebang.",
  )
  expect_diagnostic(
    parse_script_report(
      (
        #|#/bin/bash
        #|echo hi
        #|
      ),
    ).diagnostics,
    1113,
    1,
    2,
    "Use #!, not just #, for the shebang.",
  )
  expect_diagnostic(
    parse_script_report(
      (
        #| #!/bin/bash
        #|echo hi
        #|
      ),
    ).diagnostics,
    1114,
    1,
    1,
    "Remove leading spaces before the shebang.",
  )
  expect_diagnostic(
    parse_script_report(
      (
        #|# !/bin/bash
        #|echo hi
        #|
      ),
    ).diagnostics,
    1115,
    1,
    2,
    "Remove spaces between # and ! in the shebang.",
  )
  expect_diagnostic(
    parse_script_report(
      (
        #|# comment
        #|#!/bin/bash
        #|echo hi
        #|
      ),
    ).diagnostics,
    1128,
    2,
    1,
    "The shebang must be on the first line. Delete blanks and move comments.",
  )

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
  let source_depth_report = parse_script_with_options(
    (
      #|source f1.sh
      #|
    ),
    ParseOptions::new(
      false,
      false,
      false,
      true,
      Some("f0.sh"),
      [],
      source_depth_files,
    ),
  )
  expect_diagnostic(
    source_depth_report.diagnostics,
    1092,
    1,
    8,
    "Stopping at 100 'source' frames :O",
  )
}

///|
test "recoverable EOF here-doc diagnostics are not duplicated" {
  let report = parse_script_report(
    (
      #|cat << foo
      #|  foo
      #|
    ),
  )
  if count_diagnostics(report.diagnostics, 1039) != 1 {
    abort("expected a single SC1039 diagnostic")
  }
  expect_diagnostic(
    report.diagnostics,
    1072,
    3,
    1,
    "Here document was not correctly terminated. Fix any mentioned problems and try again.",
  )
}

///|
test "bats recovery keeps shellcheck's leading-space 1072 wording" {
  let report = parse_script_report(
    (
      #|@test foo
      #|
    ),
  )
  match report.script {
    Some(_) => ()
    None => fail("expected recoverable parse")
  }
  expect_diagnostic(
    report.diagnostics,
    1072,
    1,
    7,
    " Fix any mentioned problems and try again.",
  )
}
