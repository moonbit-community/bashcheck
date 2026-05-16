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
    Some(fix) => {
      assert_eq(fix.replacements.length(), 2)
      let open_wrapper = fix.replacements[0]
      assert_eq(open_wrapper.start.line, 3)
      assert_eq(open_wrapper.start.column, 3)
      assert_eq(open_wrapper.end.line, 3)
      assert_eq(open_wrapper.end.column, 6)
      assert_eq(open_wrapper.text, "")
      assert_eq(open_wrapper.precedence, 9)
      assert_true(
        open_wrapper.insertion_point == @fixer.InsertionPoint::after(),
      )
      let close_wrapper = fix.replacements[1]
      assert_eq(close_wrapper.start.line, 3)
      assert_eq(close_wrapper.start.column, 9)
      assert_eq(close_wrapper.end.line, 3)
      assert_eq(close_wrapper.end.column, 11)
      assert_eq(close_wrapper.text, "")
      assert_eq(close_wrapper.precedence, 9)
      assert_true(
        close_wrapper.insertion_point == @fixer.InsertionPoint::before(),
      )
      @test.assert_eq(
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
    }
    None => checks_fail("expected SC2321 fix")
  }

  match first_code(diagnostics, 2322).fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 2)
      let open_wrapper = fix.replacements[0]
      assert_eq(open_wrapper.start.line, 4)
      assert_eq(open_wrapper.start.column, 11)
      assert_eq(open_wrapper.end.line, 4)
      assert_eq(open_wrapper.end.column, 12)
      assert_eq(open_wrapper.text, "")
      assert_eq(open_wrapper.precedence, 11)
      assert_true(
        open_wrapper.insertion_point == @fixer.InsertionPoint::after(),
      )
      let close_wrapper = fix.replacements[1]
      assert_eq(close_wrapper.start.line, 4)
      assert_eq(close_wrapper.start.column, 15)
      assert_eq(close_wrapper.end.line, 4)
      assert_eq(close_wrapper.end.column, 16)
      assert_eq(close_wrapper.text, "")
      assert_eq(close_wrapper.precedence, 11)
      assert_true(
        close_wrapper.insertion_point == @fixer.InsertionPoint::before(),
      )
      @test.assert_eq(
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
    }
    None => checks_fail("expected SC2322 fix")
  }

  match first_code(diagnostics, 2323).fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 2)
      let open_wrapper = fix.replacements[0]
      assert_eq(open_wrapper.start.line, 4)
      assert_eq(open_wrapper.start.column, 10)
      assert_eq(open_wrapper.end.line, 4)
      assert_eq(open_wrapper.end.column, 11)
      assert_eq(open_wrapper.text, "")
      assert_eq(open_wrapper.precedence, 9)
      assert_true(
        open_wrapper.insertion_point == @fixer.InsertionPoint::after(),
      )
      let close_wrapper = fix.replacements[1]
      assert_eq(close_wrapper.start.line, 4)
      assert_eq(close_wrapper.start.column, 16)
      assert_eq(close_wrapper.end.line, 4)
      assert_eq(close_wrapper.end.column, 17)
      assert_eq(close_wrapper.text, "")
      assert_eq(close_wrapper.precedence, 9)
      assert_true(
        close_wrapper.insertion_point == @fixer.InsertionPoint::before(),
      )
      @test.assert_eq(
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
    }
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
