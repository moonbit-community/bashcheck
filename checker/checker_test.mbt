///|
fn checker_has_code(
  diagnostics : Array[PositionedDiagnostic],
  code : Int,
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
  diagnostics : Array[PositionedDiagnostic],
  code : Int,
) -> PositionedDiagnostic {
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
  let excluded = check_script(
    source,
    spec=CheckSpec::default().with_exclude_codes([2006]),
  )
  let included = check_script(
    source,
    spec=CheckSpec::default().with_include_codes([2006]),
  )

  assert_true(!checker_has_code(excluded.diagnostics, 2006))
  assert_true(checker_has_code(excluded.diagnostics, 2046))
  assert_true(checker_has_code(included.diagnostics, 2006))
  assert_true(!checker_has_code(included.diagnostics, 2046))
}

///|
test "checker honors severity thresholds and annotations" {
  let error = match parse_diagnostic_severity("error") {
    Some(severity) => severity
    None => panic()
  }
  let threshold = check_script(
    (
      #|#!/bin/dash
      #|((x += 1))
      #|rm $(ls)
      #|
    ),
    spec=CheckSpec::default().with_min_severity(error),
  )
  let annotated = check_script(
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
  let enabled = check_script(
    (
      #|echo $foo
      #|
    ),
  )
  let disabled = check_script(
    (
      #|echo $foo
      #|
    ),
    spec=CheckSpec::default().with_extended_analysis(false),
  )

  assert_true(checker_has_code(enabled.diagnostics, 2154))
  assert_true(!checker_has_code(disabled.diagnostics, 2154))
}

///|
test "checker emits SC2148 only when the entry shell stays unknown" {
  let plain = check_script(
    (
      #|echo hello
      #|
    ),
  )
  let from_directive = check_script(
    (
      #|# shellcheck shell=bash
      #|echo hello
      #|
    ),
  )
  let from_extension = check_script(
    (
      #|echo hello
      #|
    ),
    spec=CheckSpec::default().with_filename(Some("script.bash")),
  )
  let from_envrc = check_script(
    (
      #|echo hello
      #|
    ),
    spec=CheckSpec::default().with_filename(Some(".envrc")),
  )
  let from_override = check_script(
    (
      #|echo hello
      #|
    ),
    spec=CheckSpec::default().with_shell_override(
      Some(@semantics.ShellDialect::Dash),
    ),
  )

  assert_true(checker_has_code(plain.diagnostics, 2148))
  assert_true(!checker_has_code(from_directive.diagnostics, 2148))
  assert_true(!checker_has_code(from_extension.diagnostics, 2148))
  assert_true(checker_has_code(from_envrc.diagnostics, 2148))
  assert_true(!checker_has_code(from_override.diagnostics, 2148))
}

///|
test "checker shell precedence keeps stronger entry signals above filename hints" {
  let shebang_over_extension = check_script(
    (
      #|#!/bin/sh
      #|[[ x ]]
      #|
    ),
    spec=CheckSpec::default().with_filename(Some("script.bash")),
  )
  let directive_over_shebang = check_script(
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
test "checker advertises shellcheck-compatible optional checks without exposing control-flow" {
  assert_true(!supported_optional_checks().contains("control-flow"))
  assert_true(supported_optional_checks().contains("useless-use-of-cat"))
  assert_true(supported_optional_checks().contains("add-default-case"))
  assert_true(supported_optional_checks().contains("quote-safe-variables"))
  assert_true(supported_optional_checks().contains("avoid-nullary-conditions"))
  assert_true(supported_optional_checks().contains("avoid-negated-conditions"))
  assert_true(supported_optional_checks().contains("require-variable-braces"))
  assert_true(
    supported_optional_checks().contains("check-unassigned-uppercase"),
  )
  assert_true(supported_optional_checks().contains("require-double-brackets"))
  assert_true(supported_optional_checks().contains("check-set-e-suppressed"))
  assert_true(
    supported_optional_checks().contains("check-extra-masked-returns"),
  )
  assert_true(supported_optional_checks().contains("deprecate-which"))
  let descriptions = supported_checks()
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
  let enabled = check_script(
    (
      #|# shellcheck enable=control-flow
      #| echo $foo
      #|
    ),
    spec=CheckSpec::default().with_extended_analysis(false),
  )
  let disabled = check_script(
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
  let from_spec = check_script(
    (
      #|safe=hello
      #|echo $safe
      #|
    ),
    spec=CheckSpec::default().with_optional_checks(["quote-safe-variables"]),
  )
  let from_directive = check_script(
    (
      #|# shellcheck enable=require-double-brackets
      #|[ -x foo ]
      #|
    ),
  )
  let default_result = check_script(
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
  let with_rc = check_script(
    (
      #|printf '%s' `foo`
      #|
    ),
    spec=CheckSpec::default()
      .with_filename(Some("checker/testdata/rc/script.sh"))
      .with_config_files([
        ("checker/testdata/rc/.shellcheckrc", "disable=SC2006"),
      ]),
  )
  let without_rc = check_script(
    (
      #|printf '%s' `foo`
      #|
    ),
    spec=CheckSpec::default()
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
  let result = check_script(
    (
      #|printf '%s' `foo`
      #|
    ),
    spec=CheckSpec::default()
      .with_config_path_override(Some("custom.rc"))
      .with_config_files([("custom.rc", "disable=SC2006")]),
  )

  assert_true(!checker_has_code(result.diagnostics, 2006))
}

///|
test "checker keeps explicit extended analysis overrides above directives and rc" {
  let from_directive = check_script(
    (
      #|# shellcheck extended-analysis=true
      #|echo $foo
      #|
    ),
    spec=CheckSpec::default().with_extended_analysis(false),
  )
  let from_rc = check_script(
    (
      #|echo $foo
      #|
    ),
    spec=CheckSpec::default()
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
  let result = check_script(
    (
      #|echo `foo`
      #|
    ),
    spec=CheckSpec::default().with_filename(Some("script.sh")),
  )
  let diagnostic = checker_first_code(result.diagnostics, 2006)

  match diagnostic.fix {
    Some(fix) => {
      assert_eq(fix.replacements[0].filename, "script.sh")
      assert_eq(
        @fixer.apply_fix(fix, result.source),
        Some(
          (
            #|echo $(foo)
            #|
          ),
        ),
      )
    }
    None => panic()
  }
}
