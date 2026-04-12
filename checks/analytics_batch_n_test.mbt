///|
test "analytics batch n flags bats negations with last and non-last distinctions" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|@test "negation" { ! true; ! [[ -e test ]]; ! [ -e test ]; false; }
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2314), 1)
  assert_eq(count_code(diagnostics, 2315), 2)
  assert_true(first_code(diagnostics, 2314).severity is CheckSeverity::Error)
  assert_true(first_code(diagnostics, 2315).severity is CheckSeverity::Error)
}

///|
test "analytics batch n flags bats last-command negations and shellcheck-style run fix" {
  let source =
    #|#!/bin/bash
    #|@test "last ordinary" { ! true; }
    #|@test "last condition" { ! [[ -e test ]]; }
    #|
  let diagnostics = check_source(source)

  assert_eq(count_code(diagnostics, 2314), 1)
  assert_eq(count_code(diagnostics, 2315), 1)
  assert_true(first_code(diagnostics, 2314).severity is CheckSeverity::Style)
  assert_true(first_code(diagnostics, 2315).severity is CheckSeverity::Style)
  match first_code(diagnostics, 2314).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|@test "last ordinary" { run ! true; }
            #|@test "last condition" { ! [[ -e test ]]; }
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2314 fix")
  }
  assert_true(first_code(diagnostics, 2315).fix is None)
}

///|
test "analytics batch n ignores wrapped run negation and or-false forms" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|@test "run ok" { run ! true; }
      #|@test "or false ok" { ! [[ -e test ]] || false; }
      #|@test "or false bracket ok" { ! [ -e test ] || false; }
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2314), 0)
  assert_eq(count_code(diagnostics, 2315), 0)
}

///|
test "analytics batch n ignores bats negation followed by or-false" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|@test "allowed" { ! [[ -e test ]] || false; }
      #|@test "allowed single" { ! [ -e test ] || false; }
      #|@test "run form" { run ! true; }
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2314), 0)
  assert_eq(count_code(diagnostics, 2315), 0)
}
