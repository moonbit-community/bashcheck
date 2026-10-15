///|
fn check_source_extended(source : String) -> Array[@checks.CheckDiagnostic] {
  test_check_parsed_script(
    parse_checks_ok(source),
    options=TestCheckOptions::default().with_extended_analysis(true),
  )
}

///|
test "control flow checks flag unreachable commands" {
  let diagnostics = check_source_extended(
    (
      #|exit 0
      #|echo never
      #|
    ),
  )
  assert_true(has_code(diagnostics, 2317))
}

///|
test "control flow checks flag unreachable functions" {
  let diagnostics = check_source_extended(
    (
      #|f() { echo hidden; }
      #|exit
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2329))
  assert_true(!has_code(diagnostics, 2317))
}

///|
test "control flow checks only flag functions that are never invoked" {
  let dead_case = check_source_extended(
    (
      #|f() { echo hidden; }
      #|exit
      #|
    ),
  )
  let live_case = check_source_extended(
    (
      #|f() { echo live; }
      #|f
      #|
    ),
  )

  assert_true(has_code(dead_case, 2329))
  assert_true(!has_code(live_case, 2329))
}

///|
test "control flow checks ignore functions that are invoked" {
  let diagnostics = check_source_extended(
    (
      #|f() { echo live; }
      #|f
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2329))
}

///|
test "control flow checks keep maybe-sourced function definitions quiet" {
  let diagnostics = check_source_extended(
    (
      #|f() { echo hidden; }
      #|echo live
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2329))
}

///|
test "control flow checks ignore redirect-only function bodies" {
  let diagnostics = check_source_extended(
    (
      #|#!/bin/bash
      #|fun() {
      #|# shellcheck disable=SC2188
      #|> /dev/null
      #|}
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2329))
}

///|
test "control flow checks flag maybe-unset reads" {
  let diagnostics = check_source_extended(
    (
      #|echo $foo
      #|
    ),
  )
  assert_true(has_code(diagnostics, 2154))
}

///|
test "control flow optional name enables analysis without global extended mode" {
  let diagnostics = test_check_parsed_script(
    parse_checks_ok(
      (
        #|echo $foo
        #|
      ),
    ),
    options=TestCheckOptions::default()
      .with_extended_analysis(false)
      .with_optional_checks(["control-flow"]),
  )

  assert_true(has_code(diagnostics, 2154))
}

///|
test "control flow checks suppress guards that explicitly allow unset parameters" {
  let default_value = check_source_extended(
    (
      #|echo ${foo-bar}
      #|
    ),
  )
  let error_value = check_source_extended(
    (
      #|echo ${foo:?}
      #|
    ),
  )
  let alternate_value = check_source_extended(
    (
      #|echo ${foo:+$foo}
      #|
    ),
  )

  assert_true(!has_code(default_value, 2154))
  assert_true(!has_code(error_value, 2154))
  assert_true(!has_code(alternate_value, 2154))
}

///|
test "control flow checks ignore nested reads inside parameter expansion payloads" {
  let diagnostics = check_source_extended(
    (
      #|echo ${var#$x}
      #|echo ${arr[$x]}
      #|echo ${foo:-$bar}
      #|echo ${foo:-${bar}}
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2154), 2)
}

///|
test "control flow checks use condition guards for then and while bodies only" {
  let guarded_if = check_source_extended(
    (
      #|if [[ -v foo ]]; then echo $foo; fi
      #|
    ),
  )
  let guarded_while = check_source_extended(
    (
      #|while [[ -v foo ]]; do echo $foo; done
      #|
    ),
  )
  let else_branch = check_source_extended(
    (
      #|if [[ -v foo ]]; then :; else echo $foo; fi
      #|
    ),
  )

  assert_true(!has_code(guarded_if, 2154))
  assert_true(!has_code(guarded_while, 2154))
  assert_true(has_code(else_branch, 2154))
}

///|
test "control flow checks cover arithmetic variable reads" {
  let diagnostics = check_source_extended(
    (
      #|(( total = foo + 1 ))
      #|
    ),
  )
  assert_true(has_code(diagnostics, 2154))
}

///|
test "control flow checks flag array-to-scalar assignment conflicts" {
  let diagnostics = check_source_extended(
    (
      #|# shellcheck disable=SC2034
      #|arr=(a)
      #|arr=foo
      #|arr+=bar
      #|
    ),
  )

  assert_true(has_code(diagnostics, 2178))
  assert_true(has_code(diagnostics, 2179))
}

///|
test "SC2154 spans follow parameter occurrences through quotes and escapes" {
  let cases : Array[(String, Array[(Int32, Int32, Int32, Int32)])] = [
    (
      "echo \"$foo $foobar ${baz}\"\n",
      [(1, 7, 1, 11), (1, 12, 1, 19), (1, 20, 1, 26)],
    ),
    ("echo '$foo'\"\\$foo $foo\"\n", [(1, 19, 1, 23)]),
    ("echo \"\\\\$foo\"\n", [(1, 9, 1, 13)]),
    ("echo \"first\n$foo ${bar}\n\"\n", [(2, 1, 2, 5), (2, 6, 2, 12)]),
    (
      "echo $foo\"$foobar\"${baz}\n",
      [(1, 6, 1, 10), (1, 11, 1, 18), (1, 19, 1, 25)],
    ),
    ("echo \"$(echo $foo)$bar\"\n", [(1, 14, 1, 18), (1, 19, 1, 23)]),
    ("echo \"$foobar $foo\"\n", [(1, 7, 1, 14), (1, 15, 1, 19)]),
    ("echo \"$(echo $foo)$foo\"\n", [(1, 14, 1, 18), (1, 19, 1, 23)]),
    ("echo \"first\\\n$foo\"\n", [(2, 1, 2, 5)]),
    // Keep the existing rule triggers, including separate reads of one name.
    ("echo \"$foo $foo\"\n", [(1, 7, 1, 11), (1, 12, 1, 16)]),
    ("echo \"${foo}\n${foo}\"\n", [(1, 7, 1, 13), (2, 1, 2, 7)]),
  ]
  for (source, expected) in cases {
    let diagnostics = check_source_extended(source).filter(d => d.code == 2154)
    let spans = diagnostics.map(d => {
      (
        d.span.start.line,
        d.span.start.column,
        d.span.end.line,
        d.span.end.column,
      )
    })
    assert_eq(spans, expected)
  }
}
