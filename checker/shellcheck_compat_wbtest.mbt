///|
fn compat_spec() -> CheckSpec {
  CheckSpec::default().with_exclude_codes([2148])
}

///|
fn[A] compat_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn compat_codes(
  source : String,
  spec? : CheckSpec = compat_spec(),
) -> Array[Int] {
  let result = check_script(source, spec~)
  let codes : Array[Int] = []
  for diagnostic in result.diagnostics {
    match diagnostic.code {
      Some(code) => codes.push(code)
      None => ()
    }
  }
  sort_ints(codes)
}

///|
fn assert_compat_codes(
  label : String,
  source : String,
  expected : Array[Int],
  spec? : CheckSpec = compat_spec(),
) -> Unit {
  let actual = compat_codes(source, spec~)
  if actual != expected {
    compat_fail("\{label}: expected \{expected}, got \{actual}")
  }
}

///|
fn assert_compat_contains_code(
  label : String,
  source : String,
  expected : Int,
  spec? : CheckSpec = compat_spec(),
) -> Unit {
  let actual = compat_codes(source, spec~)
  if !actual.contains(expected) {
    compat_fail("\{label}: expected code \{expected}, got \{actual}")
  }
}

///|
fn compat_rc_spec(contents : String) -> CheckSpec {
  compat_spec()
  .with_filename(Some("checker/testdata/rc/script.sh"))
  .with_config_files([("checker/testdata/rc/.shellcheckrc", contents)])
}

///|
fn assert_compat_diagnostic_at_line(
  label : String,
  source : String,
  line : Int,
  code : Int,
  severity : DiagnosticSeverity,
  spec? : CheckSpec = compat_spec(),
) -> Unit {
  let result = check_script(source, spec~)
  for diagnostic in result.diagnostics {
    if diagnostic.code == Some(code) && diagnostic.span.start.line == line {
      if diagnostic.severity == severity {
        return
      }
      compat_fail(
        "\{label}: expected SC\{code} at line \{line} to have severity \{severity}, got \{diagnostic.severity}",
      )
    }
  }
  compat_fail("\{label}: expected SC\{code} at line \{line}")
}

///|
fn external_sources_annotation(
  annotations : Array[@parser.Annotation],
) -> Bool? {
  let mut flag : Bool? = None
  for annotation in annotations {
    match annotation {
      @parser.Annotation::ExternalSources(enabled) => flag = Some(enabled)
      _ => ()
    }
  }
  flag
}

///|
fn assert_effective_external_sources(
  label : String,
  spec : CheckSpec,
  expected_effective : Bool,
  expected_annotation : Bool?,
) -> Unit {
  let config = load_config(spec)
  if config.diagnostics.length() != 0 {
    compat_fail(
      "\{label}: expected rc parsing without diagnostics, got \{config.diagnostics.length()} diagnostics",
    )
  }
  let actual_annotation = external_sources_annotation(config.annotations)
  if actual_annotation != expected_annotation {
    compat_fail(
      "\{label}: expected rc external-sources annotation \{expected_annotation}, got \{actual_annotation}",
    )
  }
  let effective = apply_config_to_spec(spec, config.annotations)
  if effective.external_sources != expected_effective {
    compat_fail(
      "\{label}: expected effective external_sources=\{expected_effective}, got \{effective.external_sources}",
    )
  }
}

///|
fn sort_ints(values : Array[Int]) -> Array[Int] {
  let sorted : Array[Int] = []
  for value in values {
    sorted.push(value)
  }
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      if sorted[j] < sorted[i] {
        let current = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = current
      }
      j += 1
    }
    i += 1
  }
  sorted
}

