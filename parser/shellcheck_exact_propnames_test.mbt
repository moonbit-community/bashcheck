///|
test "shellcheck exact arithmetic prop names" {
  let ok_cases : Array[(String, String)] = [
    ("prop_a1", "(( n++ + ++c ))"),
    ("prop_a2", "(( $N*4-(3,2) ))"),
    ("prop_a3", "(( n|=2<<1 ))"),
    ("prop_a4", "(( n &= 2 **3 ))"),
    ("prop_a5", "(( 1 |= 4 && n >>= 4 ))"),
    ("prop_a6", "(( 1 | 2 ||3|4 ))"),
    ("prop_a7", "(( 3*2**10 ))"),
    ("prop_a8", "(( 3 ))"),
    ("prop_a9", "(( a^!-b ))"),
    ("prop_a10", "(( ! $? ))"),
    ("prop_a11", "(( 10#08 * 16#f ))"),
    ("prop_a12", "(( \"$((3+2))\" + '37' ))"),
    ("prop_a13", "(( foo[9*y+x]++ ))"),
    ("prop_a14", "(( 1+`echo 2` ))"),
    ("prop_a15", "(( foo[`echo foo | sed s/foo/4/g` * 3] + 4 ))"),
    ("prop_a16", "(( $foo$bar ))"),
    ("prop_a17", "(( i<(0+(1+1)) ))"),
    ("prop_a18", "(( a?b:c ))"),
    ("prop_a19", "(( \\\n3 +\\\n  2 ))"),
    ("prop_a20", "(( a ? b ? c : d : e ))"),
    ("prop_a21", "(( a ? b : c ? d : e ))"),
    ("prop_a22", "(( !!a ))"),
    ("prop_a23", "(( ~0 ))"),
  ]
  for case_ in ok_cases {
    assert_ok(case_.0, case_.1)
  }
}

///|
test "shellcheck exact condition prop names" {
  let ok_cases : Array[(String, String)] = [
    ("prop_readCondition", "[ \\( a = b \\) -a \\( c = d \\) ]"),
    ("prop_readCondition2", "[[ (a = b) || (c = d) ]]"),
    ("prop_readCondition3", "[[ $c = [[:alpha:].~-] ]]"),
    ("prop_readCondition4", "[[ $c =~ *foo* ]]"),
    ("prop_readCondition5", "[[ $c =~ f( ]] )* ]]"),
    ("prop_readCondition5a", "[[ $c =~ a(b) ]]"),
    ("prop_readCondition5b", "[[ $c =~ f( ($var ]]) )* ]]"),
    ("prop_readCondition6", "[[ $c =~ ^[yY]$ ]]"),
    ("prop_readCondition7", "[[ ${line} =~ ^[[:space:]]*# ]]"),
    ("prop_readCondition8", "[[ $l =~ ogg|flac ]]"),
    ("prop_readCondition9", "[ foo -a -f bar ]"),
    ("prop_readCondition10", "[[\na == b\n||\nc == d ]]"),
    ("prop_readCondition10a", "[[\na == b  ||\nc == d ]]"),
    ("prop_readCondition10b", "[[ a == b\n||\nc == d ]]"),
    ("prop_readCondition11", "[[ a == b ||\n c == d ]]"),
    ("prop_readCondition13", "[[ foo =~ ^fo{1,3}$ ]]"),
    ("prop_readCondition14", "[ foo '>' bar ]"),
    ("prop_readCondition15", "[ foo \">=\" bar ]"),
    ("prop_readCondition16", "[ foo \\< bar ]"),
    ("prop_readCondition17", "[[ ${file::1} = [-.\\|/\\\\] ]]"),
    ("prop_readCondition18", "[ ]"),
    ("prop_readCondition19", "[ '(' x \")\" ]"),
    ("prop_readCondition20", "[[ echo_rc -eq 0 ]]"),
    ("prop_readCondition21", "[[ $1 =~ ^(a\\ b)$ ]]"),
    ("prop_readCondition22", "[[ $1 =~ \\.a\\.(\\.b\\.)\\.c\\. ]]"),
    ("prop_readCondition23", "[[ -v arr[$var] ]]"),
    ("prop_readCondition25", "[[ lex.yy.c -ot program.l ]]"),
    ("prop_readCondition26", "[[ foo ]]\\\n && bar"),
    ("prop_readCondition28", "[[ x = [\"$1\"] ]]"),
    ("prop_readCondition29", "[[ x = [*] ]]"),
    ("prop_readConditionCommand", "[[ x ]] > foo 2>&1"),
  ]
  for case_ in ok_cases {
    assert_ok(case_.0, case_.1)
  }

  assert_warning("prop_readCondition12", "[ a == b \n -o c == d ]")
  assert_warning("prop_readCondition27", "[[ x ]] foo")
}

