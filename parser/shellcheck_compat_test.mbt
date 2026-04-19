///|
fn assert_ok(label : String, source : String) -> Unit {
  let report = @parser.parse_script_report(source)
  if report.diagnostics.length() != 0 {
    match report.script {
      Some(script) =>
        abort(
          "\{label}: expected clean parse, got diagnostics \{@debug.to_string(report.diagnostics)} with script \{script.dump()}",
        )
      None =>
        abort(
          "\{label}: expected clean parse, got failure \{@debug.to_string(report.diagnostics)}",
        )
    }
  }
  match report.script {
    Some(_) => ()
    None => abort("\{label}: expected clean parse, got parse failure")
  }
}

///|
fn assert_not_ok(label : String, source : String) -> Unit {
  let report = @parser.parse_script_report(source)
  match report.script {
    Some(script) =>
      abort(
        "\{label}: expected parse failure, got \{script.dump()} with diagnostics \{@debug.to_string(report.diagnostics)}",
      )
    None => ()
  }
}

///|
fn assert_no_commands(label : String, source : String) -> Unit {
  let report = @parser.parse_script_report(source)
  match report.script {
    Some(script) => {
      if report.diagnostics.length() != 0 {
        abort(
          "\{label}: expected comment-only script, got diagnostics \{@debug.to_string(report.diagnostics)}",
        )
      }
      if script.items.length() != 0 {
        abort("\{label}: expected no parsed commands, got \{script.dump()}")
      }
    }
    None =>
      abort(
        "\{label}: expected comment-only script, got parse failure \{@debug.to_string(report.diagnostics)}",
      )
  }
}

///|
fn assert_warning(label : String, source : String) -> Unit {
  let report = @parser.parse_script_report(source)
  if report.diagnostics.length() == 0 {
    match report.script {
      Some(script) =>
        abort(
          "\{label}: expected diagnostics, got clean parse \{script.dump()}",
        )
      None => abort("\{label}: expected parse with diagnostics, got failure")
    }
  }
  match report.script {
    Some(_) => ()
    None =>
      abort(
        "\{label}: expected parse with diagnostics, got failure \{@debug.to_string(report.diagnostics)}",
      )
  }
}

///|
fn assert_word_ok(label : String, fragment : String) -> Unit {
  assert_ok(label, "echo \{fragment}")
}

///|
fn assert_word_warning(label : String, fragment : String) -> Unit {
  assert_warning(label, "echo \{fragment}")
}

///|
test "shellcheck compatibility function and loop samples" {
  assert_ok("function standard body", "foo() { command foo --lol \"$@\"; }")
  assert_ok("function spaced parens", "foo   (){ command foo --lol \"$@\"; }")
  assert_warning("function parameter list warning", "foo(a, b) { true; }")
  assert_ok("function colon name", ":(){ :|:;}")
  assert_ok("function question mark name", "?(){ foo; }")
  assert_ok("function dotdot name", "..(){ cd ..; }")
  assert_ok("function subshell body", "foo() (ls)")
  assert_ok("function keyword without parens", "function foo { true; }")
  assert_ok("function keyword with parens", "function foo () { true; }")
  assert_warning(
    "function keyword missing space warning",
    (
      #|function foo{
      #|true
      #|}
    ),
  )
  assert_ok("function keyword extended name", "function []!() { true; }")
  assert_ok("function at-sign name", "@require(){ true; }")
  assert_ok("function hash name", "foo#bar(){ :; }")
  assert_no_commands("function hash-only name stays comment", "#bar(){ :; }")

  assert_ok("for with in list", "for f in *; do rm \"$f\"; done")
  assert_ok("for with brace body", "for f in *; { rm \"$f\"; }")
  assert_ok("for implicit positional parameters", "for f; do foo; done")
  assert_ok("for without in", "for i do true; done")
  assert_ok("arithmetic for compact", "for((i=0; i<10; i++)); do echo $i; done")
  assert_ok(
    "arithmetic for with newline",
    (
      #|for ((i=0;i<10 && n>x;i++,--n))
      #|do 
      #|echo $i
      #|done
    ),
  )
  assert_ok(
    "arithmetic for empty clauses",
    (
      #|for ((;;))
      #|do echo $i
      #|done
    ),
  )
  assert_ok(
    "arithmetic for empty clauses inline do",
    (
      #|for ((;;)) do echo $i
      #|done
    ),
  )
  assert_ok(
    "arithmetic for empty clauses semicolon",
    (
      #|for ((;;)) ; do echo $i
      #|done
    ),
  )
  assert_ok("arithmetic for brace body", "for ((;;)) { true; }")
  assert_ok(
    "for with line-continuation in clause",
    (
      #|for foo
      #|in\
      #|  bar\
      #|  baz
      #|do true; done
    ),
  )
  assert_warning(
    "for dollar iterator warning", "for $a in *; do echo \"$a\"; done",
  )
}

