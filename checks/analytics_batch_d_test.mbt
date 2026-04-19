///|
test "analytics batch d flags external command dispatch and unpassed function arguments" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|foo() { echo $1 $#; }
      #|alias bar='printf %s\n'
      #|sudo foo
      #|ssh host bar
      #|foo
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2032), 2)
  assert_eq(count_code(diagnostics, 2033), 2)
  assert_true(has_code(diagnostics, 2119))
  assert_true(has_code(diagnostics, 2120))
}

///|
test "analytics batch d flags non-standard function declarations" {
  let sh_diagnostics = check_source(
    (
      #|#!/bin/sh
      #|function foo() { true; }
      #|function bar { true; }
      #|
    ),
  )

  let ksh_diagnostics = check_source(
    (
      #|#!/bin/ksh
      #|function foo() { true; }
      #|
    ),
  )

  assert_true(has_code(sh_diagnostics, 2112))
  assert_true(has_code(sh_diagnostics, 2113))
  assert_true(has_code(ksh_diagnostics, 2111))
}

///|
test "analytics batch d flags ksh stderr pipes but keeps bash quiet" {
  let ksh_diagnostics = check_source(
    (
      #|#!/bin/ksh
      #|foo|&bar
      #|
    ),
  )

  let bash_diagnostics = check_source(
    (
      #|#!/bin/bash
      #|foo|&bar
      #|
    ),
  )

  assert_true(has_code(ksh_diagnostics, 2118))
  assert_true(!has_code(bash_diagnostics, 2118))
}

///|
test "analytics batch d flags shell-specific syntax without explicit shell support" {
  let sh_diagnostics = check_source(
    (
      #|#!/bin/sh
      #|x=foo
      #|case "$x" in bar) baz ;& esac
      #|
    ),
  )
  let ksh_diagnostics = check_source(
    (
      #|#!/bin/ksh
      #|x=foo
      #|case "$x" in bar) baz ;;& esac
      #|
    ),
  )
  let dash_diagnostics = check_source(
    (
      #|#!/bin/dash
      #|: "${ ls; }"
      #|
    ),
  )

  assert_eq(count_code(sh_diagnostics, 2127), 1)
  assert_eq(count_code(ksh_diagnostics, 2127), 1)
  assert_eq(count_code(dash_diagnostics, 2127), 1)
}

///|
test "analytics batch d keeps supported case separators and brace command expansions quiet" {
  let bash_diagnostics = check_source(
    (
      #|#!/bin/bash
      #|x=foo
      #|case "$x" in bar) baz ;;& esac
      #|: "${ ls; }"
      #|
    ),
  )
  let ksh_diagnostics = check_source(
    (
      #|#!/bin/ksh
      #|x=foo
      #|case "$x" in bar) baz ;& esac
      #|: "${ ls; }"
      #|
    ),
  )

  assert_true(!has_code(bash_diagnostics, 2127))
  assert_true(!has_code(ksh_diagnostics, 2127))
}

///|
test "analytics batch d flags shebang parameter misuse and invalid loop keywords" {
  let diagnostics = check_source(
    (
      #|#!/usr/bin/env bash -x
      #|continue 2
      #|foo() { break; }
      #|if true; then continue; fi
      #|for f in a; do ( break; ); done
      #|while true; do true | { break; }; done
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2096))
  assert_eq(count_code(diagnostics, 2104), 1)
  assert_eq(count_code(diagnostics, 2105), 2)
  assert_eq(count_code(diagnostics, 2106), 2)
}

///|
test "analytics batch d keeps env split-string and loop-local keywords quiet" {
  let diagnostics = check_source(
    (
      #|#!/usr/bin/env -S bash -x
      #|while true; do break; done
      #|for f in a; do continue; done
      #|
    ),
  )

  let ksh_diagnostics = run_checks_with_shell(
    parse_checks_ok(
      (
        #|while true; do true | { break; }; done
        #|
      ),
    ),
    @semantics.ShellDialect::Ksh,
    false,
    [],
  )

  assert_true(!has_code(diagnostics, 2096))
  assert_true(!has_code(diagnostics, 2104))
  assert_true(!has_code(diagnostics, 2105))
  assert_true(!has_code(diagnostics, 2106))
  assert_true(!has_code(ksh_diagnostics, 2106))
}

///|
test "analytics batch d avoids external dispatch and unpassed-function false positives" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|function foo() { true; }
      #|function bar { true; }
      #|foo() { echo $1; }
      #|alias bar='printf %s\n'
      #|echo foo
      #|foo hi
      #|foo "$@"
      #|ssh host echo foo
      #|find . -type f
      #|bar
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2111))
  assert_true(!has_code(diagnostics, 2112))
  assert_true(!has_code(diagnostics, 2113))
  assert_true(!has_code(diagnostics, 2032))
  assert_true(!has_code(diagnostics, 2033))
  assert_true(!has_code(diagnostics, 2119))
  assert_true(!has_code(diagnostics, 2120))
}

///|
test "analytics batch d flags cd-back sequences that should use subshells" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2164
      #|for f in *; do cd "$f"; git pull; cd ..; done
      #|cd "$tmp"
      #|foo
      #|cd -
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2103), 2)
}

///|
test "analytics batch d avoids cd-back false positives behind guards and set -e" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2164
      #|set -e
      #|for f in *; do cd "$f"; git pull; cd ..; done
      #|for f in *; do cd "$f" || continue; git pull; cd ..; done
      #|while [[ $PWD != / ]]; do cd ..; done
      #|cd ..
      #|foo
      #|cd ..
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2103))
}

///|
test "analytics batch d flags unchecked directory changes and loop variable reuse" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|if true; then cd foo; fi
      #|pushd work
      #|for i in a; do
      #|  for i in b; do
      #|    :
      #|  done
      #|done
      #|for ((j = 0; j < 1; j++)); do
      #|  for ((j = 0; j < 1; j++)); do
      #|    :
      #|  done
      #|done
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2164), 2)
  assert_eq(count_code(diagnostics, 2165), 2)
  assert_eq(count_code(diagnostics, 2167), 2)
}

///|
test "analytics batch d avoids guarded directory and distinct loop variable false positives" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|set -e
      #|cd foo
      #|if cd bar; then :; fi
      #|pushd -n work
      #|cd ../..
      #|for i in a; do
      #|  for j in b; do
      #|    :
      #|  done
      #|done
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2164))
  assert_true(!has_code(diagnostics, 2165))
  assert_true(!has_code(diagnostics, 2167))
}

///|
test "analytics batch d flags aliases reused in one parsing unit and array value index mistakes" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|{
      #|  alias x=y
      #|  x
      #|}
      #|arr=(a b)
      #|for i in ${arr[@]}; do
      #|  echo ${arr[i]}
      #|done
      #|a[0]=foo
      #|echo "$a"
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2262))
  assert_true(has_code(diagnostics, 2263))
  assert_true(has_code(diagnostics, 2302))
  assert_true(has_code(diagnostics, 2303))
  assert_true(has_code(diagnostics, 2128))
}

///|
test "analytics batch d avoids alias and array-index false positives across safe forms" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|alias x=y
      #|x
      #|arr=(a b)
      #|for i in ${arr[@]}; do
      #|  i=42
      #|  echo ${arr2[i]}
      #|done
      #|echo "${arr[0]}"
      #|echo "${arr[@]}"
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2262))
  assert_true(!has_code(diagnostics, 2263))
  assert_true(!has_code(diagnostics, 2302))
  assert_true(!has_code(diagnostics, 2303))
  assert_true(!has_code(diagnostics, 2128))
}
