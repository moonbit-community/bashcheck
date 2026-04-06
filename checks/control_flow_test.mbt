///|
fn check_source_extended(source : String) -> Array[CheckDiagnostic] {
  check_script(
    parse_checks_ok(source),
    options=CheckOptions::default().with_extended_analysis(true),
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
  let diagnostics = check_script(
    parse_checks_ok(
      (
        #|echo $foo
        #|
      ),
    ),
    options=CheckOptions::default()
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
test "control flow checks advertise array scalar conflict rules" {
  let descriptions = supported_checks()
  let mut saw_2178 = false
  let mut saw_2179 = false
  for description in descriptions {
    if description.code == 2178 {
      saw_2178 = true
    }
    if description.code == 2179 {
      saw_2179 = true
    }
  }

  assert_true(saw_2178)
  assert_true(saw_2179)
}
