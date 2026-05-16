///|
test "analytics checks flag backticks and unquoted command substitutions" {
  let diagnostics = check_source(
    (
      #|echo `foo`
      #|rm $(ls)
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2006))
  assert_true(has_code(diagnostics, 2046))
}

///|
test "analytics checks attach fixes for backticks" {
  let source =
    #|echo `printf '%s' "$x"`/`date +%F`
    #|
  let diagnostic = first_code(check_source(source), 2006)

  match diagnostic.fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 4)
      let first_open = fix.replacements[0]
      assert_eq(first_open.start.line, 1)
      assert_eq(first_open.start.column, 6)
      assert_eq(first_open.end.line, 1)
      assert_eq(first_open.end.column, 7)
      assert_eq(first_open.text, "$(")
      assert_eq(first_open.precedence, 5)
      assert_true(first_open.insertion_point == @fixer.InsertionPoint::after())
      let first_close = fix.replacements[1]
      assert_eq(first_close.start.line, 1)
      assert_eq(first_close.start.column, 23)
      assert_eq(first_close.end.line, 1)
      assert_eq(first_close.end.column, 24)
      assert_eq(first_close.text, ")")
      assert_eq(first_close.precedence, 5)
      assert_true(
        first_close.insertion_point == @fixer.InsertionPoint::before(),
      )
      let second_open = fix.replacements[2]
      assert_eq(second_open.start.line, 1)
      assert_eq(second_open.start.column, 25)
      assert_eq(second_open.end.line, 1)
      assert_eq(second_open.end.column, 26)
      assert_eq(second_open.text, "$(")
      assert_eq(second_open.precedence, 5)
      assert_true(second_open.insertion_point == @fixer.InsertionPoint::after())
      let second_close = fix.replacements[3]
      assert_eq(second_close.start.line, 1)
      assert_eq(second_close.start.column, 34)
      assert_eq(second_close.end.line, 1)
      assert_eq(second_close.end.column, 35)
      assert_eq(second_close.text, ")")
      assert_eq(second_close.precedence, 5)
      assert_true(
        second_close.insertion_point == @fixer.InsertionPoint::before(),
      )
      @test.assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|echo $(printf '%s' "$x")/$(date +%F)
            #|
          ),
        ),
      )
    }
    None => checks_fail("expected SC2006 fix")
  }
}

///|
test "analytics checks preserve multiline backtick replacement positions" {
  let source =
    #|echo `printf '%s'
    #|date`
    #|
  let diagnostic = first_code(check_source(source), 2006)

  match diagnostic.fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 2)
      let open = fix.replacements[0]
      assert_eq(open.start.line, 1)
      assert_eq(open.start.column, 6)
      assert_eq(open.end.line, 1)
      assert_eq(open.end.column, 7)
      let close = fix.replacements[1]
      assert_eq(close.start.line, 2)
      assert_eq(close.start.column, 5)
      assert_eq(close.end.line, 2)
      assert_eq(close.end.column, 6)
      @test.assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|echo $(printf '%s'
            #|date)
            #|
          ),
        ),
      )
    }
    None => checks_fail("expected multiline SC2006 fix")
  }
}

///|
test "analytics checks flag fragile for-in forms and ls/find substitutions" {
  let diagnostics = check_source(
    (
      #|for f in "$(ls)"; do :; done
      #|for g in ls; do :; done
      #|for h in $(ls *.mp3); do :; done
      #|for i in $(find / -name '*.mp3'); do :; done
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2066))
  assert_true(has_code(diagnostics, 2043))
  assert_true(has_code(diagnostics, 2045))
  assert_true(has_code(diagnostics, 2044))
}

///|
test "analytics checks flag unquoted star and array expansions" {
  let diagnostics = check_source(
    (
      #|printf '%s\n' $@ ${arr[@]} ${*} ${arr[*]}
      #|
    ),
  )

  assert_true(count_code(diagnostics, 2068) >= 2)
  assert_true(count_code(diagnostics, 2048) >= 2)
}

///|
test "analytics checks flag single and double bracket operator misuse" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[ test =~ foo ]
      #|[[ 3 \< 4 ]]
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2074))
  assert_true(has_code(diagnostics, 2075))
}

