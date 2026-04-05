# bashcheck/driver

`driver` is the package-level CLI driver. It takes already-parsed CLI intent
and turns it into rendered output plus a process exit code.

## Map High-Level CLI Actions To Output And Exit Codes

`run_cli` is the single public entry point. It combines a `CliAction`, input
files, a `checker.CheckSpec`, a `formatter.OutputFormat`, and
`formatter.FormatOptions`, then returns a `CliOutcome` with the rendered output
and the exit code a CLI wrapper should expose.

```mbt check
///|
async fn driver_doc_outcome(action : @driver.CliAction) -> @driver.CliOutcome {
  @driver.run_cli(
    action,
    [],
    @checker.CheckSpec::default(),
    @formatter.OutputFormat::default(),
    @formatter.FormatOptions::default(),
  )
}

///|
async test "doc driver handles help and version actions" {
  let help = driver_doc_outcome(@driver.CliAction::ShowHelp)
  let version = driver_doc_outcome(@driver.CliAction::ShowVersion)

  assert_eq(help.exit_code, 0)
  assert_true(help.output.contains("Usage: bashcheck"))
  assert_eq(version.exit_code, 0)
  assert_true(version.output.contains("bashcheck"))
}
```

## Reuse The Same Driver For Discovery-Oriented CLI Commands

`CliAction` is not only about linting files. The same driver also handles help,
version, and optional-check listing flows, which is why the return type stays
uniform: every action still becomes one `CliOutcome`.

```mbt check
///|
async test "doc driver renders optional-check listings" {
  let optional = driver_doc_outcome(@driver.CliAction::ListOptional)

  assert_eq(optional.exit_code, 0)
  assert_true(optional.output.contains("name:    add-default-case"))
}
```
