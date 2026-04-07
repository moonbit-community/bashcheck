///|
fn[A] parser_compat_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn assert_string_option(
  label : String,
  field : String,
  actual : String?,
  expected : String?,
) -> Unit {
  if actual != expected {
    parser_compat_fail("\{label}: expected \{field}=\{expected}, got \{actual}")
  }
}

///|
fn assert_index_raw_option(
  label : String,
  actual : ArrayIndex?,
  expected : String?,
) -> Unit {
  match (actual, expected) {
    (None, None) => ()
    (Some(index), Some(raw)) =>
      if index.raw != raw {
        parser_compat_fail(
          "\{label}: expected index raw \{raw}, got \{index.raw}",
        )
      }
    _ => parser_compat_fail("\{label}: index presence mismatch")
  }
}

///|
fn assert_operator_option(
  label : String,
  actual : ParameterOperator?,
  expected : ParameterOperator?,
) -> Unit {
  if actual != expected {
    parser_compat_fail("\{label}: operator mismatch")
  }
}

///|
fn assert_parameter_expansion_shape(
  label : String,
  raw : String,
  expected_length_prefix : Bool,
  expected_indirect : Bool,
  expected_name : String?,
  expected_index : String?,
  expected_operator : ParameterOperator?,
) -> Unit {
  let actual = parse_parameter_expansion(raw)
  if actual.length_prefix != expected_length_prefix {
    parser_compat_fail(
      "\{label}: expected length_prefix=\{expected_length_prefix}, got \{actual.length_prefix}",
    )
  }
  if actual.indirect != expected_indirect {
    parser_compat_fail(
      "\{label}: expected indirect=\{expected_indirect}, got \{actual.indirect}",
    )
  }
  assert_string_option(label, "name", actual.name, expected_name)
  assert_index_raw_option(label, actual.index, expected_index)
  assert_operator_option(label, actual.operator, expected_operator)
}

///|
fn assert_parameter_reference_shape(
  label : String,
  raw : String,
  start : Int,
  expected_name : String?,
  expected_index : String?,
  expected_next : Int,
) -> Unit {
  let (name, index, next) = parse_parameter_reference(raw, start)
  assert_string_option(label, "name", name, expected_name)
  assert_index_raw_option(label, index, expected_index)
  if next != expected_next {
    parser_compat_fail("\{label}: expected next=\{expected_next}, got \{next}")
  }
}

///|
fn is_plain_variable_name(text : String) -> Bool {
  let view = text[:]
  if view.length() == 0 || !is_name_start(view[0]) {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if !is_name_part(view[i]) {
      return false
    }
    i += 1
  }
  true
}

///|
test "shellcheck ASTLib executableFromShebang props" {
  let cases : Array[(String, String, String)] = [
    ("prop_executableFromShebang1", "/bin/sh", "sh"),
    ("prop_executableFromShebang2", "/bin/bash", "bash"),
    ("prop_executableFromShebang3", "/usr/bin/env ksh", "ksh"),
    ("prop_executableFromShebang4", "/usr/bin/env -S foo=bar bash -x", "bash"),
    (
      "prop_executableFromShebang5", "/usr/bin/env --split-string=bash -x", "bash",
    ),
    (
      "prop_executableFromShebang6", "/usr/bin/env --split-string=foo=bar bash -x",
      "bash",
    ),
    (
      "prop_executableFromShebang7", "/usr/bin/env --split-string bash -x", "bash",
    ),
    (
      "prop_executableFromShebang8", "/usr/bin/env --split-string foo=bar bash -x",
      "bash",
    ),
    ("prop_executableFromShebang9", "/usr/bin/env foo=bar dash", "dash"),
    ("prop_executableFromShebang10", "/bin/busybox sh", "busybox sh"),
    ("prop_executableFromShebang11", "/bin/busybox ash", "busybox ash"),
  ]
  for case_ in cases {
    let actual = executable_from_shebang(case_.1)
    if actual != case_.2 {
      parser_compat_fail("\{case_.0}: expected \{case_.2}, got \{actual}")
    }
  }
}