///|
test "analytics checks allow native double bracket angle operators" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[[ a < b ]]
      #|[[ c > d ]]
      #|
    ),
  )
  assert_true(!has_code(diagnostics, 2075))
}

///|
test "analytics optional checks flag useless use of cat" {
  let script = parse_checks_ok(
    (
      #|cat foo | grep bar
      #|cat "$var" | grep bar
      #|
    ),
  )
  let diagnostics = check_script(
    script,
    options=CheckOptions::default().with_optional_checks(["useless-use-of-cat"]),
  )

  assert_eq(count_code(diagnostics, 2002), 2)
  assert_eq(
    first_code(diagnostics, 2002).message,
    "Useless cat. Consider 'cmd < file | ..' or 'cmd file | ..' instead.",
  )
}

///|
test "analytics optional checks avoid useless-cat false positives" {
  let script = parse_checks_ok(
    (
      #|cat * | grep bar
      #|cat $var | grep bar
      #|cat "${!var}" | grep bar
      #|cat "$@" | grep bar
      #|cat -n | grep bar
      #|
    ),
  )
  let diagnostics = check_script(
    script,
    options=CheckOptions::default().with_optional_checks(["useless-use-of-cat"]),
  )

  assert_true(!has_code(diagnostics, 2002))
}

///|
test "analytics optional checks recommend default case arms" {
  let script = parse_checks_ok(
    (
      #|case $1 in a) true ;; ?*?) true ;; *?) true ;; esac
      #|
    ),
  )
  let diagnostics = check_script(
    script,
    options=CheckOptions::default().with_optional_checks(["add-default-case"]),
  )

  assert_true(has_code(diagnostics, 2249))
  assert_eq(
    first_code(diagnostics, 2249).message,
    "Consider adding a default *) case, even if it just exits with error.",
  )
}

///|
test "analytics optional checks accept existing default case arms" {
  let script = parse_checks_ok(
    (
      #|case $1 in x|*) true ;; **) true ;; esac
      #|
    ),
  )
  let diagnostics = check_script(
    script,
    options=CheckOptions::default().with_optional_checks(["add-default-case"]),
  )

  assert_true(!has_code(diagnostics, 2249))
}

///|
test "analytics checks flag assignment misuse patterns" {
  let diagnostics = check_source(
    (
      #|foo=bar | grep x
      #|out=ls -l
      #|prefix=hello printf '%s\n' "$prefix"
      #|same="$same"
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2036))
  assert_true(has_code(diagnostics, 2037))
  assert_true(has_code(diagnostics, 2097))
  assert_true(has_code(diagnostics, 2098))
  assert_true(has_code(diagnostics, 2269))
}

///|
test "analytics checks avoid assignment misuse false positives" {
  let diagnostics = check_source(
    (
      #|foo=bar
      #|value=$(echo "$value") cmd
      #|same=$other
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2036))
  assert_true(!has_code(diagnostics, 2037))
  assert_true(!has_code(diagnostics, 2097))
  assert_true(!has_code(diagnostics, 2098))
  assert_true(!has_code(diagnostics, 2269))
}

///|
test "analytics checks flag conditional operator misuse and quoted regexes" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[ foo -a -f bar ]
      #|[ -z 3 -o a = b ]
      #|[[ $foo =~ 'cow|bar' ]]
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2166), 2)
  assert_true(has_code(diagnostics, 2076))
}

///|
test "analytics checks allow split [ ] conditions and native [[ ]] and ors" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[ a ] && [ b ]
      #|[ a ] || [ b ]
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2166))
}

///|
test "analytics checks keep quoted =~ literals quiet" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[[ $foo =~ "bar" ]]
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2076))
}

///|
test "analytics checks flag array splitting loop globs and subshell tests" {
  let diagnostics = check_source(
    (
      #|arr=( $var $(cmd) )
      #|for file in $dir/*.txt; do :; done
      #|( -e file )
      #|( 1 -gt 2 )
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2206))
  assert_true(has_code(diagnostics, 2207))
  assert_true(has_code(diagnostics, 2231))
  assert_true(has_code(diagnostics, 2204))
  assert_true(has_code(diagnostics, 2205))
}

