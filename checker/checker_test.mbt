///|
fn checker_has_code(
  diagnostics : Array[@checker.PositionedDiagnostic],
  code : Int32,
) -> Bool {
  for diagnostic in diagnostics {
    match diagnostic.code {
      Some(found) if found == code => return true
      _ => ()
    }
  }
  false
}

///|
fn checker_first_code(
  diagnostics : Array[@checker.PositionedDiagnostic],
  code : Int32,
) -> @checker.PositionedDiagnostic {
  for diagnostic in diagnostics {
    match diagnostic.code {
      Some(found) if found == code => return diagnostic
      _ => ()
    }
  }
  panic()
}

///|
test "checker filters included and excluded codes" {
  let source =
    #|echo `foo`
    #|rm $(ls)
    #|
  let excluded = @checker.check_script(
    source,
    spec=@checker.CheckSpec::default().with_exclude_codes([2006]),
  )
  let included = @checker.check_script(
    source,
    spec=@checker.CheckSpec::default().with_include_codes([2006]),
  )

  assert_true(!checker_has_code(excluded.diagnostics, 2006))
  assert_true(checker_has_code(excluded.diagnostics, 2046))
  assert_true(checker_has_code(included.diagnostics, 2006))
  assert_true(!checker_has_code(included.diagnostics, 2046))
}

///|
test "checker honors severity thresholds and annotations" {
  let error = if @checker.parse_diagnostic_severity("error") is Some(severity) {
    severity
  } else {
    panic()
  }
  let threshold = @checker.check_script(
    (
      #|#!/bin/dash
      #|((x += 1))
      #|rm $(ls)
      #|
    ),
    spec=@checker.CheckSpec::default().with_min_severity(error),
  )
  let annotated = @checker.check_script(
    (
      #|# shellcheck disable=SC2006
      #|printf '%s' `foo`
      #|
    ),
  )

  assert_true(checker_has_code(threshold.diagnostics, 3006))
  assert_true(!checker_has_code(threshold.diagnostics, 2046))
  assert_true(!checker_has_code(annotated.diagnostics, 2006))
}

///|
test "checker enables control-flow analysis by default but can disable it" {
  let enabled = @checker.check_script(
    (
      #|echo $foo
      #|
    ),
  )
  let disabled = @checker.check_script(
    (
      #|echo $foo
      #|
    ),
    spec=@checker.CheckSpec::default().with_extended_analysis(false),
  )

  assert_true(checker_has_code(enabled.diagnostics, 2154))
  assert_true(!checker_has_code(disabled.diagnostics, 2154))
}

///|
test "checker emits SC2148 only when the entry shell stays unknown" {
  let plain = @checker.check_script(
    (
      #|echo hello
      #|
    ),
  )
  let from_directive = @checker.check_script(
    (
      #|# shellcheck shell=bash
      #|echo hello
      #|
    ),
  )
  let from_extension = @checker.check_script(
    (
      #|echo hello
      #|
    ),
    spec=@checker.CheckSpec::default().with_filename(Some("script.bash")),
  )
  let from_envrc = @checker.check_script(
    (
      #|echo hello
      #|
    ),
    spec=@checker.CheckSpec::default().with_filename(Some(".envrc")),
  )
  let from_override = @checker.check_script(
    (
      #|echo hello
      #|
    ),
    spec=@checker.CheckSpec::default().with_shell_override(Some(Dash)),
  )

  let expected = [
    (
      "error",
      Some(2148),
      1,
      1,
      "Tips depend on target shell and yours is unknown. Add a shebang or a 'shell' directive.",
    ),
  ]
  assert_checker_diagnostics(plain.diagnostics, expected)
  assert_checker_diagnostics(from_directive.diagnostics, [])
  assert_checker_diagnostics(from_extension.diagnostics, [])
  assert_checker_diagnostics(from_envrc.diagnostics, expected)
  assert_checker_diagnostics(from_override.diagnostics, [])
}

///|
test "checker shell precedence keeps stronger entry signals above filename hints" {
  let shebang_over_extension = @checker.check_script(
    (
      #|#!/bin/sh
      #|[[ x ]]
      #|
    ),
    spec=@checker.CheckSpec::default().with_filename(Some("script.bash")),
  )
  let directive_over_shebang = @checker.check_script(
    (
      #|#!/bin/sh
      #|# shellcheck shell=bash
      #|[[ x ]]
      #|
    ),
  )

  assert_true(checker_has_code(shebang_over_extension.diagnostics, 3010))
  assert_true(!checker_has_code(directive_over_shebang.diagnostics, 3010))
}

///|
test "checker emits shebang entry diagnostics and respects shell overrides" {
  let ash = @checker.check_script(
    (
      #|#!bin/ash
      #|true
      #|
    ),
  )
  let directory = @checker.check_script(
    (
      #|#!/bin/sh/
      #|true
      #|
    ),
  )
  let overridden = @checker.check_script(
    (
      #|#!bin/ash
      #|# shellcheck shell=dash
      #|true
      #|
    ),
  )

  assert_checker_diagnostics(ash.diagnostics, [
    (
      "error",
      Some(2239),
      1,
      1,
      "Ensure the shebang uses an absolute path to the interpreter.",
    ),
    (
      "warning",
      Some(2187),
      1,
      1,
      "Ash scripts will be checked as Dash. Add '# shellcheck shell=dash' to silence.",
    ),
  ])
  assert_checker_diagnostics(directory.diagnostics, [
    (
      "error",
      Some(2246),
      1,
      1,
      "This shebang specifies a directory. Ensure the interpreter is a file.",
    ),
  ])
  assert_checker_diagnostics(overridden.diagnostics, [])
}

