///|
test "command checks flag read without r and allow explicit raw reads" {
  let plain = check_source("read foo\n")
  assert_true(has_code(plain, 2162))

  let with_r = check_source("read -r foo\n")
  assert_true(!has_code(with_r, 2162))
}

///|
test "command checks attach fixes for read without r" {
  let source = "builtin read foo\nread<file\n"
  let diagnostics = check_source(source)
  let read_diagnostics = diagnostics.filter(fn(diagnostic) {
    diagnostic.code == 2162
  })
  assert_eq(read_diagnostics.length(), 2)

  match read_diagnostics[0].fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some("builtin read -r foo\nread<file\n"),
      )
    None => checks_fail("expected SC2162 fix on wrapped read")
  }

  match read_diagnostics[1].fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some("builtin read foo\nread -r<file\n"),
      )
    None => checks_fail("expected SC2162 fix on redirected read")
  }
}

///|
test "command checks allow poll-style read invocations" {
  let diagnostics = check_source("read -u 3 -t 0\n")
  assert_true(!has_code(diagnostics, 2162))
}

///|
test "command checks keep parsing read options after delimiter arguments" {
  let diagnostics = check_source("read -d '' -r foo\n")
  assert_true(!has_code(diagnostics, 2162))
}

///|
test "command checks flag useless echo substitutions" {
  let diagnostics = check_source(
    "echo $(date)\necho `date`\necho \"$(date)\"\n",
  )

  assert_eq(count_code(diagnostics, 2005), 3)
  assert_eq(
    first_code(diagnostics, 2005).message,
    "Useless echo? Instead of 'echo $(cmd)', just use 'cmd'.",
  )
}

///|
test "command checks avoid false positives for non-trivial echo substitutions" {
  let diagnostics = check_source(
    "echo \"The time is $(date)\"\necho \"$(<file)\"\n",
  )

  assert_true(!has_code(diagnostics, 2005))
}

///|
test "command checks flag find invocations without an explicit path" {
  let diagnostics = check_source("find -type f\nfind\n")

  assert_eq(count_code(diagnostics, 2185), 2)
  assert_eq(
    first_code(diagnostics, 2185).message,
    "Some finds don't have a default path. Specify '.' explicitly.",
  )
}

///|
test "command checks allow find invocations with explicit paths or help" {
  let diagnostics = check_source(
    "find . -type f\nfind -H -L \"$path\" -print\nfind --help\nfind -D exec .\n",
  )

  assert_true(!has_code(diagnostics, 2185))
}

///|
test "command checks flag deprecated grep variants" {
  let diagnostics = check_source("egrep '.+'\n/usr/bin/fgrep '*' files\n")

  assert_true(has_code(diagnostics, 2196))
  assert_true(has_code(diagnostics, 2197))
  assert_eq(
    first_code(diagnostics, 2196).message,
    "egrep is non-standard and deprecated. Use grep -E instead.",
  )
  assert_eq(
    first_code(diagnostics, 2197).message,
    "fgrep is non-standard and deprecated. Use grep -F instead.",
  )
}

///|
test "command checks allow modern grep forms" {
  let diagnostics = check_source("grep -E '.+'\ngrep -F '*' files\n")
  assert_true(!has_code(diagnostics, 2196))
  assert_true(!has_code(diagnostics, 2197))
}

///|
test "command checks flag shell time flags unless command time is explicit" {
  let bash_diagnostics = check_source("time -f '%E' sleep 1\n")
  assert_true(has_code(bash_diagnostics, 2023))

  let direct = check_source("command time -f '%E' sleep 1\n")
  assert_true(!has_code(direct, 2023))

  let dash = check_source("#!/bin/dash\ntime -f '%E' sleep 1\n")
  assert_true(!has_code(dash, 2023))
}

///|
test "command checks flag sudo redirects that sudo does not affect" {
  let diagnostics = check_source(
    "sudo echo 3 > /proc/file\nsudo cmd < input\nsudo cmd >> file\nsudo cmd &> file\n",
  )

  assert_eq(count_code(diagnostics, 2024), 4)
}