///|
test "analytics checks avoid quoted array and loop glob false positives" {
  let diagnostics = check_source(
    (
      #|arr=( "$var" "$(cmd)" $! $$ $# ${#arr[@]} * foo{1,2} )
      #|for file in "$dir"/*.txt; do :; done
      #|( grep -c foo bar )
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2206))
  assert_true(!has_code(diagnostics, 2207))
  assert_true(!has_code(diagnostics, 2231))
  assert_true(!has_code(diagnostics, 2204))
  assert_true(!has_code(diagnostics, 2205))
}

///|
test "analytics batch b checks flag glob confusion empty tests and glob comparisons" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[[ $cow == $bar ]]
      #|[ $cow = *foo* ]
      #|[[ $foo =~ *foo* ]]
      #|if [ ]; then :; fi
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2053))
  assert_true(has_code(diagnostics, 2081))
  assert_true(has_code(diagnostics, 2049))
  assert_true(has_code(diagnostics, 2212))
}

///|
test "analytics batch b checks keep regex and comparison false positives in check" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[[ $cow == "$bar" ]]
      #|[ $cow = foo ]
      #|[[ $foo =~ ^c.* ]]
      #|[[ $foo =~ x\* ]]
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2053))
  assert_true(!has_code(diagnostics, 2081))
  assert_true(!has_code(diagnostics, 2049))

  let busybox = run_checks_with_shell(
    parse_checks_ok(
      (
        #|[[ $f == *foo* ]]
        #|
      ),
    ),
    @semantics.ShellDialect::BusyboxSh,
    false,
    [],
  )
  assert_true(has_code(busybox, 2330))
}

///|
test "analytics batch b checks flag redirect and command target confusion" {
  let diagnostics = check_source(
    (
      #|test 3 > 1
      #|/usr/bin/test $var > $foo
      #|foo 1>2
      #|ls > rm
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2065), 2)
  assert_true(has_code(diagnostics, 2210))
  assert_true(has_code(diagnostics, 2238))
}

///|
test "analytics batch b checks avoid redirect target false positives" {
  let diagnostics = check_source(
    (
      #|test 1 -eq 2 2> file
      #|echo foo > '2'
      #|ls > myfile
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2065))
  assert_true(!has_code(diagnostics, 2210))
  assert_true(!has_code(diagnostics, 2238))
}

///|
test "analytics batch b checks flag arithmetic and malformed command names" {
  let diagnostics = check_source(
    (
      #|./ file
      #|foo=bar * 2
      #|n=2
      #|i=n*2
      #|foo*
      #|-e file
      #|''
      #|/
      #|foo,
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2083))
  assert_true(has_code(diagnostics, 2099))
  assert_true(has_code(diagnostics, 2100))
  assert_true(has_code(diagnostics, 2211))
  assert_true(has_code(diagnostics, 2215))
  assert_true(has_code(diagnostics, 2286))
  assert_true(has_code(diagnostics, 2287))
  assert_true(has_code(diagnostics, 2288))
}

///|
test "analytics batch b checks avoid command shape false positives" {
  let diagnostics = check_source(
    (
      #|./file
      #|echo foo*
      #|'--myexec--' args
      #|. foo.sh
      #|: foo
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2083))
  assert_true(!has_code(diagnostics, 2211))
  assert_true(!has_code(diagnostics, 2215))
  assert_true(!has_code(diagnostics, 2286))
  assert_true(!has_code(diagnostics, 2287))
  assert_true(!has_code(diagnostics, 2288))
}

///|
test "analytics batch b checks flag output-stealing command substitutions" {
  let diagnostics = check_source(
    (
      #|out=$(foo > log)
      #|err=$(foo >&2)
      #|keep=$(foo 2>&1 > /dev/null)
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2327), 2)
  assert_eq(count_code(diagnostics, 2328), 2)
}

///|
test "analytics batch c checks flag echo-wc ssh heredoc and late function definitions" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|echo "$foo" | wc -c
      #|ssh host <<EOF2
      #|echo $HOME
      #|EOF2
      #|f
      #|f() { true; }
      #|true
      #|[ $? == 0 ]
      #|$"(foo)"
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2000))
  assert_true(has_code(diagnostics, 2087))
  assert_true(has_code(diagnostics, 2181))
  assert_true(has_code(diagnostics, 2218))
  assert_true(has_code(diagnostics, 2247))
}

