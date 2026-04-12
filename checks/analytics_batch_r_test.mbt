///|
test "analytics batch r flags legacy unary -a forms" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[ -a file ]
      #|[ ! -a file ]
      #|[[ -a file ]]
      #|[ foo -a bar ]
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2331), 3)
  assert_eq(count_code(diagnostics, 2332), 1)
}

///|
test "analytics batch r ignores binary -a comparisons" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[ foo -a bar ]
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2331))
  assert_true(!has_code(diagnostics, 2332))
}

///|
test "analytics batch r attaches a shellcheck-style fix" {
  let source =
    #|#!/bin/bash
    #|[ -a file ]
    #|
  let diagnostics = check_source(source)

  assert_eq(count_code(diagnostics, 2331), 1)
  match first_code(diagnostics, 2331).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|[ -e file ]
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2331 fix")
  }
}
