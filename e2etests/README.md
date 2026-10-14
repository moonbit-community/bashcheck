# CLI end-to-end tests

These tests use the Markdown format documented in `../mooncram/README.md`.
They build and run the local `moonbit-community/bashcheck` executable, checking
stdout, stderr and the actual process exit status. No ShellCheck installation
or published bashcheck package is needed for this suite.

Run from the **bashcheck repository root**: mooncram resolves the local module
from its startup directory and runs each command in the test document directory.
All test documents are directly under `e2etests`, with fixture paths relative
to that directory. One filename test explicitly changes to `fixtures`.

```sh
moonx moonbit-community/mooncram@0.0.6 check e2etests
moonx moonbit-community/mooncram@0.0.6 test e2etests
moonx moonbit-community/mooncram@0.0.6 test e2etests --target native
```

## Test organization

The suite has 175 cases organized by behavior. Diagnostic baselines are grouped
by the shell feature being checked, rather than by implementation stage or output
format. Fixture subdirectories use the same categories as their test documents;
all diagnostic documents share the root `normalize.jq` filter.

| Documents | Coverage | Cases |
| --- | --- | --- |
| [cli-actions.md](cli-actions.md), [cli-errors.md](cli-errors.md), [checking-options.md](checking-options.md) | Meta actions, argument errors, filtering and configuration | 45 |
| [inputs.md](inputs.md) | Files, stdin, input order and IO errors | 11 |
| [formats.md](formats.md) | Renderers, fixes, colors and empty output | 16 |
| [shell-dialects.md](shell-dialects.md) | Shebangs, interpreter arguments and shell portability | 13 |
| [variables.md](variables.md) | Assignments, arrays, environment variables and scope | 12 |
| [expansions.md](expansions.md) | Quoting, word splitting, parameters, braces and globs | 18 |
| [conditions.md](conditions.md) | Tests, comparisons, logical operators and condition operands | 14 |
| [arithmetic.md](arithmetic.md) | Arithmetic syntax, evaluation and style | 5 |
| [control-flow.md](control-flow.md) | Loops, cases, exit status, traps and reachability | 16 |
| [commands.md](commands.md) | Builtins, text tools, command substitution and find pipelines | 13 |
| [redirections.md](redirections.md) | Streams, pipeline consumers, here-documents and shared stdin | 12 |

## Test selection

| Existing tests | E2E coverage | Treatment |
| --- | --- | --- |
| `compat/cli_diff_baseline_test.mbt` | Complete help and optional-check output | Migrated to `cli-actions.md`; removed the duplicate tests and their helper |
| `bashcheck_wbtest.mbt` | Actions, option errors, short options, repeated options, precedence | Keep pure parser assertions; add process-level assertions in `cli-actions.md`, `cli-errors.md` and `checking-options.md` |
| `driver/driver_test.mbt` | Meta actions, file IO, stdin, quiet short circuit, statuses 0–4 | Keep the driver API smoke test; add real IO in `inputs.md` |
| `formatter/formatter_test.mbt` | All seven formats, empty reports, ANSI color, wiki links, JSON fixes, missing final newline | Keep focused formatter assertions; add exact CLI snapshots in `formats.md` |
| `checker/checker_test.mbt` | Filtering, dialect selection, annotations, optional checks, extended analysis, rc discovery and overrides | Keep pure checker assertions; add actual disk reads and argv parsing in `checking-options.md` |
| Nine dynamic `compat/*diff_baseline_test.mbt` files and their JSON helper | 103 input cases checked against ShellCheck 0.11.0 | Migrated into the eight shell-feature documents listed above with static fixtures and jq-normalized snapshots; removed the live ShellCheck calls and helper |
| Remaining `compat/*diff_baseline_test.mbt` files | In-memory parser and diagnostic assertions | Keep unit tests: these already use fixed expectations and do not invoke ShellCheck |
| Parser, semantics, checks, CFG and fixer tests | AST shape, individual rules, dataflow and replacement algorithms | Keep unit tests for precise assertions and failure localization |

E2E tests are most useful where several layers meet: argv → IO/config → checker
→ formatter → process exit. Internal rule variants and algorithm edge cases are
better expressed as focused MoonBit tests.

## Fixtures and expectations

Fixtures are read-only inputs. Most commands use `--norc` to avoid configuration
outside the suite; rc discovery cases have their own nearest `.shellcheckrc`.
Color cases explicitly set environment variables or color flags. Stdin tests
import `cli/cat@0.2.0` through `mooncram-import` to read `fixtures/fix.sh` into
the pipeline. Moonx downloads and caches the pinned tool on first use; imported
tools run on wasm even when bashcheck is tested with `--target native`.

Every case asserts both output streams. Current CLI diagnostics and errors use
stdout, while stderr is empty. Expectations use exact output, including escaped
ANSI sequences; only OS-dependent file-open error details use glob matching.

## Compatibility baselines

The eight shell-feature documents preserve all 103 inputs from the dynamic
differential tests, including both occurrences of the identical SC2331 case in
`conditions.md`. There is no separate compatibility test directory.
Fixture text and trailing newlines were checked against the original inputs.
During migration, each case was compared with ShellCheck 0.11.0 for normalized
JSON and exit status. ShellCheck is not invoked by the suite or installed by CI.

Each diagnostic document imports `cli/jq@0.2.1`. The pipeline runs bashcheck with
`--norc -fjson`, then applies `normalize.jq` with `-c -S -M`. The filter
retains `line`, `endLine`, `column`, `endColumn`, `level`, `code`, `message`,
and `fix`. Each fix retains all replacement fields previously compared:
`line`, `endLine`, `column`, `endColumn`, `insertionPoint`, `precedence`,
and `replacement`. Null codes/fixes and empty arrays are preserved.

The filename is omitted, as the original helper replaced it with a constant.
Diagnostics are sorted by start/end line, start/end column, severity
(error, warning, info, style), code (null last), and message. Replacements are
sorted by start/end line, start/end column, precedence, insertion point, and
replacement text. These orders match the removed helper; `-S` also sorts object
keys. Expectations are compact JSON arrays, empty stderr, and status 0 or 1.
Mooncram's pipefail behavior preserves a nonzero bashcheck status when jq succeeds.

For an intentional compatibility change, review the affected snapshot and
compare that fixture with ShellCheck 0.11.0 using the same filter locally:

```sh
cd e2etests
shellcheck --norc -f json fixtures/conditions/SC2331.sh | moonx cli/jq@0.2.1 -c -S -M -f normalize.jq
```

This optional reference comparison is for local maintenance, not CI. Normal
snapshot updates use the commands below and require no ShellCheck installation.

When behavior intentionally changes, preview and review snapshot changes:

```sh
moonx moonbit-community/mooncram@0.0.6 update e2etests --dry-run
moonx moonbit-community/mooncram@0.0.6 update e2etests
git diff -- e2etests
moonx moonbit-community/mooncram@0.0.6 test e2etests
```

`update` records actual output and exit codes, so review both before accepting
changes. CI runs `test` on wasm and native and does not update expectations.