///|
test "command checks allow stderr-only and dev-null sudo redirects" {
  let diagnostics = check_source(
    "sudo cmd 2>&1\nsudo cmd 2> log\nsudo cmd > /dev/null 2>&1\n",
  )

  assert_true(!has_code(diagnostics, 2024))
}

///|
test "command checks flag deprecated tempfile utility" {
  let diagnostics = check_source("tempfile\n/usr/bin/tempfile\n")
  assert_eq(count_code(diagnostics, 2186), 2)
  assert_eq(
    first_code(diagnostics, 2186).message,
    "tempfile is deprecated. Use mktemp instead.",
  )
}

///|
test "command optional checks flag deprecated which" {
  let script = parse_checks_ok("which bash\n/usr/bin/which awk\n")
  let diagnostics = check_script(
    script,
    options=CheckOptions::default().with_optional_checks(["deprecate-which"]),
  )

  assert_eq(count_code(diagnostics, 2230), 2)
  assert_eq(
    first_code(diagnostics, 2230).message,
    "'which' is non-standard. Use builtin 'command -v' instead.",
  )
}

///|
test "command optional checks allow modern command -v lookups" {
  let script = parse_checks_ok("command -v bash\n")
  let diagnostics = check_script(
    script,
    options=CheckOptions::default().with_optional_checks(["deprecate-which"]),
  )
  assert_true(!has_code(diagnostics, 2230))
}

///|
test "command checks flag tr globs ranges duplicate sets and bracket classes" {
  let diagnostics = check_source(
    "tr [a-f] [A-F]\ntr 'a-z' 'A-Z'\ntr foo bar\ntr '[a-z]' '[A-Z]'\n",
  )

  assert_eq(count_code(diagnostics, 2060), 2)
  assert_true(has_code(diagnostics, 2018))
  assert_true(has_code(diagnostics, 2019))
  assert_true(has_code(diagnostics, 2020))
  assert_eq(count_code(diagnostics, 2021), 2)
}

///|
test "command checks avoid false positives for sensible tr usage" {
  let diagnostics = check_source(
    "tr -d '[:lower:]'\ntr aeiou _____\ntr --squeeze-repeats rl lr\ntr abc '[d*]'\ntr '[=e=]' 'e'\n",
  )

  assert_true(!has_code(diagnostics, 2060))
  assert_true(!has_code(diagnostics, 2018))
  assert_true(!has_code(diagnostics, 2019))
  assert_true(!has_code(diagnostics, 2020))
  assert_true(!has_code(diagnostics, 2021))
}

///|
test "command checks flag the Phase 4 find family" {
  let diagnostics = check_source(
    "find / -name *.php\nfind . -exec 'cat {} | wc -l' \\;\nfind . -exec sh -c 'echo {}' \\;\nfind . -name '*.wav' -o -name '*.au' -exec rm {} +\nfind . -exec echo {} > file \\;\n",
  )

  assert_true(has_code(diagnostics, 2061))
  assert_true(has_code(diagnostics, 2150))
  assert_true(has_code(diagnostics, 2156))
  assert_true(has_code(diagnostics, 2146))
  assert_true(has_code(diagnostics, 2227))
}

///|
test "command checks avoid false positives for safe find patterns" {
  let diagnostics = check_source(
    "find * -name '*.php'\nfind . -exec wc -l {} \\;\nfind . -ok sh -c 'rm \"$@\"' _ {} \\;\nfind . -name '*.wav' -o \\( -name '*.au' -exec rm {} + \\)\nfind . -exec echo {} \\; > file\n",
  )

  assert_true(!has_code(diagnostics, 2061))
  assert_true(!has_code(diagnostics, 2150))
  assert_true(!has_code(diagnostics, 2156))
  assert_true(!has_code(diagnostics, 2146))
  assert_true(!has_code(diagnostics, 2227))
}

///|
test "command checks flag expr pitfalls and modern replacements" {
  let diagnostics = check_source(
    "expr 3 + 2\nexpr match foo bar\nexpr foo : fo*\nexpr 1 * 2\nexpr 5 -3\n",
  )

  assert_true(has_code(diagnostics, 2003))
  assert_true(has_code(diagnostics, 2308))
  assert_true(has_code(diagnostics, 2305))
  assert_true(has_code(diagnostics, 2304))
  assert_true(has_code(diagnostics, 2307))
}

