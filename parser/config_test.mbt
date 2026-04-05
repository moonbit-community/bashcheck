///|
test "parse_config_report parses rc-style directives" {
  let report = @parser.parse_config_report(
    "disable=SC2006\nsource-path=SCRIPTDIR/lib\nexternal-sources=true\n# shellcheck enable=control-flow\n",
  )

  assert_eq(report.diagnostics.length(), 0)
  assert_eq(report.annotations.length(), 4)
  match report.annotations[0] {
    @parser.Annotation::Disable(code) => assert_eq(code, "SC2006")
    _ => abort("expected disable annotation")
  }
  match report.annotations[1] {
    @parser.Annotation::SourcePath(path) => assert_eq(path, "SCRIPTDIR/lib")
    _ => abort("expected source-path annotation")
  }
  match report.annotations[2] {
    @parser.Annotation::ExternalSources(flag) => assert_true(flag)
    _ => abort("expected external-sources annotation")
  }
  match report.annotations[3] {
    @parser.Annotation::Enable(name) => assert_eq(name, "control-flow")
    _ => abort("expected enable annotation")
  }
}

///|
test "parse_config_report keeps config diagnostics on the correct line" {
  let report = @parser.parse_config_report("# ordinary comment\nbogus line\n")

  assert_eq(report.annotations.length(), 0)
  assert_eq(report.diagnostics.length(), 1)
  assert_eq(report.diagnostics[0].code, Some(1125))
  assert_eq(report.diagnostics[0].span.start.line, 2)
}
