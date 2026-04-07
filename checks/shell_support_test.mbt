///|
test "shell support checks flag common sh bashisms" {
  let diagnostics = check_source(
    (
      #|#!/bin/sh
      #|source lib.sh
      #|cat < <(echo x)
      #|((x += 1))
      #|foo+=bar
      #|arr=(a b)
      #|[[ x ]]
      #|echo foo |& cat
      #|
    ),
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
  let sh_diagnostic = first_code(
    check_source(
      (
        #|#!/bin/sh
        #|((x += 1))
        #|
      ),
    ),
    3006,
  )
  let dash_diagnostic = first_code(
    check_source(
      (
        #|#!/bin/dash
        #|((x += 1))
        #|
      ),
    ),
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
    (
      #|#!/bin/busybox sh
      #|source /dev/null
      #|[[ x ]]
      #|echo ${x:0:3} ${x/st/xt} ${x[1]} ${!x[@]} ${!prefix*} ${x^^}
      #|
    ),
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
test "shell support checks flag bash-only compatibility tail rules" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2331
      #|PS1='\\033[1;35m\\$ '
      #|echo {1..$n}
      #|eval echo DSC{0001..$n}.jpg
      #|foo[1][2]=3
      #|foo=( [1][2]=c )
      #|echo ${foo[1][2]}
      #|((3.14*1))
      #|true | ! true
      #|[ ! -a file ]
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2025))
  assert_true(has_code(diagnostics, 2051))
  assert_true(has_code(diagnostics, 2079))
  assert_true(has_code(diagnostics, 2175))
  assert_true(has_code(diagnostics, 2180))
  assert_true(has_code(diagnostics, 2326))
  assert_true(has_code(diagnostics, 2332))
  assert_true(
    match first_code(diagnostics, 2025).severity {
      CheckSeverity::Info => true
      _ => false
    },
  )
  assert_true(
    match first_code(diagnostics, 2079).severity {
      CheckSeverity::Error => true
      _ => false
    },
  )
  assert_true(
    match first_code(diagnostics, 2175).severity {
      CheckSeverity::Style => true
      _ => false
    },
  )
}

///|
test "shell support checks keep bash tail negatives scoped" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|PS1='\\[\\e\\]'
      #|echo {1,3,$n}
      #|true | ( ! true )
      #|! ! true
      #|! [ -o braceexpand ]
      #|[[ ! -o braceexpand ]]
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2025))
  assert_true(!has_code(diagnostics, 2051))
  assert_true(!has_code(diagnostics, 2175))
  assert_true(!has_code(diagnostics, 2325))
  assert_true(!has_code(diagnostics, 2326))
  assert_true(!has_code(diagnostics, 2332))
}

///|
test "shell support checks flag echo-sed rewrites and sh multiple bangs" {
  let bash_diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|FOO=$(echo "$cow" | sed 's/foo/bar/g')
      #|bar=$(sed -e 's,foo,bar,' <<< "$cow")
      #|
    ),
  )
  let sh_diagnostics = check_source(
    (
      #|#!/bin/sh
      #|! ! true
      #|
    ),
  )

  assert_eq(count_code(bash_diagnostics, 2001), 2)
  assert_true(has_code(sh_diagnostics, 2325))
}

///|
test "shell support checks flag test operator arithmetic and star-at gaps" {
  let diagnostics = check_source(
    (
      #|#!/bin/sh
      #|test x \< y
      #|[ x == y ]
      #|test foo =~ bar
      #|test -v var
      #|test -a file
      #|test -o errexit
      #|test -R ref
      #|test -N file
      #|test -k /tmp
      #|test -G file
      #|test -O file
      #|echo $((i++))
      #|echo $((2**3))
      #|echo $((16#FF))
      #|echo ${@%foo}
      #|
    ),
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
    (
      #|#!/bin/sh
      #|# shellcheck disable=SC2046,SC2006,SC2182
      #|foo &> /dev/null
      #|cmd >& file
      #|exec {fd}>&2
      #|echo foo 42>/dev/null
      #|cat < /dev/tcp/host/123
      #|echo *[^0-9]*
      #|foo-bar() { true; }
      #|echo $(<file)
      #|echo `<file`
      #|trap foo ERR SIGINT sigterm
      #|printf '%q' "$1"
      #|command source lib.sh
      #|
    ),
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
    (
      #|#!/bin/sh
      #|# shellcheck disable=SC2162
      #|read -a foo
      #|printf -v out %s foo
      #|export -f foo
      #|readonly -a bar
      #|hash -l
      #|cd -P -e .
      #|type -a ls
      #|ulimit -x unlimited
      #|set -o emacs
      #|set --bad
      #|exec -c env
      #|echo -ne foo
      #|
    ),
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
    (
      #|#!/bin/sh
      #|HOSTNAME=foo
      #|echo $HOSTNAME
      #|RANDOM=9
      #|echo $RANDOM
      #|
    ),
  )
  let dash_diagnostics = check_source(
    (
      #|#!/bin/dash
      #|test x \< y
      #|test -k /tmp
      #|echo $_
      #|
    ),
  )
  let busybox_diagnostics = check_source(
    (
      #|#!/bin/busybox sh
      #|type -p test
      #|echo -ne foo
      #|read -p prompt -r name
      #|trap stop EXIT SIGTERM
      #|source /dev/null
      #|[ x == y ]
      #|
    ),
  )
  let dash_echo_flags = check_source(
    (
      #|#!/bin/dash
      #|echo -ne foo
      #|
    ),
  )

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
