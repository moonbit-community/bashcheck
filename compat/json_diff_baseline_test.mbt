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
