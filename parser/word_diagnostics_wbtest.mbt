///|
fn diagnostics_have_code(diagnostics : Array[Diagnostic], code : Int) -> Bool {
  for diagnostic in diagnostics {
    if diagnostic.code == Some(code) {
      return true
    }
  }
  false
}

///|
test "parse_word emits shellcheck invalid parenthesis diagnostic" {
  let parser = Parser::new("(".view(), ParseOptions::default(), [])
  let mut failed = false
  ignore(parser.parse_word()) catch {
    _ => failed = true
  }
  assert_true(failed)
  assert_true(diagnostics_have_code(parser.diagnostics, 1036))
}

///|
test "parse_word emits shellcheck reserved-word spacing diagnostic" {
  let parser = Parser::new("then".view(), ParseOptions::default(), [])
  let word = parser.parse_word()
  assert_eq(word.source, "then")
  assert_true(diagnostics_have_code(parser.diagnostics, 1010))
}
