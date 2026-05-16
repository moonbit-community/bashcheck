///|
test "analytics batch i flags concatenated array expansions" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|echo "foo$@"
      #|echo ${arr[@]}lol
      #|echo $a$@
      #|echo "$@"
      #|echo "${arr[@]}"
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2145), 3)
  assert_true(!has_code(diagnostics, 2295))
}

///|
test "analytics batch i flags unquoted parameter expansion patterns" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|echo ${var#$x}
      #|echo "${var#$x}"
      #|echo "${var#foo$x}"
      #|echo "${var[#$x]}"
      #|echo "${var%"$x"}"
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2295), 3)
  assert_true(!has_code(diagnostics, 2145))
}

///|
test "analytics batch i attaches shellcheck-style nested pattern fix" {
  let source =
    #|#!/bin/bash
    #|echo "${var#$x}"
    #|
  let diagnostics = check_source(source)
  let diagnostic = first_code(diagnostics, 2295)
  assert_true(diagnostic.severity is CheckSeverity::Info)

  match diagnostic.fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 2)
      let open_quote = fix.replacements[0]
      assert_eq(open_quote.start.line, 2)
      assert_eq(open_quote.start.column, 13)
      assert_eq(open_quote.end.line, 2)
      assert_eq(open_quote.end.column, 13)
      assert_eq(open_quote.text, "\"")
      assert_eq(open_quote.precedence, 10)
      assert_true(open_quote.insertion_point == @fixer.InsertionPoint::after())
      let close_quote = fix.replacements[1]
      assert_eq(close_quote.start.line, 2)
      assert_eq(close_quote.start.column, 15)
      assert_eq(close_quote.end.line, 2)
      assert_eq(close_quote.end.column, 15)
      assert_eq(close_quote.text, "\"")
      assert_eq(close_quote.precedence, 10)
      assert_true(
        close_quote.insertion_point == @fixer.InsertionPoint::before(),
      )
      @test.assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|echo "${var#"$x"}"
            #|
          ),
        ),
      )
    }
    None => checks_fail("expected SC2295 fix")
  }
}