///|
test "shellcheck ASTLib variable name props" {
  if !is_plain_variable_name("_fo123") {
    parser_compat_fail("prop_isVariableName1 failed")
  }
  if is_plain_variable_name("4") {
    parser_compat_fail("prop_isVariableName2 failed")
  }
  if is_plain_variable_name("test: ") {
    parser_compat_fail("prop_isVariableName3 failed")
  }
}

///|
test "shellcheck ASTLib braced reference props" {
  assert_parameter_reference_shape(
    "prop_getBracedReference1",
    "foo",
    0,
    Some("foo"),
    None,
    3,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference2",
    "#foo",
    1,
    Some("foo"),
    None,
    4,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference3",
    "#",
    0,
    Some("#"),
    None,
    1,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference4",
    "##",
    1,
    Some("#"),
    None,
    2,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference5",
    "#!",
    1,
    Some("!"),
    None,
    2,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference6",
    "!#",
    1,
    Some("#"),
    None,
    2,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference7",
    "!foo#?",
    1,
    Some("foo"),
    None,
    4,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference8",
    "foo-bar",
    0,
    Some("foo"),
    None,
    3,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference9",
    "foo:-bar",
    0,
    Some("foo"),
    None,
    3,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference10",
    "foo: -1",
    0,
    Some("foo"),
    None,
    3,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference11",
    "!os*",
    1,
    Some("os"),
    None,
    3,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference11b",
    "!os@",
    1,
    Some("os"),
    None,
    3,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference12",
    "!os?bar**",
    1,
    Some("os"),
    None,
    3,
  )
  assert_parameter_reference_shape(
    "prop_getBracedReference13",
    "foo[bar]",
    0,
    Some("foo"),
    Some("bar"),
    8,
  )
}

///|
test "shellcheck ASTLib modifier and index props" {
  assert_parameter_expansion_shape(
    "prop_getBracedModifier1",
    "foo:bar:baz",
    false,
    false,
    Some("foo"),
    None,
    Some(ParameterOperator::Slice("bar", Some("baz"))),
  )
  assert_parameter_expansion_shape(
    "prop_getBracedModifier2",
    "!var:-foo",
    false,
    true,
    Some("var"),
    None,
    Some(ParameterOperator::DefaultValue("foo")),
  )
  assert_parameter_expansion_shape(
    "prop_getBracedModifier3",
    "foo[bar]",
    false,
    false,
    Some("foo"),
    Some("bar"),
    None,
  )
  assert_parameter_expansion_shape(
    "prop_getBracedModifier4",
    "foo[@]@Q",
    false,
    false,
    Some("foo"),
    Some("@"),
    Some(ParameterOperator::Transform("Q")),
  )
  assert_parameter_expansion_shape(
    "prop_getBracedModifier5",
    "@@Q",
    false,
    false,
    Some("@"),
    None,
    Some(ParameterOperator::Transform("Q")),
  )
  assert_parameter_expansion_shape(
    "prop_getIndexReferences1",
    "var[x+y+1]",
    false,
    false,
    Some("var"),
    Some("x+y+1"),
    None,
  )
}

///|
test "shellcheck ASTLib offset reference props" {
  assert_parameter_expansion_shape(
    "prop_getOffsetReferences1",
    "foo:bar",
    false,
    false,
    Some("foo"),
    None,
    Some(ParameterOperator::Slice("bar", None)),
  )
  assert_parameter_expansion_shape(
    "prop_getOffsetReferences2",
    "foo:bar:baz",
    false,
    false,
    Some("foo"),
    None,
    Some(ParameterOperator::Slice("bar", Some("baz"))),
  )
  assert_parameter_expansion_shape(
    "prop_getOffsetReferences3",
    "foo[foo]:bar",
    false,
    false,
    Some("foo"),
    Some("foo"),
    Some(ParameterOperator::Slice("bar", None)),
  )
  assert_parameter_expansion_shape(
    "prop_getOffsetReferences4",
    "foo[foo]:bar:baz",
    false,
    false,
    Some("foo"),
    Some("foo"),
    Some(ParameterOperator::Slice("bar", Some("baz"))),
  )
}