///|
test "shellcheck compatibility case and condition samples" {
  assert_ok(
    "single bracket escaped groups", "[ \\( a = b \\) -a \\( c = d \\) ]",
  )
  assert_ok("double bracket grouped or", "[[ (a = b) || (c = d) ]]")
  assert_ok("double bracket character class glob", "[[ $c = [[:alpha:].~-] ]]")
  assert_ok("double bracket regex glob rhs", "[[ $c =~ *foo* ]]")
  assert_ok(
    "double bracket regex nested closing brackets", "[[ $c =~ f( ]] )* ]]",
  )
  assert_ok("double bracket regex parens", "[[ $c =~ a(b) ]]")
  assert_ok(
    "double bracket regex with nested closing brackets", "[[ $c =~ f( ($var ]]) )* ]]",
  )
  assert_ok("double bracket regex anchors", "[[ $c =~ ^[yY]$ ]]")
  assert_ok(
    "double bracket regex comment prefix", "[[ ${line} =~ ^[[:space:]]*# ]]",
  )
  assert_ok("double bracket regex alternation", "[[ $l =~ ogg|flac ]]")
  assert_ok("single bracket and file test", "[ foo -a -f bar ]")
  assert_ok("single bracket logical and", "[ foo && bar ]")
  assert_ok("double bracket legacy and", "[[ foo -a bar ]]")
  assert_ok("single bracket logical or", "[ foo || bar ]")
  assert_ok("double bracket legacy or", "[[ foo -o bar ]]")
  assert_ok(
    "double bracket multiline lhs and rhs",
    (
      #|[[
      #|a == b
      #|||
      #|c == d ]]
    ),
  )
  assert_ok(
    "double bracket multiline operator gap",
    (
      #|[[
      #|a == b  ||
      #|c == d ]]
    ),
  )
  assert_ok(
    "double bracket multiline rhs only",
    (
      #|[[ a == b
      #|||
      #|c == d ]]
    ),
  )
  assert_ok(
    "double bracket regex line breaks",
    (
      #|[[ a == b ||
      #| c == d ]]
    ),
  )
  assert_ok("double bracket regex counted repetition", "[[ foo =~ ^fo{1,3}$ ]]")
  assert_ok("single bracket empty", "[ ]")
  assert_ok("single bracket quoted parens", "[ '(' x \")\" ]")
  assert_ok("single bracket quoted operator", "[ foo '>' bar ]")
  assert_ok("single bracket double quoted operator", "[ foo \">=\" bar ]")
  assert_ok("single bracket escaped operator", "[ foo \\< bar ]")
  assert_ok("double bracket literal charset", "[[ ${file::1} = [-.\\|/\\\\] ]]")
  assert_ok("double bracket numeric compare", "[[ echo_rc -eq 0 ]]")
  assert_ok("double bracket regex escaped spaces", "[[ $1 =~ ^(a\\ b)$ ]]")
  assert_ok(
    "double bracket regex escaped parens", "[[ $1 =~ \\.a\\.(\\.b\\.)\\.c\\. ]]",
  )
  assert_ok("double bracket array index unary op", "[[ -v arr[$var] ]]")
  assert_ok("double bracket file newer-than", "[[ lex.yy.c -ot program.l ]]")
  assert_ok(
    "condition line continuation before and",
    (
      #|[[ foo ]]\
      #| && bar
    ),
  )
  assert_warning(
    "single bracket legacy or warning",
    (
      #|[ a == b 
      #| -o c == d ]
    ),
  )
  assert_ok("double bracket glob with quoted expansion", "[[ x = [\"$1\"] ]]")
  assert_ok("double bracket glob literal match", "[[ x = [*] ]]")
  assert_warning("condition trailing words", "[[ x ]] foo")
  assert_ok("condition command allows redirects", "[[ x ]] > foo 2>&1")

  assert_ok(
    "case multiple explicit patterns", "case foo in a ) lol; cow;; b|d) fooo; esac",
  )
  assert_ok(
    "case star pattern with spaced paren",
    (
      #|case foo
      #| in * ) echo bar;; esac
    ),
  )
  assert_ok(
    "case branch background terminator",
    (
      #|case foo
      #| in * ) echo bar & ;; esac
    ),
  )
  assert_ok(
    "case reserved words as patterns",
    (
      #|case foo
      #| in if) :;; done) :;; esac
    ),
  )
  assert_ok(
    "case fallthrough separator",
    (
      #|case foo
      #| in *) echo bar ;& bar) foo; esac
    ),
  )
  assert_ok(
    "case continue separator",
    (
      #|case foo
      #| in *) echo bar;;& foo) baz;; esac
    ),
  )
}