///|
test "shellcheck exact case and for prop names" {
  let ok_cases : Array[(String, String)] = [
    ("prop_readCaseClause", "case foo in a ) lol; cow;; b|d) fooo; esac"),
    ("prop_readCaseClause2", "case foo\n in * ) echo bar;; esac"),
    ("prop_readCaseClause3", "case foo\n in * ) echo bar & ;; esac"),
    ("prop_readCaseClause4", "case foo\n in *) echo bar ;& bar) foo; esac"),
    ("prop_readCaseClause5", "case foo\n in *) echo bar;;& foo) baz;; esac"),
    ("prop_readCaseClause6", "case foo\n in if) :;; done) :;; esac"),
    ("prop_readForClause", "for f in *; do rm \"$f\"; done"),
    ("prop_readForClause1", "for f in *; { rm \"$f\"; }"),
    ("prop_readForClause3", "for f; do foo; done"),
    ("prop_readForClause4", "for((i=0; i<10; i++)); do echo $i; done"),
    (
      "prop_readForClause5", "for ((i=0;i<10 && n>x;i++,--n))\ndo \necho $i\ndone",
    ),
    ("prop_readForClause6", "for ((;;))\ndo echo $i\ndone"),
    ("prop_readForClause7", "for ((;;)) do echo $i\ndone"),
    ("prop_readForClause8", "for ((;;)) ; do echo $i\ndone"),
    ("prop_readForClause9", "for i do true; done"),
    ("prop_readForClause10", "for ((;;)) { true; }"),
    ("prop_readForClause13", "for foo\nin\\\n  bar\\\n  baz\ndo true; done"),
  ]
  for case_ in ok_cases {
    assert_ok(case_.0, case_.1)
  }

  assert_warning("prop_readForClause12", "for $a in *; do echo \"$a\"; done")
}

///|
test "shellcheck exact heredoc prop names" {
  let ok_cases : Array[(String, String)] = [
    ("prop_readHereDoc", "cat << foo\nlol\ncow\nfoo"),
    ("prop_readHereDoc3", "cat << foo\n$\"\nfoo"),
    ("prop_readHereDoc5", "cat <<- !foo\nbar\n!foo"),
    ("prop_readHereDoc6", "cat << foo\\ bar\ncow\nfoo bar"),
    ("prop_readHereDoc7", "cat << foo\n\\$(f ())\nfoo"),
    ("prop_readHereDoc8", "cat <<foo>>bar\netc\nfoo"),
    ("prop_readHereDoc9", "if true; then cat << foo; fi\nbar\nfoo\n"),
    ("prop_readHereDoc10", "if true; then cat << foo << bar; fi\nfoo\nbar\n"),
    ("prop_readHereDoc11", "cat << foo $(\nfoo\n)lol\nfoo\n"),
    ("prop_readHereDoc12", "cat << foo|cat\nbar\nfoo"),
    ("prop_readHereDoc13", "cat <<'#!'\nHello World\n#!\necho Done"),
    ("prop_readHereDoc16", "cat <<- ' foo'\nbar\n foo\n"),
    ("prop_readHereDoc18", "cat <<'\"foo'\nbar\n\"foo\n"),
    (
      "prop_readHereDoc21", "# shellcheck disable=SC1039\ncat << foo\n  foo\n()\nfoo\n",
    ),
  ]
  for case_ in ok_cases {
    assert_ok(case_.0, case_.1)
  }

  let warning_cases : Array[(String, String)] = [
    ("prop_readHereDoc14", "cat << foo\nbar\nfoo \n"),
    ("prop_readHereDoc15", "cat <<foo\nbar\nfoo bar\nfoo"),
    ("prop_readHereDoc17", "cat <<- ' foo'\nbar\n  foo\n foo\n"),
    ("prop_readHereDoc20", "cat << foo\n  foo\n()\nfoo\n"),
    ("prop_readHereDoc22", "cat << foo\r\ncow\r\nfoo\r\n"),
  ]
  for case_ in warning_cases {
    assert_warning(case_.0, case_.1)
  }

  let not_ok_cases : Array[(String, String)] = [
    ("prop_readHereDoc23", "cat << foo \r\ncow\r\nfoo\r\n"),
  ]
  for case_ in not_ok_cases {
    assert_not_ok(case_.0, case_.1)
  }

  let warning_cases_2 : Array[(String, String)] = [
    ("prop_readHereDoc2", "cat <<- EOF\n  cow\n  EOF"),
    ("prop_readHereDoc4", "cat << foo\n`\nfoo"),
  ]
  for case_ in warning_cases_2 {
    assert_warning(case_.0, case_.1)
  }
}
