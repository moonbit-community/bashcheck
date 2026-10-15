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
format. Fixture subdirectories use the same categories as their test documents.
Diagnostic cases use terminal output with source excerpts, carets and suggested
fixes. Option and configuration cases use compact GCC output. JSON snapshots are
reserved for the JSON and JSON1 renderer cases in `formats.md`.

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
| Nine dynamic `compat/*diff_baseline_test.mbt` files and their JSON helper | 103 input cases checked against ShellCheck 0.11.0 | Migrated into the eight shell-feature documents listed above with static fixtures; now checked with terminal snapshots; removed the live ShellCheck calls and helper |
| Former fixed `compat/*diff_baseline_test.mbt` files | In-memory parser and diagnostic assertions | Merged into `parser`, `checker` and `checks` unit tests with complete diagnostic comparisons; removed the `compat` package |
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
During the original migration, each case was compared with ShellCheck 0.11.0 for
normalized JSON and exit status. ShellCheck is not invoked by the suite or
installed by CI.

The diagnostic documents now run bashcheck directly with
`--norc --color=never -W0 -ftty`. Exact terminal snapshots show the filename,
source line, diagnostic location, severity, code and message, plus the corrected
source when a fix is available. Disabling wiki footers keeps the focus on the
diagnostics; `formats.md` separately covers wiki links and color. Empty results
assert empty stdout, and every case still checks stderr and process exit status.
No jq dependency or JSON normalization is needed.

Terminal excerpts do not expose every span and replacement metadata field.
Complete diagnostic comparisons and replacement algorithm assertions remain in
the MoonBit unit tests; `formats.md` keeps exact JSON and JSON1 snapshots for
diagnostics with replacements and for empty results.

For an intentional compatibility change, review the affected snapshot and
compare that fixture with ShellCheck 0.11.0 using the same output options locally:

```sh
cd e2etests
shellcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2331.sh
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

## Source loading regressions

`scripts/test_source_cli.mjs` complements the Markdown suite with temporary real
files, symlinks, missing files, rc settings and a 100-level source chain. It
runs the actual native executable or the wasm executable through `moonrun`.
Static expectations cover permissions, cross-file assignments and functions,
path precedence, include-local suppression, file positions, tabbed source
excerpts, missing trailing newlines, repeated fixes and quiet short circuit.
Use `--oracle` with a local ShellCheck 0.11.0 to verify source baselines. Existing
SC2154 quote-span differences and duplicate oracle diagnostics are normalized
for that comparison. The SC1092 boundary follows the upstream parser's frame
limit and the existing parser baseline; the ShellCheck CLI reports SC1093 at
that boundary, so the oracle comparison excludes that one case.
