///|
test "shell support checks flag common sh bashisms" {
  let diagnostics = check_source(
    "#!/bin/sh\nsource lib.sh\ncat < <(echo x)\n((x += 1))\nfoo+=bar\narr=(a b)\n[[ x ]]\necho foo |& cat\n",
  )

  assert_true(has_code(diagnostics, 3046))
  assert_true(has_code(diagnostics, 3001))
  assert_true(has_code(diagnostics, 3006))
  assert_true(has_code(diagnostics, 3024))
  assert_true(has_code(diagnostics, 3030))
  assert_true(has_code(diagnostics, 3010))
  assert_true(has_code(diagnostics, 3029))
}

///|
test "shell support severity follows the active shell dialect" {
  let sh_diagnostic = first_code(check_source("#!/bin/sh\n((x += 1))\n"), 3006)
  let dash_diagnostic = first_code(
    check_source("#!/bin/dash\n((x += 1))\n"),
    3006,
  )

  assert_true(
    match sh_diagnostic.severity {
      CheckSeverity::Warning => true
      _ => false
    },
  )
  assert_true(
    match dash_diagnostic.severity {
      CheckSeverity::Error => true
      _ => false
    },
  )
  assert_true(sh_diagnostic.message.contains("POSIX sh"))
  assert_true(dash_diagnostic.message.contains("dash"))
}

///|
test "busybox sh keeps busybox-specific allowances but still flags arrays" {
  let diagnostics = check_source(
    "#!/bin/busybox sh\nsource /dev/null\n[[ x ]]\necho ${x:0:3} ${x/st/xt} ${x[1]} ${!x[@]} ${!prefix*} ${x^^}\n",
  )

  assert_true(!has_code(diagnostics, 3046))
  assert_true(!has_code(diagnostics, 3010))
  assert_true(!has_code(diagnostics, 3057))
  assert_true(!has_code(diagnostics, 3060))
  assert_true(has_code(diagnostics, 3054))
  assert_true(has_code(diagnostics, 3055))
  assert_true(has_code(diagnostics, 3056))
  assert_true(has_code(diagnostics, 3059))
}

///|
test "shell support checks flag test operator arithmetic and star-at gaps" {
  let diagnostics = check_source(
    "#!/bin/sh\ntest x \\< y\n[ x == y ]\ntest foo =~ bar\ntest -v var\ntest -a file\ntest -o errexit\ntest -R ref\ntest -N file\ntest -k /tmp\ntest -G file\ntest -O file\necho $((i++))\necho $((2**3))\necho $((16#FF))\necho ${@%foo}\n",
  )

  assert_true(has_code(diagnostics, 3012))
  assert_true(has_code(diagnostics, 3014))
  assert_true(has_code(diagnostics, 3015))
  assert_true(has_code(diagnostics, 3016))
  assert_true(has_code(diagnostics, 3017))
  assert_true(has_code(diagnostics, 3062))
  assert_true(has_code(diagnostics, 3063))
  assert_true(has_code(diagnostics, 3064))
  assert_true(has_code(diagnostics, 3065))
  assert_true(has_code(diagnostics, 3066))
  assert_true(has_code(diagnostics, 3067))
  assert_true(has_code(diagnostics, 3018))
  assert_true(has_code(diagnostics, 3019))
  assert_true(has_code(diagnostics, 3052))
  assert_true(has_code(diagnostics, 3058))
}

///|
test "shell support checks flag redirects command shortcuts and wrapped source" {
  let diagnostics = check_source(
    "#!/bin/sh\n# shellcheck disable=SC2046,SC2006,SC2182\nfoo &> /dev/null\ncmd >& file\nexec {fd}>&2\necho foo 42>/dev/null\ncat < /dev/tcp/host/123\necho *[^0-9]*\nfoo-bar() { true; }\necho $(<file)\necho `<file`\ntrap foo ERR SIGINT sigterm\nprintf '%q' \"$1\"\ncommand source lib.sh\n",
  )

  assert_true(has_code(diagnostics, 3020))
  assert_true(has_code(diagnostics, 3021))
  assert_true(has_code(diagnostics, 3022))
  assert_true(has_code(diagnostics, 3023))
  assert_true(has_code(diagnostics, 3025))
  assert_true(has_code(diagnostics, 3026))
  assert_true(has_code(diagnostics, 3033))
  assert_true(has_code(diagnostics, 3034))
  assert_true(has_code(diagnostics, 3035))
  assert_true(has_code(diagnostics, 3047))
  assert_true(has_code(diagnostics, 3048))
  assert_true(has_code(diagnostics, 3049))
  assert_true(has_code(diagnostics, 3050))
  assert_true(has_code(diagnostics, 3051))
}

///|
test "shell support checks flag non-posix builtin flags and set options" {
  let diagnostics = check_source(
    "#!/bin/sh\n# shellcheck disable=SC2162\nread -a foo\nprintf -v out %s foo\nexport -f foo\nreadonly -a bar\nhash -l\ncd -P -e .\ntype -a ls\nulimit -x unlimited\nset -o emacs\nset --bad\nexec -c env\necho -ne foo\n",
  )

  assert_eq(count_code(diagnostics, 3045), 9)
  assert_true(has_code(diagnostics, 3040))
  assert_true(has_code(diagnostics, 3042))
  assert_true(has_code(diagnostics, 3038))
  assert_true(has_code(diagnostics, 3037))
}

///|
test "shell support bash variables and dialect-specific allowances stay scoped" {
  let sh_diagnostics = check_source(
    "#!/bin/sh\nHOSTNAME=foo\necho $HOSTNAME\nRANDOM=9\necho $RANDOM\n",
  )
  let dash_diagnostics = check_source(
    "#!/bin/dash\ntest x \\< y\ntest -k /tmp\necho $_\n",
  )
  let busybox_diagnostics = check_source(
    "#!/bin/busybox sh\ntype -p test\necho -ne foo\nread -p prompt -r name\ntrap stop EXIT SIGTERM\nsource /dev/null\n[ x == y ]\n",
  )
  let dash_echo_flags = check_source("#!/bin/dash\necho -ne foo\n")

  assert_eq(count_code(sh_diagnostics, 3028), 1)
  assert_true(first_code(sh_diagnostics, 3028).message.contains("RANDOM"))
  assert_true(!has_code(dash_diagnostics, 3012))
  assert_true(!has_code(dash_diagnostics, 3065))
  assert_true(!has_code(dash_diagnostics, 3028))
  assert_true(!has_code(busybox_diagnostics, 3045))
  assert_true(!has_code(busybox_diagnostics, 3036))
  assert_true(!has_code(busybox_diagnostics, 3048))
  assert_true(!has_code(busybox_diagnostics, 3046))
  assert_true(!has_code(busybox_diagnostics, 3014))
  assert_true(has_code(dash_echo_flags, 3036))
}
