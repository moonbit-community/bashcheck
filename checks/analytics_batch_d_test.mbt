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
test "analytics batch d avoids external dispatch and unpassed-function false positives" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
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

  assert_true(!has_code(diagnostics, 2032))
  assert_true(!has_code(diagnostics, 2033))
  assert_true(!has_code(diagnostics, 2119))
  assert_true(!has_code(diagnostics, 2120))
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
