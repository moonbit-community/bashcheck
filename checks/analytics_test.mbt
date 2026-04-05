///|
test "analytics checks flag backticks and unquoted command substitutions" {
  let diagnostics = check_source("echo `foo`\nrm $(ls)\n")

  assert_true(has_code(diagnostics, 2006))
  assert_true(has_code(diagnostics, 2046))
}

///|
test "analytics checks attach fixes for backticks" {
  let source = "echo `printf '%s' \"$x\"`/`date +%F`\n"
  let diagnostic = first_code(check_source(source), 2006)

  match diagnostic.fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some("echo $(printf '%s' \"$x\")/$(date +%F)\n"),
      )
    None => checks_fail("expected SC2006 fix")
  }
}

///|
test "analytics checks flag fragile for-in forms and ls/find substitutions" {
  let diagnostics = check_source(
    "for f in \"$(ls)\"; do :; done\nfor g in ls; do :; done\nfor h in $(ls *.mp3); do :; done\nfor i in $(find / -name '*.mp3'); do :; done\n",
  )

  assert_true(has_code(diagnostics, 2066))
  assert_true(has_code(diagnostics, 2043))
  assert_true(has_code(diagnostics, 2045))
  assert_true(has_code(diagnostics, 2044))
}

///|
test "analytics checks flag unquoted star and array expansions" {
  let diagnostics = check_source("printf '%s\\n' $@ ${arr[@]} ${*} ${arr[*]}\n")

  assert_true(count_code(diagnostics, 2068) >= 2)
  assert_true(count_code(diagnostics, 2048) >= 2)
}

///|
test "analytics checks flag single and double bracket operator misuse" {
  let diagnostics = check_source(
    "#!/bin/bash\n[ test =~ foo ]\n[[ 3 \\< 4 ]]\n",
  )

  assert_true(has_code(diagnostics, 2074))
  assert_true(has_code(diagnostics, 2075))
}

///|
test "analytics checks allow native double bracket angle operators" {
  let diagnostics = check_source("#!/bin/bash\n[[ a < b ]]\n[[ c > d ]]\n")
  assert_true(!has_code(diagnostics, 2075))
}

///|
test "analytics optional checks flag useless use of cat" {
  let script = parse_checks_ok("cat foo | grep bar\ncat \"$var\" | grep bar\n")
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
    "cat * | grep bar\ncat $var | grep bar\ncat \"${!var}\" | grep bar\ncat \"$@\" | grep bar\ncat -n | grep bar\n",
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
    "case $1 in a) true ;; ?*?) true ;; *?) true ;; esac\n",
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
  let script = parse_checks_ok("case $1 in x|*) true ;; **) true ;; esac\n")
  let diagnostics = check_script(
    script,
    options=CheckOptions::default().with_optional_checks(["add-default-case"]),
  )

  assert_true(!has_code(diagnostics, 2249))
}

///|
test "analytics checks flag assignment misuse patterns" {
  let diagnostics = check_source(
    "foo=bar | grep x\nout=ls -l\nprefix=hello printf '%s\\n' \"$prefix\"\nsame=\"$same\"\n",
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
    "foo=bar\nvalue=$(echo \"$value\") cmd\nsame=$other\n",
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
    "#!/bin/bash\n[ foo -a -f bar ]\n[ -z 3 -o a = b ]\n[[ $foo =~ 'cow|bar' ]]\n",
  )

  assert_eq(count_code(diagnostics, 2166), 2)
  assert_true(has_code(diagnostics, 2076))
}

///|
test "analytics checks avoid literal regex false positives" {
  let diagnostics = check_source("#!/bin/bash\n[[ $foo =~ \"bar\" ]]\n")

  assert_true(!has_code(diagnostics, 2076))
}

///|
test "analytics checks flag array splitting loop globs and subshell tests" {
  let diagnostics = check_source(
    "arr=( $var $(cmd) )\nfor file in $dir/*.txt; do :; done\n( -e file )\n( 1 -gt 2 )\n",
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
    "arr=( \"$var\" \"$(cmd)\" $! $$ $# ${#arr[@]} * foo{1,2} )\nfor file in \"$dir\"/*.txt; do :; done\n( grep -c foo bar )\n",
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
    "#!/bin/bash\n[[ $cow == $bar ]]\n[ $cow = *foo* ]\n[[ $foo =~ *foo* ]]\nif [ ]; then :; fi\n",
  )

  assert_true(has_code(diagnostics, 2053))
  assert_true(has_code(diagnostics, 2081))
  assert_true(has_code(diagnostics, 2049))
  assert_true(has_code(diagnostics, 2212))
}

///|
test "analytics batch b checks keep regex and comparison false positives in check" {
  let diagnostics = check_source(
    "#!/bin/bash\n[[ $cow == \"$bar\" ]]\n[ $cow = foo ]\n[[ $foo =~ ^c.* ]]\n[[ $foo =~ x\\* ]]\n",
  )

  assert_true(!has_code(diagnostics, 2053))
  assert_true(!has_code(diagnostics, 2081))
  assert_true(!has_code(diagnostics, 2049))

  let busybox = run_checks_with_shell(
    parse_checks_ok("[[ $f == *foo* ]]\n"),
    @semantics.ShellDialect::BusyboxSh,
    false,
    [],
  )
  assert_true(has_code(busybox, 2330))
}

///|
test "analytics batch b checks flag redirect and command target confusion" {
  let diagnostics = check_source(
    "test 3 > 1\n/usr/bin/test $var > $foo\nfoo 1>2\nls > rm\n",
  )

  assert_eq(count_code(diagnostics, 2065), 2)
  assert_true(has_code(diagnostics, 2210))
  assert_true(has_code(diagnostics, 2238))
}

