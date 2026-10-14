# moonbit-community/bashcheck

`bashcheck` is a MoonBit reimplementation of ShellCheck 0.11.0.

Run unit and compatibility tests with `moon test`. Compatibility baselines were
checked against ShellCheck 0.11.0; running tests does not require ShellCheck.
Run CLI end-to-end tests from the repository root:

```sh
moonx moonbit-community/mooncram@0.0.6 test e2etests
moonx moonbit-community/mooncram@0.0.6 test e2etests --target native
```

See [e2etests/README.md](e2etests/README.md) for coverage and snapshot maintenance.