///|
test "shellcheck compatibility arithmetic and heredoc samples" {
  assert_ok("arithmetic postfix and prefix", "(( n++ + ++c ))")
  assert_ok("arithmetic comma group", "(( $N*4-(3,2) ))")
  assert_ok("arithmetic compound assign shift", "(( n|=2<<1 ))")
  assert_ok("arithmetic compound assign power", "(( n &= 2 **3 ))")
  assert_ok("arithmetic mixed logical assign", "(( 1 |= 4 && n >>= 4 ))")
  assert_ok("arithmetic bitwise and logical mix", "(( 1 | 2 ||3|4 ))")
  assert_ok("arithmetic power precedence", "(( 3*2**10 ))")
  assert_ok("arithmetic literal number", "(( 3 ))")
  assert_ok("arithmetic xor bang unary minus", "(( a^!-b ))")
  assert_ok("arithmetic bang special parameter", "(( ! $? ))")
  assert_ok("arithmetic explicit bases", "(( 10#08 * 16#f ))")
  assert_ok("arithmetic quoted subexpressions", "(( \"$((3+2))\" + '37' ))")
  assert_ok("arithmetic with command substitution", "(( 1+`echo 2` ))")
  assert_ok(
    "arithmetic indexed command substitution", "(( foo[`echo foo | sed s/foo/4/g` * 3] + 4 ))",
  )
  assert_ok("arithmetic indexed variable", "(( foo[9*y+x]++ ))")
  assert_ok("arithmetic concatenated parameters", "(( $foo$bar ))")
  assert_ok("arithmetic comparison with grouping", "(( i<(0+(1+1)) ))")
  assert_ok("arithmetic simple ternary", "(( a?b:c ))")
  assert_ok("arithmetic ternary nesting", "(( a ? b ? c : d : e ))")
  assert_ok("arithmetic ternary rhs nesting", "(( a ? b : c ? d : e ))")
  assert_ok("arithmetic double negation", "(( !!a ))")
  assert_ok("arithmetic bitwise not", "(( ~0 ))")
  assert_ok(
    "arithmetic line continuation",
    (
      #|(( \
      #|3 +\
      #|  2 ))
    ),
  )

  assert_ok(
    "heredoc simple body",
    (
      #|cat << foo
      #|lol
      #|cow
      #|foo
    ),
  )
  assert_warning(
    "heredoc strip tabs rejects spaces",
    (
      #|cat <<- EOF
      #|  cow
      #|  EOF
    ),
  )
  assert_ok(
    "heredoc dollar quote fragment",
    (
      #|cat << foo
      #|$"
      #|foo
    ),
  )
  assert_warning(
    "heredoc unterminated backquote",
    (
      #|cat << foo
      #|`
      #|foo
    ),
  )
  assert_ok(
    "heredoc escaped command substitution text",
    (
      #|cat << foo
      #|\$(f ())
      #|foo
    ),
  )
  assert_ok(
    "heredoc escaped delimiter space",
    (
      #|cat << foo\ bar
      #|cow
      #|foo bar
    ),
  )
  assert_ok(
    "heredoc inside if simple redirect",
    (
      #|if true; then cat << foo; fi
      #|bar
      #|foo
      #|
    ),
  )
  assert_ok(
    "heredoc process-like suffix on opener",
    (
      #|cat << foo $(
      #|foo
      #|)lol
      #|foo
      #|
    ),
  )
  assert_ok(
    "heredoc pipeline on opener",
    (
      #|cat << foo|cat
      #|bar
      #|foo
    ),
  )
  assert_ok(
    "heredoc chained redirects in if",
    (
      #|if true; then cat << foo << bar; fi
      #|foo
      #|bar
      #|
    ),
  )
  assert_ok(
    "heredoc delimiter with trailing redirect tokens",
    (
      #|cat <<foo>>bar
      #|etc
      #|foo
    ),
  )
  assert_ok(
    "quoted heredoc delimiter punctuation",
    (
      #|cat <<'#!'
      #|Hello World
      #|#!
      #|echo Done
    ),
  )
  assert_ok(
    "tab-stripping quoted heredoc delimiter",
    (
      #|cat <<- ' foo'
      #|bar
      #| foo
      #|
    ),
  )
  assert_warning(
    "tab-stripping quoted heredoc wrong indentation",
    (
      #|cat <<- ' foo'
      #|bar
      #|  foo
      #| foo
      #|
    ),
  )
  assert_ok(
    "quoted heredoc mixed quote delimiter",
    (
      #|cat <<'"foo'
      #|bar
      #|"foo
      #|
    ),
  )
  assert_ok(
    "tab-stripping heredoc punctuation",
    (
      #|cat <<- !foo
      #|bar
      #|!foo
    ),
  )
  assert_warning(
    "heredoc trailing space mismatch",
    (
      #|cat << foo
      #|bar
      #|foo 
      #|
    ),
  )
  assert_warning(
    "heredoc extra text before delimiter",
    (
      #|cat <<foo
      #|bar
      #|foo bar
      #|foo
    ),
  )
  assert_warning(
    "heredoc indented end token warning",
    (
      #|cat << foo
      #|  foo
      #|()
      #|foo
      #|
    ),
  )
  assert_ok(
    "heredoc indented end token with directive",
    (
      #|# shellcheck disable=SC1039
      #|cat << foo
      #|  foo
      #|()
      #|foo
      #|
    ),
  )
  assert_warning(
    "heredoc carriage returns",
    (
      $|cat << foo\{'\r'}
      $|cow\{'\r'}
      $|foo\{'\r'}
      $|
    ),
  )
  assert_not_ok(
    "heredoc trailing space before crlf delimiter",
    (
      $|cat << foo \{'\r'}
      $|cow\{'\r'}
      $|foo\{'\r'}
      $|
    ),
  )
}

