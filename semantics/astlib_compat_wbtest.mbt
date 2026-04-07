///|
fn[A] semantics_compat_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn assert_decoded_dollar_single_quoted(
  label : String,
  text : String,
  expected : String,
) -> Unit {
  let actual = decode_dollar_single_quoted(text)
  if actual != expected {
    semantics_compat_fail("\{label}: expected \{expected}, got \{actual}")
  }
}

///|
test "shellcheck ASTLib dollar-single-quote literal props" {
  assert_decoded_dollar_single_quoted(
    "prop_getLiteralString1", "\\x01", "\u0001",
  )
  assert_decoded_dollar_single_quoted(
    "prop_getLiteralString2", "\\xyz", "\\xyz",
  )
  assert_decoded_dollar_single_quoted(
    "prop_getLiteralString3", "\\x1", "\u0001",
  )
  assert_decoded_dollar_single_quoted(
    "prop_getLiteralString4", "\\x1y", "\u0001y",
  )
  assert_decoded_dollar_single_quoted("prop_getLiteralString5", "\\xy", "\\xy")
  assert_decoded_dollar_single_quoted("prop_getLiteralString6", "\\x", "\\x")
  assert_decoded_dollar_single_quoted(
    "prop_getLiteralString7", "\\1x", "\u0001x",
  )
  assert_decoded_dollar_single_quoted(
    "prop_getLiteralString8", "\\12x", "\u000ax",
  )
  assert_decoded_dollar_single_quoted("prop_getLiteralString9", "\\123x", "Sx")
  assert_decoded_dollar_single_quoted("prop_getLiteralString10", "\\1234", "S4")
  assert_decoded_dollar_single_quoted(
    "prop_getLiteralString11", "\\1", "\u0001",
  )
  assert_decoded_dollar_single_quoted(
    "prop_getLiteralString12", "\\12", "\u000a",
  )
  assert_decoded_dollar_single_quoted("prop_getLiteralString13", "\\123", "S")
}