///|
test "analytics batch c attaches shellcheck-style quote swap fix" {
  let source =
    #|#!/bin/bash
    #|$"(foo)"
    #|
  let diagnostic = first_code(check_source(source), 2247)
  assert_eq(diagnostic.span.start.line, 2)
  assert_eq(diagnostic.span.start.column, 1)
  match diagnostic.fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 1)
      let replacement = fix.replacements[0]
      assert_eq(replacement.start.line, 2)
      assert_eq(replacement.start.column, 1)
      assert_eq(replacement.end.line, 2)
      assert_eq(replacement.end.column, 3)
      assert_eq(replacement.text, "\"$")
      assert_eq(replacement.precedence, 7)
      assert_true(replacement.insertion_point == @fixer.InsertionPoint::after())
      @test.assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|"$(foo)"
            #|
          ),
        ),
      )
    }
    None => checks_fail("expected SC2247 fix")
  }
}

///|
test "analytics batch c checks flag overwritten exit codes" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|x(){ return 1; }
      #|x
      #|[ $? -eq 1 ] || [ $? -eq 2 ]
      #|echo "$?"
      #|echo "$?"
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2319), 1)
  assert_eq(count_code(diagnostics, 2320), 1)
}

///|
test "analytics batch c checks avoid false positives for quiet cases" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|foo=bar
      #|printf '%s\n' "$foo" | wc -c
      #|ssh host <<'EOF'
      #|echo $HOME
      #|EOF
      #|f() { true; }
      #|f
      #|g() { [ $? == 0 ]; }
      #|false
      #|status=$?
      #|echo "$status"
      #|"$("foo")"
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2000))
  assert_true(!has_code(diagnostics, 2087))
  assert_true(!has_code(diagnostics, 2181))
  assert_true(!has_code(diagnostics, 2218))
  assert_true(!has_code(diagnostics, 2247))
  assert_true(!has_code(diagnostics, 2319))
  assert_true(!has_code(diagnostics, 2320))
}

///|
test "analytics optional checks flag quote-safe variables only for clean standalone words" {
  let source =
    #|safe=hello
    #|echo $safe
    #|unsafe='hi there'
    #|echo $unsafe
    #|
  let diagnostics = check_script(
    parse_checks_ok(source),
    options=CheckOptions::default().with_optional_checks([
      "quote-safe-variables",
    ]),
  )

  assert_eq(count_code(diagnostics, 2248), 1)
  let diagnostic = first_code(diagnostics, 2248)
  assert_eq(
    diagnostic.message,
    "Prefer double quoting even when variables don't contain special characters.",
  )
  match diagnostic.fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 2)
      let open_quote = fix.replacements[0]
      assert_eq(open_quote.start.line, 2)
      assert_eq(open_quote.start.column, 6)
      assert_eq(open_quote.end.line, 2)
      assert_eq(open_quote.end.column, 6)
      assert_eq(open_quote.text, "\"")
      assert_eq(open_quote.precedence, 7)
      assert_true(open_quote.insertion_point == @fixer.InsertionPoint::after())
      let close_quote = fix.replacements[1]
      assert_eq(close_quote.start.line, 2)
      assert_eq(close_quote.start.column, 11)
      assert_eq(close_quote.end.line, 2)
      assert_eq(close_quote.end.column, 11)
      assert_eq(close_quote.text, "\"")
      assert_eq(close_quote.precedence, 7)
      assert_true(
        close_quote.insertion_point == @fixer.InsertionPoint::before(),
      )
      @test.assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|safe=hello
            #|echo "$safe"
            #|unsafe='hi there'
            #|echo $unsafe
            #|
          ),
        ),
      )
    }
    None => checks_fail("expected SC2248 fix")
  }
}

