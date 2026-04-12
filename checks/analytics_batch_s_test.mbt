///|
test "analytics batch s flags recursive cp and ignores non-legacy variants" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|cp -r foo bar
      #|cp -ri foo bar
      #|cp -R foo bar
      #|cp --recursive foo bar
      #|/bin/cp -r foo bar
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2336), 2)
}

///|
test "analytics batch s attaches a shellcheck-style fix" {
  let source =
    #|#!/bin/bash
    #|cp -r foo bar
    #|
  let diagnostics = check_source(source)

  assert_eq(count_code(diagnostics, 2336), 1)
  assert_true(first_code(diagnostics, 2336).severity is CheckSeverity::Warning)
  match first_code(diagnostics, 2336).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|cp -R foo bar
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2336 fix")
  }
}