///|
test "analytics batch b checks avoid redirect target false positives" {
  let diagnostics = check_source(
    "test 1 -eq 2 2> file\necho foo > '2'\nls > myfile\n",
  )

  assert_true(!has_code(diagnostics, 2065))
  assert_true(!has_code(diagnostics, 2210))
  assert_true(!has_code(diagnostics, 2238))
}

///|
test "analytics batch b checks flag arithmetic and malformed command names" {
  let diagnostics = check_source(
    "./ file\nfoo=bar * 2\nn=2\ni=n*2\nfoo*\n-e file\n''\n/\nfoo,\n",
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
    "./file\necho foo*\n'--myexec--' args\n. foo.sh\n: foo\n",
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
    "out=$(foo > log)\nerr=$(foo >&2)\nkeep=$(foo 2>&1 > /dev/null)\n",
  )

  assert_eq(count_code(diagnostics, 2327), 2)
  assert_eq(count_code(diagnostics, 2328), 2)
}

///|
test "analytics batch c checks flag echo-wc ssh heredoc and late function definitions" {
  let diagnostics = check_source(
    "#!/bin/bash\n# shellcheck disable=SC2154\necho \"$foo\" | wc -c\nssh host <<EOF2\necho $HOME\nEOF2\nf\nf() { true; }\n",
  )

  assert_true(has_code(diagnostics, 2000))
  assert_true(has_code(diagnostics, 2087))
  assert_true(has_code(diagnostics, 2218))
}

///|
test "analytics batch c checks flag overwritten exit codes" {
  let diagnostics = check_source(
    "#!/bin/bash\nx(){ return 1; }\nx\n[ $? -eq 1 ] || [ $? -eq 2 ]\necho \"$?\"\necho \"$?\"\n",
  )

  assert_eq(count_code(diagnostics, 2319), 1)
  assert_eq(count_code(diagnostics, 2320), 1)
}

///|
test "analytics batch c checks avoid false positives for quiet cases" {
  let diagnostics = check_source(
    "#!/bin/bash\nfoo=bar\nprintf '%s\\n' \"$foo\" | wc -c\nssh host <<'EOF'\necho $HOME\nEOF\nf() { true; }\nf\nfalse\nstatus=$?\necho \"$status\"\n",
  )

  assert_true(!has_code(diagnostics, 2000))
  assert_true(!has_code(diagnostics, 2087))
  assert_true(!has_code(diagnostics, 2218))
  assert_true(!has_code(diagnostics, 2319))
  assert_true(!has_code(diagnostics, 2320))
}

///|
test "analytics optional checks flag quote-safe variables only for clean standalone words" {
  let source = "safe=hello\necho $safe\nunsafe='hi there'\necho $unsafe\n"
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
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some("safe=hello\necho \"$safe\"\nunsafe='hi there'\necho $unsafe\n"),
      )
    None => checks_fail("expected SC2248 fix")
  }
}

///|
test "analytics optional checks flag nullary and negated conditions" {
  let diagnostics = check_script(
    parse_checks_ok(
      "[ \"$name\" ]\n[[ $(cmd) ]]\n[[ \"$a$b\" ]]\n[[ -n \"$a\" ]]\n[ ! -z \"$var\" ]\n! [ -n \"$var\" ]\n[[ ! $var == foo ]]\n! [[ $var -gt 3 ]]\n! [[ $var =~ .* ]]\n",
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
test "analytics optional checks require braces for bare variable references" {
  let source = "echo $name\nprintf '%s' prefix=$name\nprintf '%s' \"$name\"\n$tool=42\n"
  let diagnostics = check_script(
    parse_checks_ok(source),
    options=CheckOptions::default().with_optional_checks([
      "require-variable-braces",
    ]),
  )

  assert_eq(count_code(diagnostics, 2250), 2)
  let diagnostic = first_code(diagnostics, 2250)
  match diagnostic.fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          "echo ${name}\nprintf '%s' prefix=$name\nprintf '%s' \"$name\"\n$tool=42\n",
        ),
      )
    None => checks_fail("expected SC2250 fix on bare variable word")
  }
}

///|
test "analytics optional checks extend unassigned-variable warnings to uppercase names" {
  let diagnostics = check_script(
    parse_checks_ok("echo $VAR\necho $foo\n"),
    options=CheckOptions::default().with_optional_checks([
      "check-unassigned-uppercase",
    ]),
  )

  assert_eq(count_code(diagnostics, 2154), 1)
  assert_true(first_code(diagnostics, 2154).message.contains("VAR"))
}

///|
test "analytics optional checks require double brackets only in supporting shells" {
  let script = parse_checks_ok("[ -x foo ]\n[[ -x foo ]]\n")
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
test "analytics optional checks flag set-e suppression contexts for functions" {
  let diagnostics = run_checks_with_shell(
    parse_checks_ok(
      "#!/bin/bash\nset -e\nf(){ false; }\nresult=$(f)\nf && echo ok\nif f; then :; fi\nwhile f; do :; done\n! f\nfoo=$(set -e; f)\n",
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
      "false | true\ntrue $(false)\nx=$(false)$(true)\nreadarray -t files < <(ls)\nx=$(false)true\necho asdf | false\n",
    ),
    options=CheckOptions::default().with_optional_checks([
      "check-extra-masked-returns",
    ]),
  )

  assert_eq(count_code(diagnostics, 2312), 4)
}
