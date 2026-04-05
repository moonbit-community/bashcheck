# bashcheck/checker

`checker` is the public library entry point for end-to-end linting. It glues
`parser`, `semantics`, `checks`, config loading, and diagnostic filtering into
one `check_script` call.

## Run End-To-End Checking From Raw Source

`check_script` is the package entry point most callers should start from. It
parses source text, resolves config and shell context from `CheckSpec`, runs the
rule engine, and returns one `CheckResult` containing filename-aware
`PositionedDiagnostic` values.

```mbt check
///|
fn checker_doc_has_code(
  diagnostics : Array[@checker.PositionedDiagnostic],
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
test "doc checker returns positioned diagnostics from raw source" {
  let result = @checker.check_script("echo `foo`\n")

  assert_true(checker_doc_has_code(result.diagnostics, 2006))
}
```

## Shape What Gets Reported With `CheckSpec`

`CheckSpec` is where end-to-end behavior lives: shell overrides, filename
context, rc loading, source resolution, code inclusion/exclusion, minimum
severity, and optional checks. `parse_diagnostic_severity` helps UIs and CLIs
convert user input into the public `DiagnosticSeverity` enum.

```mbt check
///|
test "doc checker lets callers control severity and optional checks" {
  let error = match @checker.parse_diagnostic_severity("error") {
    Some(severity) => severity
    None => abort("missing severity")
  }
  let thresholded = @checker.check_script(
    "rm $(ls)\n",
    spec=@checker.CheckSpec::default().with_min_severity(error),
  )
  let optional = @checker.check_script(
    "safe=hello\necho $safe\n",
    spec=@checker.CheckSpec::default().with_optional_checks([
      "quote-safe-variables",
    ]),
  )

  assert_true(!checker_doc_has_code(thresholded.diagnostics, 2046))
  assert_true(checker_doc_has_code(optional.diagnostics, 2248))
}
```

## Filter, Sort, And Discover Diagnostics After Checking

For secondary processing, `filter_diagnostics` and `sort_diagnostics` work on
plain arrays of `PositionedDiagnostic`, while `supported_checks`,
`supported_optional_checks`, and `list_optional_checks_text` expose the rule set
for help output or integration UIs.

```mbt check
///|
test "doc checker exposes discovery and post-processing helpers" {
  let result = @checker.check_script("echo `foo`\nrm $(ls)\n")
  let filtered = @checker.filter_diagnostics(
    result.diagnostics,
    @checker.CheckSpec::default().with_include_codes([2006]),
  )
  let sorted = @checker.sort_diagnostics(result.diagnostics)

  assert_eq(filtered.length(), 1)
  assert_true(checker_doc_has_code(filtered, 2006))
  assert_eq(sorted.length(), result.diagnostics.length())
  assert_true(@checker.supported_checks().length() > 0)
  assert_true(
    @checker.supported_optional_checks().contains("quote-safe-variables"),
  )
  assert_true(@checker.list_optional_checks_text().contains("name:"))
}
```
