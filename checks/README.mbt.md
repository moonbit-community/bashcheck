# bashcheck/checks

`checks` is the first linting layer on top of `parser` and `semantics`. It
implements a focused batch of ShellCheck-style AST checks plus a shell-support
pass for `sh`/`dash` compatibility warnings.

## Run The Built-In Rule Engine On A Parsed Script

`check_script` is the most convenient entry point when you already have a
parsed `parser.Script`. It infers the shell from `CheckOptions`, runs the core
rule suites, and returns package-local `CheckDiagnostic` values. If the caller
already knows the shell dialect, `run_checks_with_shell` skips that inference
step and makes the shell choice explicit.

```mbt check
///|
test "doc checks runs the default rule suites" {
  let script = match
    @parser.parse_script("#!/bin/sh\nsource lib.sh\nprintf '%s' $(date)\n") {
    Ok(script) => script
    Err(err) => abort(err.to_string())
  }
  let diagnostics = @checks.check_script(script)

  assert_true(diagnostics.length() >= 2)
  assert_eq(diagnostics[0].code, 3046)
  assert_eq(diagnostics[1].code, 2046)
}
```

## Turn On Optional Analyses And Discover What Exists

Optional behavior lives in `CheckOptions`, `supported_optional_checks`,
`supported_optional_check_infos`, and `supports_optional_check_name`.
Rule-discovery UIs should start from `supported_checks`, which returns stable
`CheckDescription` values for all implemented rules.

```mbt check
///|
test "doc checks exposes optional-check metadata" {
  let script = match @parser.parse_script("safe=hello\necho $safe\n") {
    Ok(script) => script
    Err(err) => abort(err.to_string())
  }
  let diagnostics = @checks.check_script(
    script,
    options=@checks.CheckOptions::default().with_optional_checks([
      "quote-safe-variables",
    ]),
  )

  assert_true(diagnostics.any(fn(diagnostic) { diagnostic.code == 2248 }))
  assert_true(
    @checks.supported_optional_checks().contains("quote-safe-variables"),
  )
  assert_true(@checks.supports_optional_check_name("quote-safe-variables"))
  assert_true(@checks.supported_checks().length() > 0)
}
```

## Respect Inline `shellcheck` Directives In The Parsed Script

The low-level checker already understands script-level and list-item-level
`disable=` annotations that the parser stored as `Annotation` values. That
means consumers of `checks` can usually pass a parsed script straight through
without implementing directive filtering themselves.

```mbt check
///|
test "doc checks honors disable directives attached to the script" {
  let script = match
    @parser.parse_script(
      "# shellcheck disable=SC2006,SC2046\nprintf '%s' `foo`\n",
    ) {
    Ok(script) => script
    Err(err) => abort(err.to_string())
  }
  let diagnostics = @checks.check_script(script)

  assert_true(diagnostics.length() == 0)
}
```