///|
test "command checks allow expr forms that may intentionally split or expand" {
  let diagnostics = check_source(
    "expr \"$@\"\nexpr 5 $rest\nexpr foo \\< regex\n",
  )

  assert_true(!has_code(diagnostics, 2305))
  assert_true(!has_code(diagnostics, 2306))
  assert_true(!has_code(diagnostics, 2307))
}

///|
test "command checks flag grep glob confusion and regex wildcard pitfalls" {
  let diagnostics = check_source(
    "grep *.mp3 file\ngrep '*foo*' file\ngrep 'cow*test' file\ngrep -- 'Foo*' file\n",
  )

  assert_true(has_code(diagnostics, 2062))
  assert_true(has_code(diagnostics, 2063))
  assert_true(has_code(diagnostics, 2022))
}

///|
test "command checks allow grep regexes and fixed string modes" {
  let diagnostics = check_source(
    "grep foo *.mp3\ngrep '[0-9]*' file\ngrep '^aa*' file\ngrep -F 'Foo*' file\ngrep --include=*.png foo\n",
  )

  assert_true(!has_code(diagnostics, 2062))
  assert_true(!has_code(diagnostics, 2063))
}

///|
test "command checks flag trap quotes that expand too early" {
  let diagnostics = check_source(
    "trap \"echo $num\" INT\ntrap \"echo `ls`\" INT\ntrap 'echo $num' INT\n",
  )

  assert_eq(count_code(diagnostics, 2064), 2)
}

///|
test "command checks validate return and exit status arguments" {
  let diagnostics = check_source(
    "return -1\nreturn 1 2\nreturn $var\nexit 1000\nexit 1 2\nexit $((a|b))\n",
  )

  assert_true(has_code(diagnostics, 2151))
  assert_true(has_code(diagnostics, 2152))
  assert_true(has_code(diagnostics, 2241))
  assert_true(has_code(diagnostics, 2242))
  assert_eq(count_code(diagnostics, 2152), 1)
  assert_eq(count_code(diagnostics, 2242), 1)
}

///|
test "command checks validate printf format usage and argument counts" {
  let diagnostics = check_source(
    "printf foo bar\nprintf '%s %s' 1\nprintf \"$fmt\" foo\nprintf '%(%s)T'\n",
  )

  assert_true(has_code(diagnostics, 2182))
  assert_true(has_code(diagnostics, 2183))
  assert_true(has_code(diagnostics, 2059))
  assert_eq(count_code(diagnostics, 2183), 1)
}

///|
test "command checks allow valid printf arity and special forms" {
  let diagnostics = check_source(
    "printf '%s %s' 1 2\nprintf '%s %s' \"$@\"\nprintf -v out '%s' 1\nprintf '%(%s)T' -1\n",
  )

  assert_true(!has_code(diagnostics, 2182))
  assert_true(!has_code(diagnostics, 2183))
}

///|
test "command checks flag source args sudo builtins and read expansions" {
  let diagnostics = check_source(
    "#!/bin/sh\n. script arg\nsudo cd /root\nsudo export x=3\nread $var\nread -a \"$arr\"\nread arr[val]\n",
  )

  assert_true(has_code(diagnostics, 2240))
  assert_eq(count_code(diagnostics, 2232), 2)
  assert_eq(count_code(diagnostics, 2229), 2)
  assert_true(has_code(diagnostics, 2313))
}

///|
test "command checks avoid false positives for source sudo and read option arguments" {
  let diagnostics = check_source(
    "#!/bin/bash\n. script arg\nsudo -n -u export ls\nsudo docker export foo\nread -p \"$var\"\nread -rd \"$delim\" name\nread ${var?}\nread $1\n",
  )

  assert_true(!has_code(diagnostics, 2240))
  assert_true(!has_code(diagnostics, 2232))
  assert_true(!has_code(diagnostics, 2229))
  assert_true(!has_code(diagnostics, 2313))
}