///|
test "shellcheck compatibility metadata and script samples" {
  assert_no_commands(
    "prop_readAnnotation1",
    (
      #|# shellcheck disable=1234,5678
      #|
    ),
  )
  assert_no_commands(
    "prop_readAnnotation2",
    (
      #|# shellcheck disable=SC1234 disable=SC5678
      #|
    ),
  )
  assert_no_commands(
    "prop_readAnnotation3",
    (
      #|# shellcheck disable=SC1234 source=/dev/null disable=SC5678
      #|
    ),
  )
  assert_warning(
    "prop_readAnnotation4",
    (
      #|# shellcheck cats=dogs disable=SC1234
      #|
    ),
  )
  assert_no_commands(
    "prop_readAnnotation5",
    (
      #|# shellcheck disable=SC2002 # All cats are precious
      #|
    ),
  )
  assert_no_commands(
    "prop_readAnnotation6",
    (
      #|# shellcheck disable=SC1234 # shellcheck foo=bar
      #|
    ),
  )
  assert_no_commands(
    "prop_readAnnotation7",
    (
      #|# shellcheck disable=SC1000,SC2000-SC3000,SC1001
      #|
    ),
  )
  assert_no_commands(
    "prop_readAnnotation8",
    (
      #|# shellcheck disable=all
      #|
    ),
  )
  assert_no_commands(
    "prop_readAnnotation9",
    (
      #|# shellcheck source='foo bar' source-path="baz etc"
      #|
    ),
  )
  assert_no_commands(
    "prop_readAnnotation10",
    (
      #|# shellcheck disable='SC1234,SC2345' enable="foo" shell='bash'
      #|
    ),
  )
  assert_no_commands("prop_readAnyComment", "# Comment")

  assert_ok(
    "prop_readScript1",
    (
      #|#!/bin/bash
      #|echo hello world
      #|
    ),
  )
  assert_warning(
    "prop_readScript2",
    (
      $|#!/bin/bash\{'\r'}
      $|echo hello world
      $|
    ),
  )
  assert_warning(
    "prop_readScript3",
    (
      #|#!/bin/bash
      #|echo hello world
    ),
  )
  assert_warning(
    "prop_readScript4",
    (
      #|#!/usr/bin/perl
      #|foo=(
      #|
    ),
  )
  assert_no_commands(
    "prop_readScript5",
    (
      #|#!/bin/bash
      #|#This is an empty script
      #|
      #|
    ),
  )
  assert_no_commands(
    "prop_readScript6",
    (
      #|#!/usr/bin/env -S X=FOO bash
      #|#This is an empty script
      #|
      #|
    ),
  )
  assert_ok(
    "prop_readScript7",
    (
      #|#!/bin/zsh
      #|# shellcheck disable=SC1071
      #|for f (a b); echo $f
      #|
    ),
  )
}