///|
test "shellcheck checker basic compatibility props" {
  assert_compat_codes("prop_findsParseIssue", "echo \"$12\"", [1037])
  assert_compat_codes(
    "prop_commentDisablesParseIssue1",
    (
      #|#shellcheck disable=SC1037
      #|echo "$12"
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_commentDisablesParseIssue2",
    (
      #|#shellcheck disable=SC1037
      #|#lol
      #|echo "$12"
      #|
    ),
    [],
  )
  assert_compat_codes("prop_findsAnalysisIssue", "echo $1", [2086])
  assert_compat_codes(
    "prop_commentDisablesAnalysisIssue1",
    (
      #|#shellcheck disable=SC2086
      #|echo $1
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_commentDisablesAnalysisIssue2",
    (
      #|#shellcheck disable=SC2086
      #|#lol
      #|echo $1
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_optionDisablesIssue1",
    "echo $1",
    [],
    spec=CheckSpec::default().with_exclude_codes([2148, 2086]),
  )
  assert_compat_codes(
    "prop_optionDisablesIssue2",
    "echo \"$10\"",
    [],
    spec=CheckSpec::default().with_exclude_codes([2148, 1037]),
  )
  assert_compat_codes(
    "prop_annotationDisablesBadShebang",
    (
      #|#!/usr/bin/python
      #|# shellcheck shell=sh
      #|true
      #|
    ),
    [],
    spec=CheckSpec::default(),
  )
  assert_compat_codes(
    "prop_optionDisablesBadShebang",
    (
      #|#!/usr/bin/python
      #|true
      #|
    ),
    [],
    spec=CheckSpec::default().with_shell_override(
      Some(@semantics.ShellDialect::Sh),
    ),
  )
  assert_compat_codes("prop_canParseDevNull", "source /dev/null", [])
}

///|
test "shellcheck checker filename compatibility props" {
  assert_compat_codes(
    "prop_deducesTypeFromExtension",
    "(( 3.14 ))",
    [],
    spec=compat_spec().with_filename(Some("file.ksh")),
  )
  assert_compat_codes(
    "prop_deducesTypeFromExtension2",
    "(( 3.14 ))",
    [2079],
    spec=compat_spec().with_filename(Some("file.bash")),
  )
  assert_compat_codes(
    "prop_deducesTypeFromEnvrcExtension",
    "(( 3.14 ))",
    [2079],
    spec=compat_spec().with_filename(Some(".envrc")),
  )
  assert_compat_codes(
    "prop_canDisableShebangWarning",
    (
      #|#shellcheck disable=SC2148
      #|foo
      #|
    ),
    [],
    spec=CheckSpec::default().with_filename(Some("file.sh")),
  )
}

///|
test "shellcheck checker parse and include compatibility props" {
  assert_compat_codes(
    "prop_wontParseBadShell",
    (
      #|#!/usr/bin/python
      #|true $1
      #|
    ),
    [1071],
    spec=CheckSpec::default(),
  )
  assert_compat_codes(
    "prop_canDisableParseErrors",
    (
      #|#shellcheck disable=SC1073,SC1072,SC2148
      #|()
      #|
    ),
    [],
    spec=CheckSpec::default().with_filename(Some("file.sh")),
  )
  assert_compat_codes(
    "prop_shExtensionDoesntMatter",
    (
      #|echo 'hello world'
      #|
    ),
    [2148],
    spec=CheckSpec::default().with_filename(Some("file.sh")),
  )
  assert_compat_codes(
    "prop_canEnableOptionalsWithSpec",
    (
      #|#!/bin/sh
      #|[ "$1" ]
      #|
    ),
    [2244],
    spec=CheckSpec::default()
      .with_filename(Some("file.sh"))
      .with_optional_checks(["avoid-nullary-conditions"]),
  )
  assert_compat_codes(
    "prop_optionIncludes1",
    (
      #|#!/bin/sh
      #| var='a b'
      #| echo $var
      #|
    ),
    [],
    spec=CheckSpec::default().with_include_codes([2080]),
  )
  assert_compat_codes(
    "prop_optionIncludes2",
    (
      #|#!/bin/sh
      #| var='a b'
      #| echo $var
      #|
    ),
    [2086],
    spec=CheckSpec::default().with_include_codes([2086]),
  )
  assert_compat_codes(
    "prop_optionIncludes3",
    (
      #|#!/bin/sh
      #| var='a b'
      #| echo $var
      #|
    ),
    [2086],
    spec=CheckSpec::default(),
  )
  assert_compat_codes(
    "prop_optionIncludes4",
    (
      #|#!/bin/sh
      #| var='a b'
      #| echo $var
      #| echo $bar
      #|
    ),
    [2154],
    spec=CheckSpec::default().with_include_codes([2154]),
  )
}

///|
test "shellcheck checker rc compatibility props" {
  assert_compat_codes(
    "prop_readsRcFile",
    (
      #|#!/bin/sh
      #|echo $1
      #|
    ),
    [],
    spec=compat_rc_spec("disable=2086"),
  )
  assert_compat_codes(
    "prop_canUseNoRC",
    (
      #|#!/bin/sh
      #|echo $1
      #|
    ),
    [2086],
    spec=compat_rc_spec("disable=2086").with_ignore_rc(true),
  )
  assert_compat_codes(
    "prop_NoRCWontLookAtFile",
    (
      #|#!/bin/sh
      #|echo $1
      #|
    ),
    [2086],
    spec=CheckSpec::default()
      .with_filename(Some("checker/testdata/rc/script.sh"))
      .with_ignore_rc(true),
  )
  assert_compat_codes(
    "prop_brokenRcGetsWarning",
    (
      #|#!/bin/sh
      #|echo $1
      #|
    ),
    [1134, 2086],
    spec=compat_rc_spec("rofl"),
  )
  assert_compat_codes(
    "prop_canEnableOptionalsWithRc",
    (
      #|#!/bin/sh
      #|[ "$1" ]
      #|
    ),
    [2244],
    spec=compat_rc_spec("enable=avoid-nullary-conditions"),
  )
  assert_compat_codes(
    "prop_rcCanSuppressEarlyProblems1",
    (
      #|#!/bin/zsh
      #|echo $1
      #|
    ),
    [],
    spec=compat_rc_spec("disable=1071"),
  )
  assert_compat_codes(
    "prop_rcCanSuppressEarlyProblems2",
    (
      #|!/bin/bash
      #|echo 'hello world'
      #|
    ),
    [],
    spec=compat_rc_spec("disable=1104"),
  )
  assert_compat_codes(
    "prop_rcCanSuppressDfa",
    (
      #|#!/bin/sh
      #|exit; foo;
      #|
    ),
    [],
    spec=compat_rc_spec("extended-analysis=false"),
  )
  assert_compat_codes(
    "prop_fileCanSuppressDfa",
    (
      #|#!/bin/sh
      #|# shellcheck extended-analysis=false
      #|exit; foo;
      #|
    ),
    [],
    spec=compat_rc_spec(""),
  )
  assert_compat_codes(
    "prop_fileWinsWhenSuppressingDfa1",
    (
      #|#!/bin/sh
      #|# shellcheck extended-analysis=false
      #|exit; foo;
      #|
    ),
    [],
    spec=compat_rc_spec("extended-analysis=true"),
  )
  assert_compat_codes(
    "prop_fileWinsWhenSuppressingDfa2",
    (
      #|#!/bin/sh
      #|# shellcheck extended-analysis=true
      #|exit; foo;
      #|
    ),
    [2317],
    spec=compat_rc_spec("extended-analysis=false"),
  )
  assert_compat_codes(
    "prop_flagWinsWhenSuppressingDfa1",
    (
      #|#!/bin/sh
      #|# shellcheck extended-analysis=false
      #|exit; foo;
      #|
    ),
    [2317],
    spec=compat_rc_spec("extended-analysis=false").with_extended_analysis(true),
  )
  assert_compat_codes(
    "prop_flagWinsWhenSuppressingDfa2",
    (
      #|#!/bin/sh
      #|# shellcheck extended-analysis=true
      #|exit; foo;
      #|
    ),
    [],
    spec=compat_rc_spec("extended-analysis=true").with_extended_analysis(false),
  )
}

///|
test "shellcheck checker source-path and external sources compatibility props" {
  let source_path_spec = compat_spec()
    .with_filename(Some("dir/myscript"))
    .with_check_sourced(true)
    .add_source_path("foo")
  assert_compat_codes(
    "prop_sourcePathRedirectsName",
    (
      #|#!/bin/bash
      #|source lib
      #|
    ),
    [2086],
    spec={ ..source_path_spec, source_files: [("foo/lib", "echo $1")] },
  )

  let source_path_annotation_spec = compat_spec()
    .with_filename(Some("dir/myscript"))
    .with_check_sourced(true)
  assert_compat_codes(
    "prop_sourcePathAddsAnnotation",
    (
      #|#!/bin/bash
      #|# shellcheck source-path=mypath
      #|source lib
      #|
    ),
    [2086],
    spec={
      ..source_path_annotation_spec,
      source_files: [("mypath/lib", "echo $1")],
    },
  )
  assert_compat_codes(
    "prop_sourcePathWorksWithSpaces",
    (
      #|#!/bin/bash
      #|# shellcheck source-path='my path'
      #|source lib
      #|
    ),
    [2086],
    spec={
      ..source_path_annotation_spec,
      source_files: [("my path/lib", "echo $1")],
    },
  )
  assert_compat_codes(
    "prop_sourcePathRedirectsDirective",
    (
      #|#!/bin/bash
      #|# shellcheck source=lib
      #|source kittens
      #|
    ),
    [2086],
    spec={ ..source_path_spec, source_files: [("foo/lib", "echo $1")] },
  )

  // Adapted coverage: upstream uses a mock resolver to observe the
  // tri-state external-sources setting. Here we assert the effective rc
  // annotation plus the observable checker behavior it drives.
  assert_effective_external_sources(
    "prop_rcCanAllowExternalSources",
    compat_rc_spec("external-sources=true"),
    true,
    Some(true),
  )
  assert_effective_external_sources(
    "prop_rcCanDenyExternalSources",
    compat_rc_spec("external-sources=false"),
    false,
    Some(false),
  )
  assert_effective_external_sources(
    "prop_rcCanLeaveExternalSourcesUnspecified",
    compat_rc_spec(""),
    false,
    None,
  )

  let file_disable_external_spec = compat_rc_spec("external-sources=true").with_check_sourced(
    true,
  )
  assert_compat_codes(
    "prop_fileCanDisableExternalSources",
    (
      #|#!/bin/bash
      #|true
      #|source withExternal
      #|# shellcheck external-sources=false
      #|source withoutExternal
      #|
    ),
    [1091, 1091],
    spec=file_disable_external_spec,
  )
  assert_compat_diagnostic_at_line(
    "prop_fileCanDisableExternalSources",
    (
      #|#!/bin/bash
      #|true
      #|source withExternal
      #|# shellcheck external-sources=false
      #|source withoutExternal
      #|
    ),
    3,
    1091,
    DiagnosticSeverity::Info,
    spec=file_disable_external_spec,
  )
  assert_compat_diagnostic_at_line(
    "prop_fileCanDisableExternalSources",
    (
      #|#!/bin/bash
      #|true
      #|source withExternal
      #|# shellcheck external-sources=false
      #|source withoutExternal
      #|
    ),
    5,
    1091,
    DiagnosticSeverity::Warning,
    spec=file_disable_external_spec,
  )

  let file_cannot_enable_external_spec = {
    ..compat_spec().with_filename(Some("dir/myscript")).with_check_sourced(true),
    source_files: [("foo", "true")],
  }
  assert_compat_codes(
    "prop_fileCannotEnableExternalSources",
    (
      #|#!/bin/bash
      #|# shellcheck external-sources=true
      #|source foo
      #|
    ),
    [1144],
    spec=file_cannot_enable_external_spec,
  )
  assert_compat_codes(
    "prop_fileCannotEnableExternalSources2",
    (
      #|#!/bin/bash
      #|# shellcheck external-sources=true
      #|source foo
      #|
    ),
    [1144],
    spec={
      ..file_cannot_enable_external_spec,
      config_files: [
        ("checker/testdata/rc/.shellcheckrc", "external-sources=false"),
      ],
      filename: Some("checker/testdata/rc/script.sh"),
    },
  )

  assert_compat_codes(
    "prop_sourcedFileUsesOriginalShellExtension",
    "source file.ksh",
    [2079],
    spec={
      ..CheckSpec::default()
      .with_filename(Some("file.bash"))
      .with_check_sourced(true),
      source_files: [("file.ksh", "(( 3.14 ))")],
    },
  )
}

///|
test "shellcheck checker parser edge compatibility props" {
  assert_compat_codes(
    "prop_sourceWithHereDocWorks",
    (
      #|source bar << eof
      #|lol
      #|eof
      #|
    ),
    [],
    spec={
      ..compat_spec(),
      check_sourced: true,
      source_files: [("bar", "true\n")],
    },
  )
  assert_compat_contains_code(
    "prop_hereDocsAreParsedWithoutTrailingLinefeed", "cat << eof", 1044,
  )
  assert_compat_codes(
    "prop_hereDocsWillHaveParsedIndices",
    (
      #|#!/bin/bash
      #|my_array=(a b)
      #|cat <<EOF >> ./test
      #| $(( 1 + my_array[1] ))
      #|EOF
      #|
    ),
    [],
  )
  assert_compat_contains_code(
    "prop_sourcePartOfOriginalScript",
    (
      #|#!/bin/sh
      #|source ./saywhat.sh
      #|
    ),
    3046,
  )
  assert_compat_codes(
    "prop_spinBug1413",
    (
      #|fun() {
      #|# shellcheck disable=SC2188
      #|> /dev/null
      #|}
      #|
    ),
    [],
  )
}

///|
test "shellcheck checker filewide annotation compatibility props" {
  assert_compat_codes("prop_filewideAnnotationBase", "#!/bin/sh\necho $1", [
    2086,
  ])
  assert_compat_codes(
    "prop_filewideAnnotation1",
    (
      #|#!/bin/sh
      #|# shellcheck disable=2086
      #|echo $1
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_filewideAnnotation2",
    (
      #|#!/bin/sh
      #|# shellcheck disable=2086
      #|true
      #|echo $1
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_filewideAnnotation3",
    (
      #|#!/bin/sh
      #|#unrelated
      #|# shellcheck disable=2086
      #|true
      #|echo $1
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_filewideAnnotation4",
    (
      #|#!/bin/sh
      #|# shellcheck disable=2086
      #|#unrelated
      #|true
      #|echo $1
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_filewideAnnotation5",
    (
      #|#!/bin/sh
      #|
      #|
      #|
      #|
      #|#shellcheck disable=2086
      #|true
      #|echo $1
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_filewideAnnotation6",
    (
      #|#shellcheck shell=sh
      #|#unrelated
      #|#shellcheck disable=2086
      #|true
      #|echo $1
      #|
    ),
    [],
    spec=CheckSpec::default(),
  )
  assert_compat_codes(
    "prop_filewideAnnotation7",
    (
      #|#!/bin/sh
      #|# shellcheck disable=2086
      #|#unrelated
      #|true
      #|echo $1
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_filewideAnnotationBase2",
    "true\n[ $? == 0 ] && echo $1",
    [2086, 2181],
  )
  assert_compat_codes(
    "prop_filewideAnnotation8",
    (
      #|# Disable $? warning
      #|#shellcheck disable=SC2181
      #|# Disable quoting warning
      #|#shellcheck disable=2086
      #|true
      #|[ $? == 0 ] && echo $1
      #|
    ),
    [],
  )
  assert_compat_codes(
    "prop_canDisableAllWarnings",
    (
      #|#!/bin/sh
      #|echo $1
      #|#shellcheck disable=all
      #|echo `echo $1`
      #|
    ),
    [2086],
  )
}

///|
test "shellcheck checker source and recursion compatibility props" {
  assert_compat_codes(
    "prop_failsWhenNotSourcing",
    "source lol; echo \"$bar\"",
    [1091, 2154],
  )
  assert_compat_codes(
    "prop_worksWhenSourcing",
    "source lib; echo \"$bar\"",
    [],
    spec={
      ..compat_spec(),
      check_sourced: true,
      source_files: [("lib", "bar=1")],
    },
  )
  assert_compat_codes(
    "prop_worksWhenSourcingWithDashDash",
    "source -- lib; echo \"$bar\"",
    [],
    spec={
      ..compat_spec(),
      check_sourced: true,
      source_files: [("lib", "bar=1")],
    },
  )
  assert_compat_codes(
    "prop_worksWhenSourcingWithDashP",
    "source -p \"$MYPATH\" lib; echo \"$bar\"",
    [],
    spec={
      ..compat_spec(),
      check_sourced: true,
      source_files: [("lib", "bar=1")],
    },
  )
  assert_compat_codes("prop_worksWhenDotting", ". lib; echo \"$bar\"", [], spec={
    ..compat_spec(),
    check_sourced: true,
    source_files: [("lib", "bar=1")],
  })
  assert_compat_codes("prop_noInfiniteSourcing", "source lib", [], spec={
    ..compat_spec(),
    check_sourced: true,
    source_files: [("lib", "source lib")],
  })
  assert_compat_codes(
    "prop_canSourceBadSyntax",
    "source lib; echo $1",
    [1094, 2086],
    spec={
      ..compat_spec(),
      check_sourced: true,
      source_files: [("lib", "for f; do")],
    },
  )
  assert_compat_codes("prop_cantSourceDynamic", ". \"$1\"", [1090], spec={
    ..compat_spec(),
    check_sourced: true,
    source_files: [("lib", "")],
  })
  assert_compat_codes("prop_cantSourceDynamic2", "source ~/foo", [1090], spec={
    ..compat_spec(),
    check_sourced: true,
    source_files: [("lib", "")],
  })
  assert_compat_codes(
    "prop_canStripPrefixAndSource",
    "source \"$MYDIR/lib\"",
    [],
    spec={ ..compat_spec(), check_sourced: true, source_files: [("./lib", "")] },
  )
  assert_compat_codes(
    "prop_canStripPrefixAndSource2",
    "source \"$(dirname \"${BASH_SOURCE[0]}\")/utils.sh\"",
    [],
    spec={
      ..compat_spec(),
      check_sourced: true,
      source_files: [("./utils.sh", "")],
    },
  )
  assert_compat_codes(
    "prop_canSourceDynamicWhenRedirected",
    (
      #|#shellcheck source=lib
      #|. "$1"
      #|
    ),
    [],
    spec={ ..compat_spec(), check_sourced: true, source_files: [("lib", "")] },
  )
  assert_compat_codes(
    "prop_canRedirectWithSpaces",
    (
      #|#shellcheck source="my file"
      #|. "$1"
      #|
    ),
    [],
    spec={
      ..compat_spec(),
      check_sourced: true,
      source_files: [("my file", "")],
    },
  )
  assert_compat_codes("prop_recursiveAnalysis", "source lib", [2086], spec={
    ..compat_spec(),
    check_sourced: true,
    source_files: [("lib", "echo $1")],
  })
  assert_compat_codes("prop_recursiveParsing", "source lib", [1037], spec={
    ..compat_spec(),
    check_sourced: true,
    source_files: [("lib", "echo \"$10\"")],
  })
  assert_compat_codes("prop_nonRecursiveAnalysis", "source lib", [], spec={
    ..compat_spec(),
    source_files: [("lib", "echo $1")],
  })
  assert_compat_codes("prop_nonRecursiveParsing", "source lib", [], spec={
    ..compat_spec(),
    source_files: [("lib", "echo \"$10\"")],
  })
  assert_compat_codes(
    "prop_sourceDirectiveDoesntFollowFile",
    (
      #|#shellcheck source=foo
      #|. "$1"; echo "$baz"
      #|
    ),
    [],
    spec={
      ..compat_spec(),
      check_sourced: true,
      source_files: [("foo", "source bar"), ("bar", "baz=3")],
    },
  )
}