///|
test "command checks flag alias pitfalls from phase 5" {
  let diagnostics = check_source(
    "alias a='cp $1 /a'\nalias a=\"echo \\${@}\"\nalias foo=\"echo $PWD\"\n",
  )

  assert_eq(count_code(diagnostics, 2142), 2)
  assert_eq(count_code(diagnostics, 2139), 1)
  assert_eq(
    first_code(diagnostics, 2142).message,
    "Aliases can't use positional parameters. Use a function.",
  )
  assert_eq(
    first_code(diagnostics, 2139).message,
    "This expands when defined, not when used. Consider escaping.",
  )
}

///|
test "command checks avoid false positives for harmless alias forms" {
  let diagnostics = check_source(
    "alias $1='foo'\nalias -p\nalias foo='echo {1..10}'\nalias foo='echo $PWD'\n",
  )

  assert_true(!has_code(diagnostics, 2142))
  assert_eq(count_code(diagnostics, 2139), 1)
}

///|
test "command checks validate while getopts case coverage" {
  let diagnostics = check_source(
    "while getopts 'a:b' x; do case $x in a) foo;; esac; done\nwhile getopts 'a:' x; do case $x in a) foo;; b) bar;; esac; done\n",
  )

  assert_true(has_code(diagnostics, 2213))
  assert_true(has_code(diagnostics, 2214))
  assert_eq(count_code(diagnostics, 2220), 2)
  assert_eq(
    first_code(diagnostics, 2213).message,
    "getopts specified -b, but it's not handled by this 'case'.",
  )
  assert_eq(
    first_code(diagnostics, 2220).message,
    "Invalid flags are not handled. Add a *) case.",
  )
}

///|
test "command checks avoid false positives for valid while getopts patterns" {
  let diagnostics = check_source(
    "while getopts 'a:b' x; do case $x in a) foo;; b) bar;; *) :;; esac; done\nwhile getopts 'a:123' x; do case $x in a) foo;; [0-9]) bar;; esac; done\nwhile getopts 'a:' x; do case $x in a) foo;; \\?) bar;; *) baz;; esac; done\nwhile getopts 'a:b' x; do case $y in a) foo;; esac; done\nwhile getopts 'a:b' x; do case x$x in xa) foo;; xb) foo;; esac; done\nwhile getopts 'a:b' x; do x=a; case $x in a) foo;; esac; done\n",
  )

  assert_true(!has_code(diagnostics, 2213))
  assert_true(!has_code(diagnostics, 2214))
  assert_true(!has_code(diagnostics, 2220))
}

///|
test "command checks flag phase 5 command option and argument shape issues" {
  let diagnostics = check_source(
    "#!/bin/bash\nlet a=1\nmv 'foo bar'\ncp 'foo bar'\nln 'foo bar'\nchmod -r 0755 dir\nxargs -i{} echo {}\nalias x =0\nlet x = 0\nexport a +=b\n",
  )

  assert_true(has_code(diagnostics, 2219))
  assert_true(has_code(diagnostics, 2224))
  assert_true(has_code(diagnostics, 2225))
  assert_true(has_code(diagnostics, 2226))
  assert_true(has_code(diagnostics, 2253))
  assert_true(has_code(diagnostics, 2267))
  assert_eq(count_code(diagnostics, 2290), 3)
}

///|
test "command checks avoid false positives for phase 5 option parsing" {
  let diagnostics = check_source(
    "#!/bin/sh\nlet a=1\nmv foo bar\nmv \"$@\"\nmv -t foo bar\nmv --target-directory=foo bar\nmv --target-direc=foo bar\nmv --version\nmv \"${!var}\"\ncp foo bar\ncp -t dest foo\nln foo bar\nln -t dest foo\nchmod -R 0755 dir\nchmod a-r dir\nxargs -I{} echo {}\nxargs sed -i -e foo\nxargs -x sed -i foo\nalias x=0\nexport a+=b\neval \"$*\"\neval \"${args[*]@Q}\"\n",
  )

  assert_true(!has_code(diagnostics, 2219))
  assert_true(!has_code(diagnostics, 2224))
  assert_true(!has_code(diagnostics, 2225))
  assert_true(!has_code(diagnostics, 2226))
  assert_true(!has_code(diagnostics, 2253))
  assert_true(!has_code(diagnostics, 2267))
  assert_true(!has_code(diagnostics, 2290))
  assert_true(!has_code(diagnostics, 2293))
  assert_true(!has_code(diagnostics, 2294))
}

