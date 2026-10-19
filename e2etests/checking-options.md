# CLI checking options and filesystem configuration

The pure API tests with real argument parsing and rc files read from disk.

## Code and severity filtering

Repeated include flags accumulate. An explicit include list takes precedence over
exclude, matching ShellCheck; exclude alone and higher severity thresholds remove findings.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc -iSC2006 -fgcc fixtures/fix.sh
@STDOUT
fixtures/fix.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -i2006 -eSC2006 -fgcc fixtures/fix.sh
@STDOUT
fixtures/fix.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -eSC2006 -fgcc fixtures/fix.sh
@STDOUT
fixtures/fix.sh:2:13: warning: Quote this to prevent word splitting. [SC2046]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -iSC2154 -iSC2086 -fgcc fixtures/warnings.sh
@STDOUT
fixtures/warnings.sh:2:6: warning: foo is referenced but not assigned. [SC2154]
fixtures/warnings.sh:2:6: note: Double quote to prevent globbing and word splitting. [SC2086]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -i2006 -Swarning -fgcc fixtures/fix.sh
@STDOUT (empty)
@STDERR (empty)

$ moonx moonbit-community/bashcheck --norc -i2006 -Sstyle -fgcc fixtures/fix.sh
@STDOUT
fixtures/fix.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -i2006 -fgcc fixtures/annotated.sh
@STDOUT (empty)
@STDERR (empty)
```

## Dialect precedence

A shebang overrides the filename extension, while the CLI shell overrides the shebang. A .bash filename can supply a missing dialect.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc -i3010 -fgcc fixtures/dialect.bash
@STDOUT
fixtures/dialect.bash:2:1: warning: In POSIX sh, [[ ]] is undefined. [SC3010]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -sbash -i3010 -fgcc fixtures/dialect.bash
@STDOUT (empty)
@STDERR (empty)

$ moonx moonbit-community/bashcheck --norc -fgcc fixtures/plain.bash
@STDOUT (empty)
@STDERR (empty)

$ moonx moonbit-community/bashcheck --norc -i2148 -fgcc fixtures/unknown.sh
@STDOUT
fixtures/unknown.sh:1:1: error: Tips depend on target shell and yours is unknown. Add a shebang or a 'shell' directive. [SC2148]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -sbash -fgcc fixtures/unknown.sh
@STDOUT (empty)
@STDERR (empty)
```

## Optional and extended analysis

Defaults, explicit optional checks, all, unknown check names and the control-flow extension keep their existing CLI behavior.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc -i2248,2292 -fgcc fixtures/optional.sh
@STDOUT (empty)
@STDERR (empty)

$ moonx moonbit-community/bashcheck --norc -oquote-safe-variables,require-double-brackets -i2248,2292 -fgcc fixtures/optional.sh
@STDOUT
fixtures/optional.sh:3:6: note: Prefer double quoting even when variables don't contain special characters. [SC2248]
fixtures/optional.sh:4:1: note: Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox. [SC2292]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -oall -i2248,2292 -fgcc fixtures/optional.sh
@STDOUT
fixtures/optional.sh:3:6: note: Prefer double quoting even when variables don't contain special characters. [SC2248]
fixtures/optional.sh:4:1: note: Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox. [SC2292]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -obogus -i2248,2292 -fgcc fixtures/optional.sh
@STDOUT (empty)
@STDERR (empty)

$ moonx moonbit-community/bashcheck --norc -i2154 -fgcc fixtures/warnings.sh
@STDOUT
fixtures/warnings.sh:2:6: warning: foo is referenced but not assigned. [SC2154]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc --extended-analysis=false -i2154 -fgcc fixtures/analysis.sh
@STDOUT (empty)
@STDERR (empty)

$ moonx moonbit-community/bashcheck --norc --extended-analysis=false -ocontrol-flow -i2154 -fgcc fixtures/warnings.sh
@STDOUT
fixtures/warnings.sh:2:6: warning: foo is referenced but not assigned. [SC2154]
@STDERR (empty)
[1]
```

## First format wins

Later format selections do not replace the first one. A diagnostic distinguishes
the compact GCC output from the source excerpt and carets in terminal output.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -fgcc -ftty -i2006 fixtures/fix.sh
@STDOUT
fixtures/fix.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]
```

## Rc discovery and overrides

The checked file directory and its parents are searched. The nearest readable rc file wins; --rcfile selects another file and --norc bypasses configuration.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck -i2006 -fgcc fixtures/rc/script.sh
@STDOUT (empty)
@STDERR (empty)

$ moonx moonbit-community/bashcheck -i2006 -fgcc fixtures/rc/subdir/script.sh
@STDOUT (empty)
@STDERR (empty)

$ moonx moonbit-community/bashcheck -i2006 -fgcc fixtures/rc/near/script.sh
@STDOUT
fixtures/rc/near/script.sh:1:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -sbash -i2006 -fgcc fixtures/rc/script.sh
@STDOUT
fixtures/rc/script.sh:1:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --rcfile fixtures/custom.rc -i2006 -fgcc fixtures/rc/script.sh
@STDOUT
fixtures/rc/script.sh:1:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --rcfile fixtures/custom.rc -i2292 -fgcc fixtures/optional.sh
@STDOUT
fixtures/optional.sh:4:1: note: Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox. [SC2292]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc --rcfile fixtures/custom.rc -i2292 -fgcc fixtures/optional.sh
@STDOUT (empty)
@STDERR (empty)

$ moonx moonbit-community/bashcheck --rcfile fixtures/custom.rc --extended-analysis=false -i2154 -fgcc fixtures/analysis.sh
@STDOUT (empty)
@STDERR (empty)
```