///|
test "analytics optional checks flag nullary and negated conditions" {
  let diagnostics = check_script(
    parse_checks_ok(
      (
        #|[ "$name" ]
        #|[[ $(cmd) ]]
        #|[[ "$a$b" ]]
        #|[[ -n "$a" ]]
        #|[ ! -z "$var" ]
        #|! [ -n "$var" ]
        #|[[ ! $var == foo ]]
        #|! [[ $var -gt 3 ]]
        #|! [[ $var =~ .* ]]
        #|
      ),
    ),
    options=CheckOptions::default().with_optional_checks([
      "avoid-nullary-conditions", "avoid-negated-conditions",
    ]),
  )

  assert_true(has_code(diagnostics, 2243))
  assert_eq(count_code(diagnostics, 2244), 2)
  assert_true(has_code(diagnostics, 2236))
  assert_true(has_code(diagnostics, 2237))
  assert_eq(count_code(diagnostics, 2335), 2)
}

///|
test "analytics optional checks attach shellcheck-style nullary condition fix" {
  let source =
    #|[[ $(cmd) ]]
    #|
  let diagnostics = check_script(
    parse_checks_ok(source),
    options=CheckOptions::default().with_optional_checks([
      "avoid-nullary-conditions",
    ]),
  )

  let diagnostic = first_code(diagnostics, 2243)
  assert_eq(diagnostic.span.start.line, 1)
  assert_eq(diagnostic.span.start.column, 4)
  assert_eq(diagnostic.span.end.column, 10)
  match diagnostic.fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 1)
      let replacement = fix.replacements[0]
      assert_eq(replacement.start.line, 1)
      assert_eq(replacement.start.column, 4)
      assert_eq(replacement.end.line, 1)
      assert_eq(replacement.end.column, 4)
      assert_eq(replacement.text, "-n ")
      assert_eq(replacement.precedence, 7)
      assert_true(replacement.insertion_point == @fixer.InsertionPoint::after())
      @test.assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|[[ -n $(cmd) ]]
            #|
          ),
        ),
      )
    }
    None => checks_fail("expected SC2243 fix")
  }
}

///|
test "analytics optional checks attach shellcheck-style dynamic nullary fix" {
  let source =
    #|[[ "$a$b" ]]
    #|
  let diagnostics = check_script(
    parse_checks_ok(source),
    options=CheckOptions::default().with_optional_checks([
      "avoid-nullary-conditions",
    ]),
  )

  let diagnostic = first_code(diagnostics, 2244)
  assert_eq(diagnostic.span.start.line, 1)
  assert_eq(diagnostic.span.start.column, 4)
  assert_eq(diagnostic.span.end.column, 10)
  match diagnostic.fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 1)
      let replacement = fix.replacements[0]
      assert_eq(replacement.start.line, 1)
      assert_eq(replacement.start.column, 4)
      assert_eq(replacement.end.line, 1)
      assert_eq(replacement.end.column, 4)
      assert_eq(replacement.text, "-n ")
      assert_eq(replacement.precedence, 7)
      assert_true(replacement.insertion_point == @fixer.InsertionPoint::after())
      @test.assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|[[ -n "$a$b" ]]
            #|
          ),
        ),
      )
    }
    None => checks_fail("expected SC2244 fix")
  }
}

///|
test "analytics optional checks require braces for bare variable references" {
  let source =
    #|echo $name
    #|printf '%s' prefix=$name
    #|printf '%s' "$name"
    #|$tool=42
    #|
  let diagnostics = check_script(
    parse_checks_ok(source),
    options=CheckOptions::default().with_optional_checks([
      "require-variable-braces",
    ]),
  )

  assert_eq(count_code(diagnostics, 2250), 2)
  let diagnostic = first_code(diagnostics, 2250)
  match diagnostic.fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 2)
      let open_brace = fix.replacements[0]
      assert_eq(open_brace.start.line, 1)
      assert_eq(open_brace.start.column, 6)
      assert_eq(open_brace.end.line, 1)
      assert_eq(open_brace.end.column, 7)
      assert_eq(open_brace.text, "${")
      assert_eq(open_brace.precedence, 7)
      assert_true(open_brace.insertion_point == @fixer.InsertionPoint::after())
      let close_brace = fix.replacements[1]
      assert_eq(close_brace.start.line, 1)
      assert_eq(close_brace.start.column, 11)
      assert_eq(close_brace.end.line, 1)
      assert_eq(close_brace.end.column, 11)
      assert_eq(close_brace.text, "}")
      assert_eq(close_brace.precedence, 7)
      assert_true(
        close_brace.insertion_point == @fixer.InsertionPoint::before(),
      )
      @test.assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|echo ${name}
            #|printf '%s' prefix=$name
            #|printf '%s' "$name"
            #|$tool=42
            #|
          ),
        ),
      )
    }
    None => checks_fail("expected SC2250 fix on bare variable word")
  }
}