///|
test "command checks flag eval array pitfalls" {
  let diagnostics = check_source(
    "eval $@\neval \"${args[@]}\"\neval \"${args[@]@Q}\"\n",
  )

  assert_eq(count_code(diagnostics, 2294), 2)
  assert_eq(count_code(diagnostics, 2293), 1)
  assert_eq(
    first_code(diagnostics, 2293).message,
    "When eval'ing @Q-quoted words, use * rather than @ as the index.",
  )
}

///|
test "command checks flag phase 4 command-specialized families" {
  let diagnostics = check_source(
    "#!/bin/bash\n# shellcheck disable=SC2154,SC2086,SC2034,SC2329\nmkdir -p -m 0755 a/b\nsu foo\nssh host \"echo $PS1\"\nset foo 42\nexport $foo\nunset foo[1]\nrm -rf /home\nrm -r $1/$2\necho foo         bar\nq() { local readonly var=1; }\nq2() { local x=1 y=$x; }\n",
  )

  assert_true(has_code(diagnostics, 2174))
  assert_true(has_code(diagnostics, 2117))
  assert_true(has_code(diagnostics, 2029))
  assert_true(has_code(diagnostics, 2121))
  assert_true(has_code(diagnostics, 2163))
  assert_true(has_code(diagnostics, 2184))
  assert_true(has_code(diagnostics, 2114))
  assert_true(has_code(diagnostics, 2115))
  assert_true(has_code(diagnostics, 2291))
  assert_true(has_code(diagnostics, 2316))
  assert_true(has_code(diagnostics, 2318))
}

///|
test "command checks flag timed command and local scope edge cases" {
  let piped = check_source("#!/bin/sh\ntime -p foo | bar\n")
  let compound = check_source("#!/bin/dash\ntime ( foo; bar; )\n")
  let local_top_level = check_source(
    "#!/bin/bash\n# shellcheck disable=SC2034\nlocal foo=3\n",
  )

  assert_true(has_code(piped, 2176))
  assert_true(has_code(compound, 2177))
  assert_true(has_code(local_top_level, 2168))
}

///|
test "command checks avoid false positives for phase 4 command-specialized families" {
  let diagnostics = check_source(
    "#!/bin/bash\n# shellcheck disable=SC2034\nmkdir -p a/b\nmkdir -m 0755 a/b\nmkdir -p -m 0755 singlelevel\necho rm | su foo\nsu root < script\nssh host \"ls foo\"\nset -- if=/dev/null\nexport foo\nunset foo\nrm -r /home/${USER:?}/*\necho foo  bar\nf() { local foo=3; }\nq() { local var=1; }\nq2() { local x=1; local y=$x; }\n",
  )
  let timed = check_source("#!/bin/sh\ntime sleep 1\n")
  let timed_compound = check_source("#!/bin/dash\ntime foo\n")

  assert_true(!has_code(diagnostics, 2174))
  assert_true(!has_code(diagnostics, 2117))
  assert_true(!has_code(diagnostics, 2029))
  assert_true(!has_code(diagnostics, 2121))
  assert_true(!has_code(diagnostics, 2163))
  assert_true(!has_code(diagnostics, 2184))
  assert_true(!has_code(diagnostics, 2114))
  assert_true(!has_code(diagnostics, 2115))
  assert_true(!has_code(diagnostics, 2291))
  assert_true(!has_code(diagnostics, 2168))
  assert_true(!has_code(diagnostics, 2316))
  assert_true(!has_code(diagnostics, 2318))
  assert_true(!has_code(timed, 2176))
  assert_true(!has_code(timed_compound, 2177))
}
