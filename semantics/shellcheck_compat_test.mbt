///|
fn determine_shell_compat(
  source : String,
  fallback : @semantics.ShellDialect?,
) -> @semantics.ShellDialect {
  let script = parse_shell_ok(source)
  match fallback {
    Some(shell) =>
      @semantics.determine_shell_with_fallback(script, None, None, Some(shell))
    None => @semantics.determine_shell(script)
  }
}

///|
fn assert_determine_shell_case(
  label : String,
  source : String,
  expected : @semantics.ShellDialect,
) -> Unit {
  let actual = determine_shell_compat(source, None)
  if actual != expected {
    fail("\{label}: expected \{expected}, got \{actual}")
  }
}

///|
fn assert_determine_shell_case_with_fallback(
  label : String,
  source : String,
  expected : @semantics.ShellDialect,
  fallback : @semantics.ShellDialect,
) -> Unit {
  let actual = determine_shell_compat(source, Some(fallback))
  if actual != expected {
    fail("\{label}: expected \{expected}, got \{actual}")
  }
}

///|
fn literal_variables_compat(source : String) -> Array[String] {
  let word = @parser.parse_text_as_word(source)
  let names : Array[String] = []
  for part in word.parts {
    @semantics.walk_word_part(part, fn(current) {
      match current {
        @parser.WordPart::Parameter(name) => names.push(name)
        @parser.WordPart::BracedParameter(expansion) =>
          match expansion.name {
            Some(name) => names.push(name)
            None => ()
          }
        _ => ()
      }
    })
  }
  names
}

///|
test "shellcheck analyzerlib determineShell props" {
  assert_determine_shell_case(
    "prop_determineShell0",
    (
      #|#!/bin/sh
      #|
    ),
    @semantics.ShellDialect::Sh,
  )
  assert_determine_shell_case(
    "prop_determineShell1",
    (
      #|#!/usr/bin/env ksh
      #|
    ),
    @semantics.ShellDialect::Ksh,
  )
  assert_determine_shell_case(
    "prop_determineShell2",
    "",
    @semantics.ShellDialect::Bash,
  )
  assert_determine_shell_case(
    "prop_determineShell3",
    (
      #|#!/bin/sh -e
      #|
    ),
    @semantics.ShellDialect::Sh,
  )
  assert_determine_shell_case(
    "prop_determineShell4",
    (
      #|#!/bin/ksh
      #|#shellcheck shell=sh
      #|foo
      #|
    ),
    @semantics.ShellDialect::Sh,
  )
  assert_determine_shell_case(
    "prop_determineShell5",
    (
      #|#shellcheck shell=sh
      #|foo
      #|
    ),
    @semantics.ShellDialect::Sh,
  )
  assert_determine_shell_case(
    "prop_determineShell6",
    (
      #|#! /bin/sh
      #|
    ),
    @semantics.ShellDialect::Sh,
  )
  assert_determine_shell_case(
    "prop_determineShell7",
    (
      #|#! /bin/ash
      #|
    ),
    @semantics.ShellDialect::Dash,
  )
  assert_determine_shell_case_with_fallback(
    "prop_determineShell8",
    (
      #|#!/bin/sh
      #|
    ),
    @semantics.ShellDialect::Sh,
    @semantics.ShellDialect::Ksh,
  )
  assert_determine_shell_case(
    "prop_determineShell9",
    (
      #|#!/bin/env -S dash -x
      #|
    ),
    @semantics.ShellDialect::Dash,
  )
  assert_determine_shell_case(
    "prop_determineShell10",
    (
      #|#!/bin/env --split-string= dash -x
      #|
    ),
    @semantics.ShellDialect::Dash,
  )
  assert_determine_shell_case(
    "prop_determineShell11",
    (
      #|#!/bin/busybox sh
      #|
    ),
    @semantics.ShellDialect::BusyboxSh,
  )
  assert_determine_shell_case(
    "prop_determineShell12",
    (
      #|#!/bin/busybox ash
      #|
    ),
    @semantics.ShellDialect::BusyboxSh,
  )
}

///|
/// Adapted upstream coverage: bashcheck does not expose ShellCheck's
/// getVariablesFromLiteral helper, so assert the equivalent variable-name
/// recovery from the parsed literal word instead.
test "shellcheck analyzerlib literal variable props" {
  assert_eq(literal_variables_compat("$foo${bar//a/b}$BAZ"), [
    "foo", "bar", "BAZ",
  ])
}
