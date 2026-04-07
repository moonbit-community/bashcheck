///|
fn compat_spec() -> CheckSpec {
  CheckSpec::default().with_exclude_codes([2148])
}

///|
fn[A] compat_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn compat_codes(
  source : String,
  spec? : CheckSpec = compat_spec(),
) -> Array[Int] {
  let result = check_script(source, spec~)
  let codes : Array[Int] = []
  for diagnostic in result.diagnostics {
    match diagnostic.code {
      Some(code) => codes.push(code)
      None => ()
    }
  }
  codes
}

///|
fn assert_compat_codes(
  label : String,
  source : String,
  expected : Array[Int],
  spec? : CheckSpec = compat_spec(),
) -> Unit {
  let actual = compat_codes(source, spec~)
  if actual != expected {
    compat_fail("\{label}: expected \{expected}, got \{actual}")
  }
}

///|
test "shellcheck checker basic compatibility props" {
  assert_compat_codes("prop_findsParseIssue", "echo \"$12\"", [1037])
  assert_compat_codes(
    "prop_commentDisablesParseIssue1",
    (
      #|#shellcheck disable=SC1037
      #|echo "$12"
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_commentDisablesParseIssue2",
    (
      #|#shellcheck disable=SC1037
      #|#lol
      #|echo "$12"
      #|
    ),
    [],
  )
  assert_compat_codes("prop_findsAnalysisIssue", "echo $1", [2086])
  assert_compat_codes(
    "prop_commentDisablesAnalysisIssue1",
    (
      #|#shellcheck disable=SC2086
      #|echo $1
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_commentDisablesAnalysisIssue2",
    (
      #|#shellcheck disable=SC2086
      #|#lol
      #|echo $1
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_optionDisablesIssue1",
    "echo $1",
    [],
    spec=CheckSpec::default().with_exclude_codes([2148, 2086]),
  )
  assert_compat_codes(
    "prop_optionDisablesIssue2",
    "echo \"$10\"",
    [],
    spec=CheckSpec::default().with_exclude_codes([2148, 1037]),
  )
  assert_compat_codes(
    "prop_annotationDisablesBadShebang",
    (
      #|#!/usr/bin/python
      #|# shellcheck shell=sh
      #|true
      #|
    ),
    [],
    spec=CheckSpec::default(),
  )
  assert_compat_codes("prop_canParseDevNull", "source /dev/null", [])
}

///|
test "shellcheck checker filename compatibility props" {
  assert_compat_codes(
    "prop_deducesTypeFromExtension",
    "(( 3.14 ))",
    [],
    spec=compat_spec().with_filename(Some("file.ksh")),
  )
  assert_compat_codes(
    "prop_deducesTypeFromExtension2",
    "(( 3.14 ))",
    [2079],
    spec=compat_spec().with_filename(Some("file.bash")),
  )
  assert_compat_codes(
    "prop_deducesTypeFromEnvrcExtension",
    "(( 3.14 ))",
    [2079],
    spec=compat_spec().with_filename(Some(".envrc")),
  )
  assert_compat_codes(
    "prop_canDisableShebangWarning",
    (
      #|#shellcheck disable=SC2148
      #|foo
      #|
    ),
    [],
    spec=CheckSpec::default().with_filename(Some("file.sh")),
  )
}
