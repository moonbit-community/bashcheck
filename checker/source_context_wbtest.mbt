///|
test "source analysis runs before sourced diagnostic filtering" {
  let source = "#!/bin/bash\nsource lib.sh\necho \"$bar\"\n"
  let spec = {
    ..CheckSpec::default(),
    ignore_rc: true,
    filename: Some("main.sh"),
    source_files: [("lib.sh", "bar='hello world'\necho $bar\n")],
  }
  let hidden = test_check_script(source, spec~)
  assert_true(hidden.diagnostics.is_empty())
  let visible = test_check_script(source, spec=spec.with_check_sourced(true))
  assert_eq(visible.diagnostics.length(), 1)
  let diagnostic = visible.diagnostics[0]
  assert_eq(diagnostic.code, Some(2086))
  assert_eq(diagnostic.filename, "lib.sh")
  assert_eq(diagnostic.span.start.source_id, 1)
  assert_eq(visible.sources[1].source, spec.source_files[0].1)
  assert_true(visible.sources[1].parent is Some((0, _)))
  let fix = diagnostic.fix.unwrap()
  assert_true(
    fix.replacements.all(replacement => {
      replacement.filename == "lib.sh" &&
      replacement.start.source_id == 1 &&
      replacement.end.source_id == 1
    }),
  )
}

///|
test "repeated includes retain independent suppression contexts" {
  let source = "#!/bin/bash\ntrue\n# shellcheck disable=SC2086\nsource lib.sh\nsource lib.sh\n"
  let spec = {
    ..CheckSpec::default(),
    ignore_rc: true,
    filename: Some("main.sh"),
    check_sourced: true,
    source_files: [("lib.sh", "echo $1\n")],
  }
  let result = test_check_script(source, spec~)
  assert_eq(result.sources.length(), 3)
  assert_eq(result.sources[1].source, result.sources[2].source)
  assert_true(
    result.sources[1].parent is Some((0, { start: { line: 4, .. }, .. })),
  )
  assert_true(
    result.sources[2].parent is Some((0, { start: { line: 5, .. }, .. })),
  )
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(result.diagnostics[0].code, Some(2086))
  assert_eq(result.diagnostics[0].span.start.source_id, 2)
}

///|
test "cached source read failures finish the request loop" {
  let spec = {
    ..CheckSpec::default(),
    ignore_rc: true,
    filename: Some("main.sh"),
    external_sources: true,
    allowed_files: Some(["main.sh"]),
    source_aliases: [("missing.sh", "missing.sh")],
    failed_sources: [("missing.sh", "missing.sh: read denied")],
  }
  let source = "#!/bin/bash\nsource missing.sh\n"
  let report = prepare_script(source, spec~)
  assert_true(report.requests.is_empty())
  let result = check_prepared_script(source, report, spec~)
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(result.diagnostics[0].code, Some(1091))
  assert_eq(
    result.diagnostics[0].message,
    "Not following: missing.sh: read denied",
  )
}

///|
test "source depth stops before requesting another file and respects filters" {
  let source_files : Array[(String, String)] = []
  for i in 0..<100 {
    source_files.push(("f\{i}.sh", "source f\{i + 1}.sh\n"))
  }
  let spec = {
    ..CheckSpec::default(),
    ignore_rc: true,
    filename: Some("main.sh"),
    check_sourced: true,
    external_sources: true,
    source_files,
  }
  let source = "#!/bin/bash\nsource f0.sh\n"
  let report = prepare_script(source, spec~)
  assert_true(report.requests.is_empty())
  assert_eq(report.sources.length(), 101)
  let result = check_prepared_script(source, report, spec~)
  assert_eq(result.diagnostics.length(), 1)
  let diagnostic = result.diagnostics[0]
  assert_eq(diagnostic.code, Some(1093))
  assert_eq(diagnostic.severity, Info)
  assert_eq(
    diagnostic.message,
    "This file appears to be recursively sourced. Ignoring.",
  )
  assert_eq(diagnostic.filename, "f99.sh")
  assert_eq(diagnostic.span.start.source_id, 100)
  for
    filtered in [
      spec.with_check_sourced(false),
      spec.with_min_severity(Warning),
      spec.with_exclude_codes([1093]),
    ] {
    assert_true(test_check_script(source, spec=filtered).diagnostics.is_empty())
  }
  source_files[99] = ("f99.sh", "# shellcheck disable=SC1093\nsource f100.sh\n")
  assert_true(test_check_script(source, spec~).diagnostics.is_empty())
  source_files[99] = ("f99.sh", "true\n")
  assert_true(test_check_script(source, spec~).diagnostics.is_empty())
}