///|
test "analytics optional checks extend unassigned-variable warnings to uppercase names" {
  let diagnostics = check_script(
    parse_checks_ok(
      (
        #|echo $VAR
        #|echo $foo
        #|
      ),
    ),
    options=CheckOptions::default().with_optional_checks([
      "check-unassigned-uppercase",
    ]),
  )

  assert_eq(count_code(diagnostics, 2154), 1)
  assert_true(first_code(diagnostics, 2154).message.contains("VAR"))
}

///|
test "analytics optional checks require double brackets only in supporting shells" {
  let script = parse_checks_ok(
    (
      #|[ -x foo ]
      #|[[ -x foo ]]
      #|
    ),
  )
  let bash = run_checks_with_shell(
    script,
    @semantics.ShellDialect::Bash,
    false,
    ["require-double-brackets"],
  )
  let sh = run_checks_with_shell(script, @semantics.ShellDialect::Sh, false, [
    "require-double-brackets",
  ])

  assert_eq(count_code(bash, 2292), 1)
  assert_true(!has_code(sh, 2292))
}

///|
test "analytics optional checks attach shellcheck-style double bracket fix" {
  let source =
    #|#!/bin/bash
    #|[ -x foo ]
    #|
  let diagnostics = check_script(
    parse_checks_ok(source),
    options=CheckOptions::default().with_optional_checks([
      "require-double-brackets",
    ]),
  )

  let diagnostic = first_code(diagnostics, 2292)
  match diagnostic.fix {
    Some(fix) => {
      assert_eq(fix.replacements.length(), 2)
      let open_bracket = fix.replacements[0]
      assert_eq(open_bracket.start.line, 2)
      assert_eq(open_bracket.start.column, 1)
      assert_eq(open_bracket.end.line, 2)
      assert_eq(open_bracket.end.column, 1)
      assert_eq(open_bracket.text, "[")
      assert_eq(open_bracket.precedence, 7)
      assert_true(
        open_bracket.insertion_point == @fixer.InsertionPoint::after(),
      )
      let close_bracket = fix.replacements[1]
      assert_eq(close_bracket.start.line, 2)
      assert_eq(close_bracket.start.column, 11)
      assert_eq(close_bracket.end.line, 2)
      assert_eq(close_bracket.end.column, 11)
      assert_eq(close_bracket.text, "]")
      assert_eq(close_bracket.precedence, 7)
      assert_true(
        close_bracket.insertion_point == @fixer.InsertionPoint::before(),
      )
      @test.assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|[[ -x foo ]]
            #|
          ),
        ),
      )
    }
    None => checks_fail("expected SC2292 fix")
  }
}

///|
test "analytics optional checks flag set-e suppression contexts for functions" {
  let diagnostics = run_checks_with_shell(
    parse_checks_ok(
      (
        #|#!/bin/bash
        #|set -e
        #|f(){ false; }
        #|result=$(f)
        #|f && echo ok
        #|if f; then :; fi
        #|while f; do :; done
        #|! f
        #|foo=$(set -e; f)
        #|
      ),
    ),
    @semantics.ShellDialect::Bash,
    false,
    ["check-set-e-suppressed"],
  )

  assert_eq(count_code(diagnostics, 2310), 4)
  assert_eq(count_code(diagnostics, 2311), 1)
}

///|
test "analytics optional checks flag additional masked return contexts" {
  let diagnostics = check_script(
    parse_checks_ok(
      (
        #|false | true
        #|true $(false)
        #|x=$(false)$(true)
        #|readarray -t files < <(ls)
        #|x=$(false)true
        #|echo asdf | false
        #|
      ),
    ),
    options=CheckOptions::default().with_optional_checks([
      "check-extra-masked-returns",
    ]),
  )

  assert_eq(count_code(diagnostics, 2312), 4)
}