///|
test "shellcheck compatibility word and expansion samples" {
  assert_word_ok("prop_readNormalWord", "'foo'\"bar\"{1..3}baz$(lol)")
  assert_word_ok("prop_readNormalWord2", "foo**(foo)!!!(@@(bar))")
  assert_word_ok("prop_readNormalWord3", "foo#")
  assert_word_ok(
    "prop_readNormalWord4",
    (
      #|$"foo"$'foo
      #|bar'
    ),
  )
  assert_word_warning("prop_readNormalWord5", "${foo}}")
  assert_word_ok("prop_readNormalWord6", "foo/{}")
  assert_word_ok(
    "prop_readNormalWord7",
    (
      #|foo\
      #|bar
    ),
  )
  assert_warning(
    "prop_readNormalWord8",
    (
      #|(foo\ 
      #|bar)
    ),
  )
  assert_ok(
    "prop_readNormalWord9",
    (
      #|(foo\ ;
      #|bar)
    ),
  )
  assert_word_warning("prop_readNormalWord10", "\u201Chello\u201D")
  assert_word_warning("prop_readNormalWord11", "\u2018hello\u2019")
  assert_word_warning("prop_readNormalWord12", "hello\u2018")

  assert_word_ok("prop_readProcSub1", "<(echo test | wc -l)")
  assert_word_ok("prop_readProcSub2", "<(  if true; then true; fi )")
  assert_word_ok(
    "prop_readProcSub3",
    (
      #|<( # nothing here 
      #|)
    ),
  )

  assert_word_ok("prop_readSingleQuoted", "'foo bar'")
  assert_word_warning("prop_readSingleQuoted2", "'foo bar\\'")
  assert_word_warning("prop_readSingleQuoted4", "'it's")
  assert_warning(
    "prop_readSingleQuoted5",
    (
      #|foo='bar
      #|cow 'arg
    ),
  )
  assert_ok("prop_readSingleQuoted6", "foo='bar cow 'arg")
  assert_word_ok("prop_readSingleQuoted7", "'foo\u201Cbar'")
  assert_word_warning("prop_readSingleQuoted8", "'foo\u2018bar'")

  assert_word_ok("prop_readBackTicked", "`ls *.mp3`")
  assert_word_ok("prop_readBackTicked2", "`grep \"\\\"\"`")
  assert_word_warning("prop_readBackTicked3", "\u00B4grep \"\\\"\"\u00B4")
  assert_ok(
    "prop_readBackTicked4",
    (
      #|`echo foo
      #|echo bar`
    ),
  )
  assert_ok("prop_readBackTicked5", "echo `foo`bar")
  assert_warning(
    "prop_readBackTicked6",
    (
      #|echo `foo
      #|echo `bar
    ),
  )
  assert_ok("prop_readBackTicked7", "`#inline comment`")
  assert_ok(
    "prop_readBackTicked8",
    (
      #|echo `#comment` \
      #|bar baz
    ),
  )

  assert_word_ok("prop_readDoubleQuoted", "\"Hello $FOO\"")
  assert_word_ok("prop_readDoubleQuoted2", "\"$'\"")
  assert_word_ok("prop_readDoubleQuoted3", "\"\u2018hello\u2019\"")
  assert_warning(
    "prop_readDoubleQuoted4",
    (
      #|"foo
      #|bar"foo
    ),
  )
  assert_ok(
    "prop_readDoubleQuoted5",
    (
      #|lol "foo
      #|bar" etc
    ),
  )
  assert_ok("prop_readDoubleQuoted6", "echo \"${ ls; }\"")
  assert_ok("prop_readDoubleQuoted7", "echo \"${ ls;}bar\"")
  assert_word_warning("prop_readDoubleQuoted8", "\"\u201Chello\u201D\"")
  assert_word_ok("prop_readDoubleQuoted10", "\"foo\\\\n\"")

  assert_word_ok("prop_readGlob1", "*")
  assert_word_ok("prop_readGlob2", "[^0-9]")
  assert_word_ok("prop_readGlob3", "[a[:alpha:]]")
  assert_word_ok("prop_readGlob4", "[[:alnum:]]")
  assert_word_ok("prop_readGlob5", "[^[:alpha:]1-9]")
  assert_word_ok("prop_readGlob6", "[\\|]")
  assert_word_ok("prop_readGlob7", "[^[]")
  assert_word_ok("prop_readGlob8", "[*?]")
  assert_word_ok("prop_readGlob9", "[!]^]")
  assert_word_ok("prop_readGlob10", "[]]")

  assert_word_ok("prop_readExtglob1", "!(*.mp3)")
  assert_word_ok("prop_readExtglob2", "!(*.mp3|*.wmv)")
  assert_word_ok("prop_readExtglob4", "+(foo \\) bar)")
  assert_word_ok("prop_readExtglob5", "+(!(foo *(bar)))")
  assert_word_ok("prop_readExtglob6", "*(((||))|())")
  assert_word_ok("prop_readExtglob7", "*(<>)")
  assert_word_ok("prop_readExtglob8", "@(|*())")

  assert_word_ok("prop_readDollarExpression1", "$(((1) && 3))")
  assert_word_warning("prop_readDollarExpression2", "$(((1)) && 3)")
  assert_word_warning("prop_readDollarExpression3", "$((\"$@\" &); foo;)")
  assert_word_ok("prop_readDollarSingleQuote", "$'foo\\\'lol'")
  assert_word_ok("prop_readDollarDoubleQuote", "$\"hello\"")
  assert_word_ok("prop_readDollarArithmetic", "$(( 3 * 4 +5))")
  assert_word_ok("prop_readDollarArithmetic2", "$(((3*4)+(1*2+(3-1))))")
  assert_ok("prop_readArithmeticExpression", "((a?b:c))")

  assert_word_ok("prop_readDollarBraceCommandExpansion1", "${ ls; }")
  assert_word_ok(
    "prop_readDollarBraceCommandExpansion2",
    (
      #|${
      #|ls
      #|}
    ),
  )
  assert_word_ok("prop_readDollarBraceCommandExpansion3", "${|  REPLY=42; }")
  assert_word_ok("prop_readDollarBraced1", "${foo//bar/baz}")
  assert_word_ok("prop_readDollarBraced2", "${foo/'{cow}'}")
  assert_word_ok("prop_readDollarBraced3", "${foo%%$(echo cow\\})}")
  assert_word_ok("prop_readDollarBraced4", "${foo#\\}}")
  assert_word_ok(
    "prop_readDollarExpansion1",
    (
      #|$(echo foo; ls
      #|)
    ),
  )
  assert_word_ok("prop_readDollarExpansion2", "$(  )")
  assert_word_ok(
    "prop_readDollarExpansion3",
    (
      #|$( command 
      #|#comment 
      #|)
    ),
  )
  assert_word_ok("prop_readDollarVariable", "$@")
  assert_word_ok("prop_readDollarVariable2", "$?!")
  assert_word_warning("prop_readDollarVariable3", "$10")
  assert_word_warning("prop_readDollarVariable4", "$arr[@]")
  assert_word_warning("prop_readDollarVariable5", "$arr[f")
  assert_word_warning("prop_readDollarLonely1", "\"$\"var")
  assert_word_warning("prop_readDollarLonely2", "\"$\"\"var\"")
  assert_word_ok("prop_readDollarLonely3", "\"$\"$var")
  assert_word_ok("prop_readDollarLonely4", "\"$\"*")
  assert_word_ok("prop_readDollarLonely5", "$\"str\"")
}

