///|
fn batch_k_count_warning_code(
  diagnostics : Array[CheckDiagnostic],
  code : Int,
) -> Int {
  let mut count = 0
  for diagnostic in diagnostics {
    if diagnostic.code == code && diagnostic.severity is CheckSeverity::Warning {
      count += 1
    }
  }
  count
}

///|
fn batch_k_first_warning_code(
  diagnostics : Array[CheckDiagnostic],
  code : Int,
) -> CheckDiagnostic {
  for diagnostic in diagnostics {
    if diagnostic.code == code && diagnostic.severity is CheckSeverity::Warning {
      return diagnostic
    }
  }
  checks_fail("missing warning diagnostic code \{code}")
}

///|
test "analytics batch k flags while-read pitfalls and shellcheck-style fixes" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|while read -r foo; do ssh "$foo" uptime; done
      #|while read -r foo; do ffmpeg -i foo.mkv bar.mkv -an; done
      #|while read -r foo; do mplayer foo.ogv > file; done
      #|while read -r foo; do HandBrakeCLI foo.mkv -o out.mkv; done
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2095), 8)
  assert_eq(batch_k_count_warning_code(diagnostics, 2095), 4)
  match batch_k_first_warning_code(diagnostics, 2095).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(
          fix,
          (
            #|#!/bin/bash
            #|while read -r foo; do ssh "$foo" uptime; done
            #|while read -r foo; do ffmpeg -i foo.mkv bar.mkv -an; done
            #|while read -r foo; do mplayer foo.ogv > file; done
            #|while read -r foo; do HandBrakeCLI foo.mkv -o out.mkv; done
            #|,
          ),
        ),
        Some(
          (
            #|#!/bin/bash
            #|while read -r foo; do ssh -n "$foo" uptime; done
            #|while read -r foo; do ffmpeg -i foo.mkv bar.mkv -an; done
            #|while read -r foo; do mplayer foo.ogv > file; done
            #|while read -r foo; do HandBrakeCLI foo.mkv -o out.mkv; done
            #|,
          ),
        ),
      )
    None => checks_fail("expected SC2095 fix")
  }
}

///|
test "analytics batch k ignores stdin-safe read conditions and pipeline-second commands" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|while read -r foo <&3; do ssh "$foo" uptime; done 3< file
      #|while read -r foo; do echo ls | ssh "$foo" uptime; done < file
      #|while read -r foo; do ssh -n "$foo" uptime; done < file
      #|while read -r foo; do ffmpeg -nostdin -i foo.mkv bar.mkv -an; done
      #|while read -r foo; do mplayer foo.ogv <<< q; done
      #|while read -r foo; do HandBrakeCLI foo.mkv -o out.mkv < /dev/null; done
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2095))
}

///|
test "analytics batch k flags nested command substitutions inside while-read loops" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|while read -r foo; do x=$(ssh host cmd); done
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2095), 2)
  match batch_k_first_warning_code(diagnostics, 2095).fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(
          fix,
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2034
            #|while read -r foo; do x=$(ssh host cmd); done
            #|,
          ),
        ),
        Some(
          (
            #|#!/bin/bash
            #|# shellcheck disable=SC2034
            #|while read -r foo; do x=$(ssh -n host cmd); done
            #|,
          ),
        ),
      )
    None => checks_fail("expected nested SC2095 fix")
  }
}

///|
test "analytics batch k keeps background spans aligned with shellcheck" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|while read -r foo; do ssh "$foo" uptime & done
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2095), 2)
  let warning = batch_k_first_warning_code(diagnostics, 2095)
  assert_eq(warning.span.start.column, 23)
  assert_eq(warning.span.end.column, 40)
  match warning.fix {
    Some(fix) =>
      assert_eq(
        @fixer.apply_fix(
          fix,
          (
            #|#!/bin/bash
            #|while read -r foo; do ssh "$foo" uptime & done
            #|,
          ),
        ),
        Some(
          (
            #|#!/bin/bash
            #|while read -r foo; do ssh -n "$foo" uptime & done
            #|,
          ),
        ),
      )
    None => checks_fail("expected background SC2095 fix")
  }
}
