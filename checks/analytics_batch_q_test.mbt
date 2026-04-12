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
