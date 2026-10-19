# moonbit-community/bashcheck

`bashcheck` is a MoonBit reimplementation of ShellCheck 0.11.0.

Run unit and compatibility tests with `moon test`. Compatibility baselines were
checked against ShellCheck 0.11.0; running tests does not require ShellCheck.
Run CLI end-to-end tests from the repository root:

```sh
moonx moonbit-community/mooncram@0.0.7 test e2etests
moonx moonbit-community/mooncram@0.0.7 test e2etests --target native
```

See [e2etests/README.md](e2etests/README.md) for coverage and snapshot maintenance.

Source files are analyzed when permitted by the input list or `-x`. `-a` also
reports their diagnostics. Use `-P SCRIPTDIR` to search beside each script;
the script directory is not searched implicitly. Rc settings apply before
include resolution, and file directives override those settings.

The production packages expose the interfaces used by the CLI. AST dumps,
raw CFG builders and test convenience wrappers live in test files.

```sh
node scripts/test_source_cli.mjs --target wasm
node scripts/test_source_cli.mjs --target native
node scripts/audit_reachability.mjs
```

The source suite creates real files, symlinks and a 100-level include chain.
`--oracle` optionally rechecks its source-resolution expectations against a
local ShellCheck 0.11.0. CI uses static expectations and requires no oracle.
The reachability audit uses compiler symbol references for both supported CLI
targets, including function registrations and global initialization; it fails
when a production function is unreachable from the executable on both targets.
