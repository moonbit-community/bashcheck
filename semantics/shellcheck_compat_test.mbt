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
    (
      #|true
      #|
    ),
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
