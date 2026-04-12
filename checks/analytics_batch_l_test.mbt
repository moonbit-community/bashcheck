///|
test "analytics batch l flags arithmetic-context parentheses and indexes" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|a[$((1+1))]=n
      #|echo $(( ((1+1)) ))
      #|echo $(( (x) ))
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2321), 1)
  assert_eq(count_code(diagnostics, 2322), 1)
  assert_eq(count_code(diagnostics, 2323), 2)

  match first_code(diagnostics, 2321).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(
          fix,
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2034
            #|a[$((1+1))]=n
            #|echo $(( ((1+1)) ))
            #|echo $(( (x) ))
            #|
          ),
        ),
        Some(
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2034
            #|a[1+1]=n
            #|echo $(( ((1+1)) ))
            #|echo $(( (x) ))
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2321 fix")
  }

  match first_code(diagnostics, 2323).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(
          fix,
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2034
            #|a[$((1+1))]=n
            #|echo $(( ((1+1)) ))
            #|echo $(( (x) ))
            #|
          ),
        ),
        Some(
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2034
            #|a[$((1+1))]=n
            #|echo $(( (1+1) ))
            #|echo $(( (x) ))
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2323 fix")
  }
}

///|
test "analytics batch l flags plus equals with numeric append values" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|n=4
      #|x+=1
      #|y+=n
      #|declare -i z=0
      #|z+=1
      #|w+='1'
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2324), 2)
}

///|
test "analytics batch l avoids associative-index and non-leading-parens false positives" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|declare -A assoc
      #|assoc[$((1+1))]=val
      #|plain[(1+1)+1]=1
      #|(( (1*1)+1 ))
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2321))
  assert_true(!has_code(diagnostics, 2322))
  assert_true(!has_code(diagnostics, 2323))
}
