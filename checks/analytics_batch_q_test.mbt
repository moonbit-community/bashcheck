///|
test "analytics batch q flags redirected nowhere and pipe-to-nowhere cases" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|> file
      #|> file | grep foo
      #|grep foo | > bar
      #|foo | echo bar
      #|foo | basename < file.txt
      #|ls > foo > bar
      #|ls > foo 2> bar > baz
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2188), 1)
  assert_eq(count_code(diagnostics, 2189), 2)
  assert_eq(count_code(diagnostics, 2216), 2)
  assert_eq(count_code(diagnostics, 2217), 1)
  assert_eq(count_code(diagnostics, 2259), 1)
  assert_eq(count_code(diagnostics, 2260), 1)
  assert_eq(count_code(diagnostics, 2261), 4)
}

///|
test "analytics batch q ignores nested command substitutions" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|foo=$(< file)
      #|echo $(cat)
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2188))
  assert_true(!has_code(diagnostics, 2216))
}

///|
test "analytics batch q keeps nested pipelines inside command substitutions active" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|echo $(foo | echo bar)
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2216))
}

///|
test "analytics batch q does not misclassify here-doc command substitutions as pipe consumers" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|foo | cat <<EOF
      #|$(cat)
      #|EOF
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2259))
  assert_true(!has_code(diagnostics, 2216))
}

///|
test "analytics batch q flags quoted here-docs that override piped stdin" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|echo World | cat << 'EOF'
      #|hello $(cat)
      #|EOF
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2259))
}

///|
test "analytics batch q keeps fd-dup and command exceptions quiet" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|find . -print0 | du --files0-from=/dev/stdin
      #|find . | du --exclude-from=/dev/fd/0
      #|yes | cp -Ri foo/* bar
      #|yes | rm --interactive *
      #|ls 1>&3 3>&1 3>&-
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2216))
  assert_true(!has_code(diagnostics, 2217))
  assert_true(!has_code(diagnostics, 2259))
  assert_true(!has_code(diagnostics, 2260))
  assert_true(!has_code(diagnostics, 2261))
}

///|
test "analytics batch q flags misplaced stderr redirect ordering without expansion false positives" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|test 2>&1 > cow
      #|foo | bar 2>&1 > /dev/null
      #|test 2>&1 > file | grep stderr
      #|errors=$(test 2>&1 > file)
      #|read < <(test 2>&1 > file)
      #|{ test > file; } 2>&1
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2069), 2)
}

///|
test "analytics batch q flags repeated appends and grep output comparisons" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|foo >> file; bar >> file; baz >> file;
      #|[[ $(foo | grep bar) ]]
      #|[ -z "$(foo | grep bar)" ]
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2129), 1)
  assert_eq(count_code(diagnostics, 2143), 2)
}

///|
test "analytics batch q flags bare bangs under set -e and preserves shellcheck-style fixes" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|set -e
      #|while true; do ! true; done
      #|{ ! true; }
      #|! foo | bar
      #|! true
      #|rest
      #|
    ),
  )
  let fix_source =
    #|#!/bin/bash
    #|set -e
    #|! true
    #|rest
    #|
  let fix_diagnostic = first_code(check_source(fix_source), 2251)

  assert_eq(count_code(diagnostics, 2251), 4)
  match fix_diagnostic.fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, fix_source),
        Some(
          (
            #|#!/bin/bash
            #|set -e
            #| true && exit 1
            #|rest
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2251 fix")
  }
}

///|
test "analytics batch q avoids useless-bang false positives in conditions and final positions" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|set -e
      #|if ! true; then :; fi
      #|while ! true; do :; done
      #|( ! true )
      #|! foo && bar
      #|f() { ! true; }
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2251))
}

///|
test "analytics batch q flags arithmetic side effects in command redirections" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|printf %s x > $((i++))
      #|printf %s x 2> $((i+=1))
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2257), 2)
}

///|
test "analytics batch q keeps pure arithmetic redirects and dash quiet" {
  let bash_diagnostics = check_source(
    (
      #|#!/bin/bash
      #|printf %s x > $((i + 1))
      #|
    ),
  )
  let dash_diagnostics = check_source(
    (
      #|#!/bin/dash
      #|printf %s x > $((i++))
      #|
    ),
  )

  assert_true(!has_code(bash_diagnostics, 2257))
  assert_true(!has_code(dash_diagnostics, 2257))
}

///|
test "analytics batch q flags mistaken background and pipe operators on test commands" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2078
      #|a=$1
      #|[ "$a" ] & [ "$a" ]
      #|test -e foo & [ "$a" ]
      #|[ "$a" ] | [ "$a" ]
      #|
    ),
  )
  let and_fix_source =
    #|#!/bin/bash
    #|# shellcheck disable=SC2078
    #|a=$1
    #|[ "$a" ] & [ "$a" ]
    #|
  let or_fix_source =
    #|#!/bin/bash
    #|# shellcheck disable=SC2078
    #|a=$1
    #|[ "$a" ] | [ "$a" ]
    #|

  assert_eq(count_code(diagnostics, 2265), 2)
  assert_eq(count_code(diagnostics, 2266), 1)
  match first_code(check_source(and_fix_source), 2265).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, and_fix_source),
        Some(
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2078
            #|a=$1
            #|[ "$a" ] && [ "$a" ]
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2265 fix")
  }
  match first_code(check_source(or_fix_source), 2266).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, or_fix_source),
        Some(
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2078
            #|a=$1
            #|[ "$a" ] || [ "$a" ]
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2266 fix")
  }
}

///|
test "analytics batch q keeps logical and-or test operators quiet" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|a=$1
      #|[ "$a" ] && [ "$a" ]
      #|test -e foo && [ "$a" ]
      #|[ "$a" ] || [ "$a" ]
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2265))
  assert_true(!has_code(diagnostics, 2266))
}

///|
test "analytics batch q avoids append and grep-q false positives" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|foo >> file; bar >> other; baz >> file;
      #|[ -z "$(grep bar | cmd)" ]
      #|rm $(ls | grep file)
      #|[[ -n "$(pgrep foo)" ]]
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2129))
  assert_true(!has_code(diagnostics, 2143))
}