///|
test "shellcheck compatibility command and compound samples" {
  assert_ok("prop_readIoFile", ">> \"$(date +%YYmmDD)\"")
  assert_ok("prop_readIoRedirect", "3>&2")
  assert_ok("prop_readIoRedirect2", "2> lol")
  assert_ok("prop_readIoRedirect3", "4>&-")
  assert_ok("prop_readIoRedirect4", "&> lol")
  assert_ok("prop_readIoRedirect5", "{foo}>&2")
  assert_ok("prop_readIoRedirect6", "{foo}<&-")
  assert_ok("prop_readIoRedirect7", "{foo}>&1-")
  assert_ok("prop_readHereString", "<<< \"Hello $world\"")
  assert_ok("prop_readNewlineList1", "&> /dev/null echo foo")

  assert_warning("prop_readSeparator1", "a &; b")
  assert_ok("prop_readSeparator2", "a & b")
  assert_warning("prop_readSeparator3", "a &amp; b")
  assert_warning("prop_readSeparator4", "a &gt; file; b")
  assert_warning(
    "prop_readSeparator5", "curl https://example.com/?foo=moo&bar=cow",
  )

  assert_ok("prop_readSimpleCommand", "echo test > file")
  assert_ok("prop_readSimpleCommand2", "cmd &> file")
  assert_ok("prop_readSimpleCommand3", "export foo=(bar baz)")
  assert_ok("prop_readSimpleCommand4", "typeset -a foo=(lol)")
  assert_ok("prop_readSimpleCommand5", "time if true; then echo foo; fi")
  assert_ok("prop_readSimpleCommand6", "time -p ( ls -l; )")
  assert_ok("prop_readSimpleCommand7", "\\ls")
  assert_ok("prop_readSimpleCommand7b", "\\:")
  assert_warning("prop_readSimpleCommand8", "// Lol")
  assert_warning("prop_readSimpleCommand9", "/* Lolbert */")
  assert_warning("prop_readSimpleCommand10", "/**** Lolbert */")
  assert_ok("prop_readSimpleCommand11", "/\\* foo")
  assert_warning("prop_readSimpleCommand12", "elsif foo")
  assert_warning("prop_readSimpleCommand13", "ElseIf foo")
  assert_warning("prop_readSimpleCommand14", "elseif[$i==2]")
  assert_warning("prop_readSimpleCommand15", "trap 'foo\"bar' INT")

  assert_ok("prop_readPipeline", "! cat /etc/issue | grep -i ubuntu")
  assert_warning("prop_readPipeline2", "!cat /etc/issue | grep -i ubuntu")
  assert_ok("prop_readPipeline3", "for f; do :; done|cat")
  assert_ok("prop_readPipeline4", "! ! true")
  assert_ok("prop_readPipeline5", "true | ! true")

  assert_ok("prop_readAndOr", "grep -i lol foo || exit 1")
  assert_ok(
    "prop_readAndOr1",
    (
      #|# shellcheck disable=1
      #|foo
    ),
  )
  assert_ok(
    "prop_readAndOr2",
    (
      #|# shellcheck disable=1
      #|# lol
      #|# shellcheck disable=3
      #|foo
    ),
  )
  assert_ok("prop_readTerm", "time ( foo; bar; )")

  assert_ok(
    "prop_readIfClause", "if false; then foo; elif true; then stuff; more stuff; else cows; fi",
  )
  assert_warning("prop_readIfClause2", "if false; then; echo oo; fi")
  assert_warning(
    "prop_readIfClause3", "if false; then true; else; echo lol; fi",
  )
  assert_warning(
    "prop_readIfClause4", "if false; then true; else if true; then echo lol; fi; fi",
  )
  assert_ok(
    "prop_readIfClause5",
    (
      #|if false; then true; else
      #|if true; then echo lol; fi; fi
    ),
  )
  assert_warning(
    "prop_readIfClause6",
    (
      #|if true
      #|then
      #|Do the thing
      #|fi
    ),
  )

  assert_ok("prop_readSubshell", "( cd /foo; tar cf stuff.tar * )")
  assert_ok("brace group script with separators", "{ a; b | c | d; e; }")
  assert_warning("brace group script without required space", "{foo;}")
  assert_ok("brace group script with nested subshell", "{(foo)}")

  assert_ok(
    "bats script form 1",
    (
      #|@test 'can parse' {
      #|  true
      #|}
    ),
  )
  assert_ok(
    "bats script form 2",
    (
      #|@test random text !(@*$Y&! {
      #|  true
      #|}
    ),
  )
  assert_ok(
    "bats script form 3",
    (
      #|@test foo { bar { baz {
      #|  true
      #|}
    ),
  )
  assert_warning(
    "bats script form with newline body opener",
    (
      #|@test foo 
      #|{
      #| true
      #|}
    ),
  )

  assert_ok("prop_readWhileClause", "while [[ -e foo ]]; do sleep 1; done")
  assert_ok("prop_readUntilClause", "until kill -0 $PID; do sleep 1; done")
  assert_ok("prop_readSelectClause1", "select foo in *; do echo $foo; done")
  assert_ok("prop_readSelectClause2", "select foo; do echo $foo; done")
  assert_ok(
    "select newline separator without in",
    (
      #|select foo
      #|do echo $foo; done
    ),
  )

  assert_ok("prop_readCoProc1", "coproc foo { echo bar; }")
  assert_ok("prop_readCoProc2", "coproc { echo bar; }")
  assert_ok("prop_readCoProc3", "coproc echo bar")
  assert_ok("prop_readCoProc4", "coproc a=b echo bar")
  assert_ok("prop_readCoProc5", "coproc 'foo' { echo bar; }")
  assert_ok("prop_readCoProc6", "coproc \"foo$$\" { echo bar; }")
  assert_ok("prop_readCoProc7", "coproc 'foo' ( echo bar )")
  assert_ok("prop_readCoProc8", "coproc \"foo$$\" while true; do true; done")

  assert_ok("prop_readCompoundCommand", "{ echo foo; }>/dev/null")

  assert_ok("prop_readAssignmentWord", "a=42")
  assert_ok("prop_readAssignmentWord2", "b=(1 2 3)")
  assert_ok("prop_readAssignmentWord5", "b+=lol")
  assert_ok("prop_readAssignmentWord7", "a[3$n'']=42")
  assert_ok("prop_readAssignmentWord8", "a[4''$(cat foo)]=42")
  assert_ok("prop_readAssignmentWord9", "IFS= ")
  assert_ok("prop_readAssignmentWord9a", "foo=")
  assert_ok("prop_readAssignmentWord9b", "foo=  ")
  assert_ok("prop_readAssignmentWord9c", "foo=  #bar")
  assert_ok("prop_readAssignmentWord11", "foo=([a]=b [c] [d]= [e f )")
  assert_ok("prop_readAssignmentWord12", "a[b <<= 3 + c]='thing'")
  assert_ok("prop_readAssignmentWord13", "var=( (1 2) (3 4) )")
  assert_ok("prop_readAssignmentWord14", "var=( 1 [2]=(3 4) )")
  assert_ok("prop_readAssignmentWord15", "var=(1 [2]=(3 4))")
}
