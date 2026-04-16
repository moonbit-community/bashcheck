///|
async test "phase 0 dynamic json diff aligns newly closed command gaps" {
  assert_shellcheck_json_matches(
    "SC2001",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2154
      #|FOO=$(echo "$cow" | sed 's/foo/bar/g')
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2028",
    (
      #|#!/bin/bash
      #|echo "\\n"
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2155",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|f(){ local x=$(false); }
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2172-SC2173",
    (
      #|#!/bin/bash
      #|trap foo 16 KILL 9
      #|
    ),
  )
}

///|
async test "phase 0 dynamic json diff aligns planned compatibility gaps" {
  assert_shellcheck_json_matches(
    "SC2086-mixed-word",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|echo x$foo
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC1033",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|[[ "$foo" ]
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC1034",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|[ "$foo" ]]
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2181",
    (
      #|#!/bin/bash
      #|true
      #|[ $? == 0 ]
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2187",
    (
      #|#!bin/ash
      #|true
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2239",
    (
      #|#!bin/sh
      #|true
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2246",
    (
      #|#!/bin/sh/
      #|true
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2247",
    (
      #|#!/bin/bash
      #|$"(foo)"
      #|
    ),
  )
}

///|
async test "phase 1 dynamic json diff aligns analytics batch a syntax gaps" {
  assert_shellcheck_json_matches(
    "SC2016",
    (
      #|#!/bin/bash
      #|echo '$foo'
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2034",
    (
      #|#!/bin/bash
      #|foo=bar
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2050",
    (
      #|#!/bin/bash
      #|[[ x == y ]]
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2086",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|echo $foo
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2088",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|var="~/out.txt"
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2140",
    (
      #|#!/bin/bash
      #|echo "VALUES ("id")"
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2153",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2086
      #|HOME_DIR=1
      #|echo $HOMR_DIR
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2258",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|for f in foo, bar,; do true; done
      #|
    ),
  )
}

///|
async test "phase 1 dynamic json diff aligns analytics bad parameter substitutions" {
  assert_shellcheck_json_matches(
    "analytics bad parameter substitutions",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2086,SC2154
      #|echo ${"bar"}
      #|echo ${{var}
      #|echo ${$(x)//x/y}
      #|echo ${'foo'}
      #|echo ${${x%.*}##*/}
      #|echo ${${x}foo!}
      #|
    ),
  )
}

///|
async test "phase 2 dynamic json diff aligns analytics batch i expansion diagnostics" {
  assert_shellcheck_json_matches(
    "SC2145-SC2295",
    (
      #|#!/bin/bash
      #|echo "foo$@"
      #|echo ${var#$x}
      #|echo "${name#$y}"
      #|
    ),
  )
}

///|
async test "phase 3 dynamic json diff aligns analytics batch k while-read diagnostics" {
  assert_shellcheck_json_matches(
    "SC2095-direct",
    (
      #|#!/bin/bash
      #|while read -r foo; do ssh "$foo" uptime; done
      #|while read -r foo; do ffmpeg -i foo.mkv bar.mkv -an; done
      #|while read -r foo; do mplayer foo.ogv > file; done
      #|while read -r foo; do HandBrakeCLI foo.mkv -o out.mkv; done
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2095-nested-assignment",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|while read -r foo; do x=$(ssh host cmd); done
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2095-nested-if-and-background",
    (
      #|#!/bin/bash
      #|while read -r foo; do if true; then ssh "$foo" uptime; fi; done
      #|while read -r foo; do ssh "$foo" uptime & done
      #|
    ),
  )
}

///|
async test "phase 0 dynamic json diff aligns newly closed shell support gaps" {
  assert_shellcheck_json_matches(
    "SC2025",
    (
      #|#!/bin/bash
      #|PS1='\\033[1;35m\\$ '
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2051",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2086,SC2154
      #|echo {1..$n}
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2079",
    (
      #|#!/bin/bash
      #|((3.14*1))
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2175",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2086,SC2154
      #|eval echo DSC{0001..$n}.jpg
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2180",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2086,SC2154
      #|echo ${foo[1][2]}
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2325",
    (
      #|#!/bin/sh
      #|! ! true
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2326",
    (
      #|#!/bin/bash
      #|true | ! true
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2332",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2331
      #|[ ! -a file ]
      #|
    ),
  )
}

///|
async test "SC2331" {
  assert_shellcheck_json_matches(
    "SC2331",
    (
      #|#!/bin/bash
      #|[ -a file ]
      #|
    ),
  )
}

///|
async test "phase 3 dynamic json diff aligns analytics command-shape rules" {
  assert_shellcheck_json_matches(
    "SC2256",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2209
      #|foo_bar2=val; $"foo_bar2"
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2268",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2086
      #|[ x"$foo" = x'lol' ]
      #|test X$foo = Xbar
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2283-SC2285",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2086,SC2046
      #|foo = $bar
      #|foo == $bar
      #|var += $(foo)
      #|var +=$(foo)
      #|
    ),
  )
}

///|
async test "phase 3 dynamic json diff aligns analytics arithmetic-context rules" {
  assert_shellcheck_json_matches(
    "SC2321-SC2324",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|a[$((1+1))]=n
      #|echo $(( ((1+1)) ))
      #|echo $(( (x) ))
      #|n=4
      #|x+=1
      #|y+=n
      #|
    ),
  )
}

///|
async test "phase 4 dynamic json diff aligns analytics batch m unmatchable case rules" {
  assert_shellcheck_json_matches(
    "SC2194-SC2222",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|case foo in bar) true; esac
      #|case foo-$bar in ??|*) true; esac
      #|case $f in cow) true;; bar|cow) false;; esac
      #|
    ),
  )
}

///|
async test "phase 4 dynamic json diff aligns bats negation and unreachable function diagnostics" {
  assert_shellcheck_json_matches(
    "SC2314-SC2315-SC2329",
    (
      #|#!/bin/bash
      #|@test "negation" { ! true; false; }
      #|@test "condition" { ! [[ -e test ]]; }
      #|f() { echo hidden; }
      #|exit
      #|
    ),
  )
}

///|
async test "phase 4 dynamic json diff aligns blatant recursion diagnostics" {
  assert_shellcheck_json_matches(
    "SC2264",
    (
      #|#!/bin/bash
      #|f() { f; }
      #|cd() { cd "$1" || exit; }
      #|
    ),
  )
}

///|
async test "phase 4 dynamic json diff aligns equals in command diagnostics" {
  assert_shellcheck_json_matches(
    "SC2270-SC2282",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2086
      #|0='foo'
      #|1='foo'
      #|$var=foo
      #|${var}=foo
      #|var${x}=value
      #|=======
      #|======= Here =======
      #|foo
      #|=42
      #|411toppm=true
      #|
    ),
  )
}

///|
async test "phase 4 dynamic json diff aligns analytics batch q redirect and pipe diagnostics" {
  assert_shellcheck_json_matches(
    "SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261",
    (
      #|#!/bin/bash
      #|> file
      #|> file | grep foo
      #|grep foo | > bar
      #|foo | echo bar
      #|foo | basename < file.txt
      #|ls > foo > bar
      #|ls > foo 2> bar > baz
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2216-nested-pipeline-in-command-substitution",
    (
      #|#!/bin/bash
      #|echo $(foo | echo bar)
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2216-here-doc-nested-consumer",
    (
      #|#!/bin/bash
      #|foo | cat <<EOF
      #|$(cat)
      #|EOF
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2259-quoted-here-doc",
    (
      #|#!/bin/bash
      #|echo World | cat << 'EOF'
      #|hello $(cat)
      #|EOF
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2216-command-exceptions-and-fd-dup",
    (
      #|#!/bin/bash
      #|find . -print0 | du --files0-from=/dev/stdin
      #|find . | du --exclude-from=/dev/fd/0
      #|yes | cp -Ri foo/* bar
      #|yes | rm --interactive *
      #|ls 1>&3 3>&1 3>&-
      #|
    ),
  )
}

///|
async test "phase 4 dynamic json diff aligns analytics batch t command misuse diagnostics" {
  assert_shellcheck_json_matches(
    "SC2007",
    (
      #|#!/bin/bash
      #|echo $[1+2]
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2084",
    (
      #|#!/bin/bash
      #|$((i++))
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2091",
    (
      #|#!/bin/bash
      #|$(foo)
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2092",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2006
      #|`foo`
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2093",
    (
      #|#!/bin/bash
      #|exec foo; true
      #|for f in *; do exec "$f"; done
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2094",
    (
      #|#!/bin/bash
      #|cat foo > foo
      #|cat lol | sed -e 's/a/b/g' > lol
      #|
    ),
  )

  assert_shellcheck_json_matches(
    "SC2209",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|out=cat foo
      #|here=pwd
      #|
    ),
  )
}

///|
async test "phase 5 dynamic json diff aligns legacy unary test diagnostics" {
  assert_shellcheck_json_matches(
    "SC2331",
    (
      #|#!/bin/bash
      #|[ -a file ]
      #|
    ),
  )
}
