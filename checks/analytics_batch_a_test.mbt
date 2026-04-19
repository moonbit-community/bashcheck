///|
test "analytics batch a checks flag single quotes constant tests tilde quotes and trailing commas" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|echo '$foo'
      #|echo "VALUES ("id")"
      #|[[ x == y ]]
      #|# shellcheck disable=SC2154
      #|echo $foo
      #|# shellcheck disable=SC2034
      #|var="~/out.txt"
      #|for f in foo, bar,; do true; done
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2016))
  assert_true(has_code(diagnostics, 2050))
  assert_true(has_code(diagnostics, 2086))
  assert_true(has_code(diagnostics, 2088))
  assert_true(has_code(diagnostics, 2140))
  assert_eq(count_code(diagnostics, 2258), 2)
}

///|
test "analytics batch a flags quoted fragment gaps without tripping quote-safe joins" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC1011,SC2086,SC2154
      #|echo 'foo'bar
      #|echo "a"$b"c"
      #|echo "VALUES ("id")"
      #|echo "$dir"/"$file"
      #|echo "$dir"some_stuff"$file"
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2026), 1)
  assert_eq(count_code(diagnostics, 2027), 1)
  assert_eq(count_code(diagnostics, 2140), 1)
}

///|
test "analytics batch a checks avoid quoted-expression false positives in known contexts" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|sed 's/foo$/bar/'
      #|sed -n '$p'
      #|awk '{print $1}'
      #|trap 'echo $SECONDS' EXIT
      #|PS1='$PWD \$ '
      #|echo "foo"/"bar"
      #|[[ $x == y ]]
      #|~/file
      #|for f in 'ls,' 'grep,' 'mv'; do true; done
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2016))
  assert_true(!has_code(diagnostics, 2050))
  assert_true(!has_code(diagnostics, 2088))
  assert_true(!has_code(diagnostics, 2140))
  assert_true(!has_code(diagnostics, 2258))
}

///|
test "analytics batch a flags impossible equality comparisons without replacing SC2050" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2203
      #|[[ *.png == [a-z] ]]
      #|[[ x == y ]]
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2193), 1)
  assert_eq(count_code(diagnostics, 2050), 1)
}

///|
test "analytics batch a avoids impossible-comparison false positives on overlapping words" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|[[ $n == $n ]]
      #|[[ ~me == ~+ ]]
      #|[[ ~ == ~+ ]]
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2193))
}

///|
test "analytics batch a flags simple and declaration-style unused assignments" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|foo=bar
      #|readonly baz=qux
      #|declare zap
      #|typeset t=3
      #|f(){ local x=1; }
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2034), 5)
}

///|
test "analytics batch a ignores exported used and prefixed assignments" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|foo=bar echo hi
      #|export nope=1
      #|used=1
      #|echo $used
      #|value=1
      #|((value += 1))
      #|foo=$foo
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2034))
  assert_true(has_code(diagnostics, 2269))
}

///|
test "analytics batch a counts arithmetic and here-doc expansions as assignment uses" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|arith_word=1
      #|echo $((arith_word + 1))
      #|heredoc_param=1
      #|cat <<EOF
      #|$heredoc_param
      #|EOF
      #|heredoc_index=(a b)
      #|cat <<EOF >> ./test
      #| $(( 1 + heredoc_index[1] ))
      #|EOF
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2034))
}

///|
test "analytics batch a flags pure unquoted parameter words with shellcheck-style fixes" {
  let source =
    #|#!/bin/bash
    #|# shellcheck disable=SC2154
    #|echo $foo
    #|echo ${foo:-bar}
    #|echo $1
    #|echo $*
    #|echo ${array[*]}
    #|echo ${array[@]}
    #|echo ${foo:+bar}
    #|echo ${#foo}
    #|
  let diagnostics = check_source(source)

  assert_eq(count_code(diagnostics, 2086), 5)
  match first_code(diagnostics, 2086).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2154
            #|echo "$foo"
            #|echo ${foo:-bar}
            #|echo $1
            #|echo $*
            #|echo ${array[*]}
            #|echo ${array[@]}
            #|echo ${foo:+bar}
            #|echo ${#foo}
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2086 fix")
  }
}

///|
test "analytics batch a flags mixed unquoted parameter words with shellcheck-style fixes" {
  let source =
    #|#!/bin/bash
    #|# shellcheck disable=SC2154
    #|echo x$foo
    #|
  let diagnostics = check_source(source)

  assert_eq(count_code(diagnostics, 2086), 1)
  match first_code(diagnostics, 2086).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2154
            #|echo x"$foo"
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2086 fix")
  }
}

///|
test "analytics batch a ignores case words for unquoted parameter expansion" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|case $1 in a) true ;; esac
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2086))
}

///|
test "analytics batch a ignores quote-safe standalone variables for unquoted expansion" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|safe=hello
      #|echo $safe
      #|unsafe='hi there'
      #|echo $unsafe
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2086), 1)
}

///|
test "analytics batch a reports uppercase misspellings with close assigned matches" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2086
      #|HOME_DIR=1
      #|PATHS=1
      #|echo $HOMR_DIR
      #|echo ${PATS}
      #|echo $UNSETVAR
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2153), 2)
  assert_true(
    diagnostics.any(fn(d) { d.code == 2153 && d.message.contains("HOME_DIR") }),
  )
  assert_true(
    diagnostics.any(fn(d) { d.code == 2153 && d.message.contains("PATHS") }),
  )
}

///|
test "analytics batch a flags bad parameter substitution family" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2086,SC2154
      #|echo ${"bar"}
      #|echo ${{var}
      #|echo ${$(x)//x/y}
      #|echo ${'foo'}
      #|echo ${${x%.*}##*/}
      #|echo ${${x}foo!}
      #|echo ${$x}
      #|echo ${foo$n}
      #|echo ${bar}
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2296), 1)
  assert_eq(count_code(diagnostics, 2297), 1)
  assert_eq(count_code(diagnostics, 2298), 1)
  assert_eq(count_code(diagnostics, 2299), 1)
  assert_eq(count_code(diagnostics, 2300), 1)
  assert_eq(count_code(diagnostics, 2301), 1)
}

///|
test "analytics batch a keeps constant-condition warnings in compound single-bracket tests" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|[ x == y ]
      #|[ -z 3 -o a = b ]
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2050), 2)
  assert_eq(count_code(diagnostics, 2166), 1)
}

///|
test "analytics batch a trailing comma diagnostics carry a delete fix" {
  let source =
    #|#!/bin/bash
    #|# shellcheck disable=SC2034
    #|for f in foo, bar,; do true; done
    #|
  let diagnostic = first_code(check_source(source), 2258)

  match diagnostic.fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(fix, source),
        Some(
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2034
            #|for f in foo bar,; do true; done
            #|
          ),
        ),
      )
    None => checks_fail("expected SC2258 fix")
  }
}
