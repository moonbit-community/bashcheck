///|
fn assert_command_status(
  label : String,
  source : String,
  expected : String,
) -> Unit {
  let parser = Parser::new(source.view(), ParseOptions::default(), [])
  let actual = try {
    parser.skip_command_gaps()
    ignore(parser.parse_command())
    parser.skip_command_gaps()
    if !parser.eof() {
      status_not_ok()
    } else if parser.diagnostics.length() == 0 {
      status_ok()
    } else {
      status_warning()
    }
  } catch {
    _ => status_not_ok()
  }
  if actual != expected {
    fail_status(label, expected, actual, parser.diagnostics)
  }
}

///|
fn assert_bats_test_status(
  label : String,
  source : String,
  expected : String,
) -> Unit {
  let parser = Parser::new(source.view(), ParseOptions::default(), [])
  let actual = try {
    parser.skip_command_gaps()
    match parser.try_parse_bats_test() {
      Some(_) => {
        parser.skip_command_gaps()
        if !parser.eof() {
          status_not_ok()
        } else if parser.diagnostics.length() == 0 {
          status_ok()
        } else {
          status_warning()
        }
      }
      None => status_not_ok()
    }
  } catch {
    _ => status_not_ok()
  }
  if actual != expected {
    fail_status(label, expected, actual, parser.diagnostics)
  }
}

///|
fn assert_brace_group_direct_status(
  label : String,
  source : String,
  expected : String,
) -> Unit {
  let parser = Parser::new(source.view(), ParseOptions::default(), [])
  let actual = try {
    ignore(parser.parse_brace_group())
    parser.skip_command_gaps()
    if !parser.eof() {
      status_not_ok()
    } else if parser.diagnostics.length() == 0 {
      status_ok()
    } else {
      status_warning()
    }
  } catch {
    _ => status_not_ok()
  }
  if actual != expected {
    fail_status(label, expected, actual, parser.diagnostics)
  }
}

///|
test "shellcheck exact function definition prop names" {
  let ok_cases : Array[(String, String)] = [
    ("prop_readFunctionDefinition", "foo() { command foo --lol \"$@\"; }"),
    ("prop_readFunctionDefinition1", "foo   (){ command foo --lol \"$@\"; }"),
    ("prop_readFunctionDefinition5", ":(){ :|:;}"),
    ("prop_readFunctionDefinition6", "?(){ foo; }"),
    ("prop_readFunctionDefinition7", "..(){ cd ..; }"),
    ("prop_readFunctionDefinition8", "foo() (ls)"),
    ("prop_readFunctionDefinition9", "function foo { true; }"),
    ("prop_readFunctionDefinition10", "function foo () { true; }"),
    ("prop_readFunctionDefinition12", "function []!() { true; }"),
    ("prop_readFunctionDefinition13", "@require(){ true; }"),
    ("prop_readFunctionDefinition14", "foo#bar(){ :; }"),
  ]
  for case_ in ok_cases {
    assert_command_status(case_.0, case_.1, status_ok())
  }

  let warning_cases : Array[(String, String)] = [
    ("prop_readFunctionDefinition4", "foo(a, b) { true; }"),
    (
      "prop_readFunctionDefinition11",
      (
        #|function foo{
        #|true
        #|}
      ),
    ),
  ]
  for case_ in warning_cases {
    assert_command_status(case_.0, case_.1, status_warning())
  }

  assert_command_status(
    "prop_readFunctionDefinition15",
    "#bar(){ :; }",
    status_not_ok(),
  )
}

///|
test "shellcheck exact brace group prop names" {
  assert_brace_group_direct_status(
    "prop_readBraceGroup",
    "{ a; b | c | d; e; }",
    status_ok(),
  )
  assert_brace_group_direct_status(
    "prop_readBraceGroup2",
    "{foo;}",
    status_warning(),
  )
  assert_brace_group_direct_status(
    "prop_readBraceGroup3",
    "{(foo)}",
    status_ok(),
  )
}

///|
test "shellcheck exact bats prop names" {
  let ok_cases : Array[(String, String)] = [
    (
      "prop_readBatsTest1",
      (
        #|@test 'can parse' {
        #|  true
        #|}
      ),
    ),
    (
      "prop_readBatsTest2",
      (
        #|@test random text !(@*$Y&! {
        #|  true
        #|}
      ),
    ),
    (
      "prop_readBatsTest3",
      (
        #|@test foo { bar { baz {
        #|  true
        #|}
      ),
    ),
  ]
  for case_ in ok_cases {
    assert_bats_test_status(case_.0, case_.1, status_ok())
  }

  assert_bats_test_status(
    "prop_readBatsTest4",
    (
      #|@test foo 
      #|{
      #| true
      #|}
    ),
    status_not_ok(),
  )
}
