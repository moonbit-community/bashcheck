///|
fn find_diagnostic(
  diagnostics : Array[Diagnostic],
  code : Int32,
) -> Diagnostic? {
  for diagnostic in diagnostics {
    if diagnostic.code == Some(code) {
      return Some(diagnostic)
    }
  }
  None
}

///|
fn count_diagnostics(diagnostics : Array[Diagnostic], code : Int32) -> Int32 {
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
  code : Int32,
  line : Int32,
  column : Int32,
  message : String,
) -> Unit {
  if find_diagnostic(diagnostics, code) is Some(diagnostic) {
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
  } else {
    abort("missing diagnostic \{code}")
  }
}

///|
test "condition trailing tokens include shellcheck parse-stop diagnostic" {
  let report = parse_script_report("[[ x ]] foo")
  if report.script is Some(_) {
    ()
  } else {
    fail("expected recoverable parse")
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
  if report.script is Some(_) {
    ()
  } else {
    fail("expected recoverable parse")
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
  if report.script is Some(_) {
    ()
  } else {
    fail("expected recoverable parse")
  }
  expect_diagnostic(
    report.diagnostics,
    1072,
    1,
    7,
    " Fix any mentioned problems and try again.",
  )
}