///|
test "checker advertises shellcheck-compatible optional checks without exposing control-flow" {
  assert_true(!@checker.supported_optional_checks().contains("control-flow"))
  assert_true(
    @checker.supported_optional_checks().contains("useless-use-of-cat"),
  )
  assert_true(@checker.supported_optional_checks().contains("add-default-case"))
  assert_true(
    @checker.supported_optional_checks().contains("quote-safe-variables"),
  )
  assert_true(
    @checker.supported_optional_checks().contains("avoid-nullary-conditions"),
  )
  assert_true(
    @checker.supported_optional_checks().contains("avoid-negated-conditions"),
  )
  assert_true(
    @checker.supported_optional_checks().contains("require-variable-braces"),
  )
  assert_true(
    @checker.supported_optional_checks().contains("check-unassigned-uppercase"),
  )
  assert_true(
    @checker.supported_optional_checks().contains("require-double-brackets"),
  )
  assert_true(
    @checker.supported_optional_checks().contains("check-set-e-suppressed"),
  )
  assert_true(
    @checker.supported_optional_checks().contains("check-extra-masked-returns"),
  )
  assert_true(@checker.supported_optional_checks().contains("deprecate-which"))
  let descriptions = @checker.supported_checks()
  let mut found = false
  let mut found_optional = false
  for description in descriptions {
    if description.code == 2154 {
      found = true
    }
    if description.code == 2002 {
      found_optional = true
    }
  }
  assert_true(found)
  assert_true(found_optional)
}

///|
test "checker honors enable and extended-analysis directives" {
  let enabled = @checker.check_script(
    (
      #|# shellcheck enable=control-flow
      #| echo $foo
      #|
    ),
    spec=@checker.CheckSpec::default().with_extended_analysis(false),
  )
  let disabled = @checker.check_script(
    (
      #|# shellcheck extended-analysis=false
      #| echo $foo
      #|
    ),
  )

  assert_true(checker_has_code(enabled.diagnostics, 2154))
  assert_true(!checker_has_code(disabled.diagnostics, 2154))
}

///|
test "checker honors optional checks from spec and directives" {
  let from_spec = @checker.check_script(
    (
      #|safe=hello
      #|echo $safe
      #|
    ),
    spec=@checker.CheckSpec::default().with_optional_checks([
      "quote-safe-variables",
    ]),
  )
  let from_directive = @checker.check_script(
    (
      #|# shellcheck enable=require-double-brackets
      #|[ -x foo ]
      #|
    ),
  )
  let default_result = @checker.check_script(
    (
      #|safe=hello
      #|echo $safe
      #|[ -x foo ]
      #|
    ),
  )

  assert_true(checker_has_code(from_spec.diagnostics, 2248))
  assert_true(checker_has_code(from_directive.diagnostics, 2292))
  assert_true(!checker_has_code(default_result.diagnostics, 2248))
  assert_true(!checker_has_code(default_result.diagnostics, 2292))
}

///|
test "checker loads .shellcheckrc unless disabled" {
  let with_rc = @checker.check_script(
    (
      #|printf '%s' `foo`
      #|
    ),
    spec=@checker.CheckSpec::default()
      .with_filename(Some("checker/testdata/rc/script.sh"))
      .with_config_files([
        ("checker/testdata/rc/.shellcheckrc", "disable=SC2006"),
      ]),
  )
  let without_rc = @checker.check_script(
    (
      #|printf '%s' `foo`
      #|
    ),
    spec=@checker.CheckSpec::default()
      .with_filename(Some("checker/testdata/rc/script.sh"))
      .with_config_files([
        ("checker/testdata/rc/.shellcheckrc", "disable=SC2006"),
      ])
      .with_ignore_rc(true),
  )

  assert_true(!checker_has_code(with_rc.diagnostics, 2006))
  assert_true(checker_has_code(without_rc.diagnostics, 2006))
}

///|
test "checker honors explicit rcfile override paths" {
  let result = @checker.check_script(
    (
      #|printf '%s' `foo`
      #|
    ),
    spec=@checker.CheckSpec::default()
      .with_config_path_override(Some("custom.rc"))
      .with_config_files([("custom.rc", "disable=SC2006")]),
  )

  assert_true(!checker_has_code(result.diagnostics, 2006))
}

///|
test "checker keeps explicit extended analysis overrides above directives and rc" {
  let from_directive = @checker.check_script(
    (
      #|# shellcheck extended-analysis=true
      #|echo $foo
      #|
    ),
    spec=@checker.CheckSpec::default().with_extended_analysis(false),
  )
  let from_rc = @checker.check_script(
    (
      #|echo $foo
      #|
    ),
    spec=@checker.CheckSpec::default()
      .with_extended_analysis(false)
      .with_filename(Some("checker/testdata/rc/script.sh"))
      .with_config_files([
        ("checker/testdata/rc/.shellcheckrc", "extended-analysis=true"),
      ]),
  )

  assert_true(!checker_has_code(from_directive.diagnostics, 2154))
  assert_true(!checker_has_code(from_rc.diagnostics, 2154))
}

///|
test "checker localizes lint fixes to the reported filename" {
  let result = @checker.check_script(
    (
      #|echo `foo`
      #|
    ),
    spec=@checker.CheckSpec::default().with_filename(Some("script.sh")),
  )
  let diagnostic = checker_first_code(result.diagnostics, 2006)

  if diagnostic.fix is Some(fix) {
    assert_eq(fix.replacements[0].filename, "script.sh")
    @test.assert_eq(
      @fixer.apply_fix(fix, result.source),
      Some(
        (
          #|echo $(foo)
          #|
        ),
      ),
    )
  } else {
    panic()
  }
}
