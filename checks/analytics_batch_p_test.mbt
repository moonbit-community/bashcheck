///|
fn count_equals_in_command_codes(diagnostics : Array[CheckDiagnostic]) -> Int {
  let mut total = 0
  let mut code = 2270
  while code <= 2282 {
    total += count_code(diagnostics, code)
    code += 1
  }
  total
}

///|
test "analytics batch p maps shell-specific equals-in-command diagnostics" {
  let bash_source =
    #|#!/bin/bash
    #|0='foo'
    #|
  let bash_diagnostics = check_source(bash_source)
  assert_eq(count_code(bash_diagnostics, 2277), 1)
  let bash_expected =
    #|#!/bin/bash
    #|BASH_ARGV0='foo'
    #|
  match first_code(bash_diagnostics, 2277).fix {
    Some(fix) =>
      assert_eq(@fixer.apply_fix(fix, bash_source), Some(bash_expected))
    None => checks_fail("expected SC2277 fix")
  }

  let ksh_diagnostics = check_source(
    (
      #|#!/bin/ksh
      #|$0='foo'
      #|
    ),
  )
  assert_eq(count_code(ksh_diagnostics, 2278), 1)

  let dash_diagnostics = check_source(
    (
      #|#!/bin/dash
      #|${0}='foo'
      #|
    ),
  )
  assert_eq(count_code(dash_diagnostics, 2279), 1)

  let sh_diagnostics = check_source(
    (
      #|#!/bin/sh
      #|0='foo'
      #|
    ),
  )
  assert_eq(count_code(sh_diagnostics, 2280), 1)
}

///|
test "analytics batch p flags equals-in-command variants" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2086
      #|1='foo'
      #|var$((n+1))=value
      #|var${x}=value
      #|$(cmd)='foo'
      #|$var==42
      #|=======
      #|======= Here =======
      #|foo
      #|=42
      #|var${x}/=value
      #|${}=value
      #|${#x}=value
      #|411toppm=true
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2270), 1)
  assert_eq(count_code(diagnostics, 2271), 3)
  assert_eq(count_code(diagnostics, 2272), 1)
  assert_eq(count_code(diagnostics, 2273), 1)
  assert_eq(count_code(diagnostics, 2274), 1)
  assert_eq(count_code(diagnostics, 2275), 1)
  assert_eq(count_code(diagnostics, 2276), 3)
  assert_eq(count_code(diagnostics, 2282), 1)
}

///|
test "analytics batch p offers lhs assignment fixes for direct references" {
  let plain_source =
    #|#!/bin/bash
    #|# shellcheck disable=SC2154,SC2086
    #|$var=foo
    #|
  let plain_diagnostics = check_source(plain_source)
  let plain_expected =
    #|#!/bin/bash
    #|# shellcheck disable=SC2154,SC2086
    #|var=foo
    #|
  match first_code(plain_diagnostics, 2281).fix {
    Some(fix) =>
      assert_eq(@fixer.apply_fix(fix, plain_source), Some(plain_expected))
    None => checks_fail("expected plain SC2281 fix")
  }

  let braced_source =
    #|#!/bin/bash
    #|# shellcheck disable=SC2154,SC2086
    #|${var[42]}=foo
    #|
  let braced_diagnostics = check_source(braced_source)
  let braced_expected =
    #|#!/bin/bash
    #|# shellcheck disable=SC2154,SC2086
    #|var[42]=foo
    #|
  match first_code(braced_diagnostics, 2281).fix {
    Some(fix) =>
      assert_eq(@fixer.apply_fix(fix, braced_source), Some(braced_expected))
    None => checks_fail("expected braced SC2281 fix")
  }

  let plus_source =
    #|#!/bin/bash
    #|# shellcheck disable=SC2154,SC2086
    #|$var+=foo
    #|
  let plus_diagnostics = check_source(plus_source)
  let plus_expected =
    #|#!/bin/bash
    #|# shellcheck disable=SC2154,SC2086
    #|var+=foo
    #|
  match first_code(plus_diagnostics, 2281).fix {
    Some(fix) =>
      assert_eq(@fixer.apply_fix(fix, plus_source), Some(plus_expected))
    None => checks_fail("expected plus-assignment SC2281 fix")
  }
}

///|
test "analytics batch p ignores already literal command names" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|--foo=bar
      #|$(cmd)'=foo'
      #|
    ),
  )

  assert_eq(count_equals_in_command_codes(diagnostics), 0)
}
