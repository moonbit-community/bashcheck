///|
test "analytics batch o flags blatant recursion and offers command fixups" {
  let source =
    #|#!/bin/bash
    #|f() { f; }
    #|cd() { cd "$1" || exit; }
    #|
  let diagnostics = check_source(source)

  assert_eq(count_code(diagnostics, 2264), 2)
  match first_code(diagnostics, 2264).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(
          fix,
          (
            #|#!/bin/bash
            #|f() { f; }
            #|cd() { cd "$1" || exit; }
            #|,
          ),
        ),
        Some(
          (
            #|#!/bin/bash
            #|f() { command f; }
            #|cd() { cd "$1" || exit; }
            #|,
          ),
        ),
      )
    None => checks_fail("expected SC2264 fix")
  }
}

///|
test "analytics batch o ignores command wrappers and later self references" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|f() { command f; }
      #|cd() { builtin cd $1; }
      #|cd() { [ -z "$1" ] || cd "$1"; }
      #|cd() { something; cd $1; }
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2264))
}
