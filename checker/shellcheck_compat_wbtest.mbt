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
  sort_ints(codes)
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
fn assert_compat_contains_code(
  label : String,
  source : String,
  expected : Int,
  spec? : CheckSpec = compat_spec(),
) -> Unit {
  let actual = compat_codes(source, spec~)
  if !actual.contains(expected) {
    compat_fail("\{label}: expected code \{expected}, got \{actual}")
  }
}

///|
fn compat_rc_spec(contents : String) -> CheckSpec {
  compat_spec()
  .with_filename(Some("checker/testdata/rc/script.sh"))
  .with_config_files([("checker/testdata/rc/.shellcheckrc", contents)])
}

///|
fn sort_ints(values : Array[Int]) -> Array[Int] {
  let sorted : Array[Int] = []
  for value in values {
    sorted.push(value)
  }
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      if sorted[j] < sorted[i] {
        let current = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = current
      }
      j += 1
    }
    i += 1
  }
  sorted
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
  assert_compat_codes(
    "prop_optionDisablesBadShebang",
    (
      #|#!/usr/bin/python
      #|true
      #|
    ),
    [],
    spec=CheckSpec::default().with_shell_override(
      Some(@semantics.ShellDialect::Sh),
    ),
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

///|
test "shellcheck checker parse and include compatibility props" {
  assert_compat_codes(
    "prop_wontParseBadShell",
    (
      #|#!/usr/bin/python
      #|true $1
      #|
    ),
    [1071],
    spec=CheckSpec::default(),
  )
  assert_compat_codes(
    "prop_canDisableParseErrors",
    (
      #|#shellcheck disable=SC1073,SC1072,SC2148
      #|()
      #|
    ),
    [],
    spec=CheckSpec::default().with_filename(Some("file.sh")),
  )
  assert_compat_codes(
    "prop_shExtensionDoesntMatter",
    (
      #|echo 'hello world'
      #|
    ),
    [2148],
    spec=CheckSpec::default().with_filename(Some("file.sh")),
  )
  assert_compat_codes(
    "prop_canEnableOptionalsWithSpec",
    (
      #|#!/bin/sh
      #|[ "$1" ]
      #|
    ),
    [2244],
    spec=CheckSpec::default()
      .with_filename(Some("file.sh"))
      .with_optional_checks(["avoid-nullary-conditions"]),
  )
  assert_compat_codes(
    "prop_optionIncludes1",
    (
      #|#!/bin/sh
      #| var='a b'
      #| echo $var
      #|
    ),
    [],
    spec=CheckSpec::default().with_include_codes([2080]),
  )
  assert_compat_codes(
    "prop_optionIncludes2",
    (
      #|#!/bin/sh
      #| var='a b'
      #| echo $var
      #|
    ),
    [2086],
    spec=CheckSpec::default().with_include_codes([2086]),
  )
  assert_compat_codes(
    "prop_optionIncludes3",
    (
      #|#!/bin/sh
      #| var='a b'
      #| echo $var
      #|
    ),
    [2086],
    spec=CheckSpec::default(),
  )
  assert_compat_codes(
    "prop_optionIncludes4",
    (
      #|#!/bin/sh
      #| var='a b'
      #| echo $var
      #| echo $bar
      #|
    ),
    [2154],
    spec=CheckSpec::default().with_include_codes([2154]),
  )
}

///|
test "shellcheck checker rc compatibility props" {
  assert_compat_codes(
    "prop_readsRcFile",
    (
      #|#!/bin/sh
      #|echo $1
      #|
    ),
    [],
    spec=compat_rc_spec("disable=2086"),
  )
  assert_compat_codes(
    "prop_canUseNoRC",
    (
      #|#!/bin/sh
      #|echo $1
      #|
    ),
    [2086],
    spec=compat_rc_spec("disable=2086").with_ignore_rc(true),
  )
  assert_compat_codes(
    "prop_NoRCWontLookAtFile",
    (
      #|#!/bin/sh
      #|echo $1
      #|
    ),
    [2086],
    spec=CheckSpec::default()
      .with_filename(Some("checker/testdata/rc/script.sh"))
      .with_ignore_rc(true),
  )
  assert_compat_codes(
    "prop_brokenRcGetsWarning",
    (
      #|#!/bin/sh
      #|echo $1
      #|
    ),
    [1134, 2086],
    spec=compat_rc_spec("rofl"),
  )
  assert_compat_codes(
    "prop_canEnableOptionalsWithRc",
    (
      #|#!/bin/sh
      #|[ "$1" ]
      #|
    ),
    [2244],
    spec=compat_rc_spec("enable=avoid-nullary-conditions"),
  )
  assert_compat_codes(
    "prop_rcCanSuppressEarlyProblems1",
    (
      #|#!/bin/zsh
      #|echo $1
      #|
    ),
    [],
    spec=compat_rc_spec("disable=1071"),
  )
  assert_compat_codes(
    "prop_rcCanSuppressEarlyProblems2",
    (
      #|!/bin/bash
      #|echo 'hello world'
      #|
    ),
    [],
    spec=compat_rc_spec("disable=1104"),
  )
  assert_compat_codes(
    "prop_rcCanSuppressDfa",
    (
      #|#!/bin/sh
      #|exit; foo;
      #|
    ),
    [],
    spec=compat_rc_spec("extended-analysis=false"),
  )
  assert_compat_codes(
    "prop_fileCanSuppressDfa",
    (
      #|#!/bin/sh
      #|# shellcheck extended-analysis=false
      #|exit; foo;
      #|
    ),
    [],
    spec=compat_rc_spec(""),
  )
  assert_compat_codes(
    "prop_fileWinsWhenSuppressingDfa1",
    (
      #|#!/bin/sh
      #|# shellcheck extended-analysis=false
      #|exit; foo;
      #|
    ),
    [],
    spec=compat_rc_spec("extended-analysis=true"),
  )
  assert_compat_codes(
    "prop_fileWinsWhenSuppressingDfa2",
    (
      #|#!/bin/sh
      #|# shellcheck extended-analysis=true
      #|exit; foo;
      #|
    ),
    [2317],
    spec=compat_rc_spec("extended-analysis=false"),
  )
  assert_compat_codes(
    "prop_flagWinsWhenSuppressingDfa1",
    (
      #|#!/bin/sh
      #|# shellcheck extended-analysis=false
      #|exit; foo;
      #|
    ),
    [2317],
    spec=compat_rc_spec("extended-analysis=false").with_extended_analysis(true),
  )
  assert_compat_codes(
    "prop_flagWinsWhenSuppressingDfa2",
    (
      #|#!/bin/sh
      #|# shellcheck extended-analysis=true
      #|exit; foo;
      #|
    ),
    [],
    spec=compat_rc_spec("extended-analysis=true").with_extended_analysis(false),
  )
}

///|
test "shellcheck checker parser edge compatibility props" {
  assert_compat_codes(
    "prop_sourceWithHereDocWorks",
    (
      #|source bar << eof
      #|lol
      #|eof
      #|
    ),
    [],
    spec={
      ..compat_spec(),
      check_sourced: true,
      source_files: [("bar", "true\n")],
    },
  )
  assert_compat_contains_code(
    "prop_sourcePartOfOriginalScript",
    (
      #|#!/bin/sh
      #|source ./saywhat.sh
      #|
    ),
    3046,
  )
  assert_compat_codes(
    "prop_spinBug1413",
    (
      #|fun() {
      #|# shellcheck disable=SC2188
      #|> /dev/null
      #|}
      #|
    ),
    [],
  )
}
