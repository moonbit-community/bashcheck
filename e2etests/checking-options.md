# CLI checking options and filesystem configuration

The pure API tests with real argument parsing and rc files read from disk.

## Code and severity filtering

Repeated include flags accumulate. An explicit include list takes precedence over
exclude, matching ShellCheck; exclude alone and higher severity thresholds remove findings.

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -iSC2006 -fgcc fixtures/fix.sh
@STDOUT
fixtures/fix.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ bashcheck --norc -i2006 -eSC2006 -fjson fixtures/fix.sh
@STDOUT
[{"file":"fixtures/fix.sh","line":2,"endLine":2,"column":13,"endColumn":18,"level":"style","code":2006,"message":"Use $(...) notation instead of legacy backticks `...`.","fix":{"replacements":[{"column":13,"endColumn":14,"endLine":2,"insertionPoint":"afterEnd","line":2,"precedence":5,"replacement":"$("},{"column":17,"endColumn":18,"endLine":2,"insertionPoint":"beforeStart","line":2,"precedence":5,"replacement":")"}]}}]
@STDERR (empty)
[1]

$ bashcheck --norc -eSC2006 -fgcc fixtures/fix.sh
@STDOUT
fixtures/fix.sh:2:13: warning: Quote this to prevent word splitting. [SC2046]
@STDERR (empty)
[1]

$ bashcheck --norc -iSC2154 -iSC2086 -fgcc fixtures/warnings.sh
@STDOUT
fixtures/warnings.sh:2:6: warning: foo is referenced but not assigned. [SC2154]
fixtures/warnings.sh:2:6: note: Double quote to prevent globbing and word splitting. [SC2086]
@STDERR (empty)
[1]

$ bashcheck --norc -i2006 -Swarning -fjson fixtures/fix.sh
@STDOUT
[]
@STDERR (empty)

$ bashcheck --norc -i2006 -Sstyle -fgcc fixtures/fix.sh
@STDOUT
fixtures/fix.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ bashcheck --norc -i2006 -fjson fixtures/annotated.sh
@STDOUT
[]
@STDERR (empty)
```

## Dialect precedence

A shebang overrides the filename extension, while the CLI shell overrides the shebang. A .bash filename can supply a missing dialect.

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -i3010 -fgcc fixtures/dialect.bash
@STDOUT
fixtures/dialect.bash:2:1: warning: In POSIX sh, [[ ]] is undefined. [SC3010]
@STDERR (empty)
[1]

$ bashcheck --norc -sbash -i3010 -fjson fixtures/dialect.bash
@STDOUT
[]
@STDERR (empty)

$ bashcheck --norc -fjson fixtures/plain.bash
@STDOUT
[]
@STDERR (empty)

$ bashcheck --norc -i2148 -fgcc fixtures/unknown.sh
@STDOUT
fixtures/unknown.sh:1:1: error: Tips depend on target shell and yours is unknown. Add a shebang or a 'shell' directive. [SC2148]
@STDERR (empty)
[1]

$ bashcheck --norc -sbash -fjson fixtures/unknown.sh
@STDOUT
[]
@STDERR (empty)
```

## Optional and extended analysis

Defaults, explicit optional checks, all, unknown check names and the control-flow extension keep their existing CLI behavior.

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -i2248,2292 -fjson fixtures/optional.sh
@STDOUT
[]
@STDERR (empty)

$ bashcheck --norc -oquote-safe-variables,require-double-brackets -i2248,2292 -fgcc fixtures/optional.sh
@STDOUT
fixtures/optional.sh:3:6: note: Prefer double quoting even when variables don't contain special characters. [SC2248]
fixtures/optional.sh:4:1: note: Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox. [SC2292]
@STDERR (empty)
[1]

$ bashcheck --norc -oall -i2248,2292 -fgcc fixtures/optional.sh
@STDOUT
fixtures/optional.sh:3:6: note: Prefer double quoting even when variables don't contain special characters. [SC2248]
fixtures/optional.sh:4:1: note: Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox. [SC2292]
@STDERR (empty)
[1]

$ bashcheck --norc -obogus -i2248,2292 -fjson fixtures/optional.sh
@STDOUT
[]
@STDERR (empty)

$ bashcheck --norc -i2154 -fgcc fixtures/warnings.sh
@STDOUT
fixtures/warnings.sh:2:6: warning: foo is referenced but not assigned. [SC2154]
@STDERR (empty)
[1]

$ bashcheck --norc --extended-analysis=false -i2154 -fjson fixtures/analysis.sh
@STDOUT
[]
@STDERR (empty)

$ bashcheck --norc --extended-analysis=false -ocontrol-flow -i2154 -fgcc fixtures/warnings.sh
@STDOUT
fixtures/warnings.sh:2:6: warning: foo is referenced but not assigned. [SC2154]
@STDERR (empty)
[1]
```

## First format wins

Later format selections do not replace the first one.

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson -ftty -i2006 fixtures/clean.sh
@STDOUT
[]
@STDERR (empty)
```

## Rc discovery and overrides

The checked file directory and its parents are searched. The nearest readable rc file wins; --rcfile selects another file and --norc bypasses configuration.

```mooncram moonbit-community/bashcheck
$ bashcheck -i2006 -fjson fixtures/rc/script.sh
@STDOUT
[]
@STDERR (empty)

$ bashcheck -i2006 -fjson fixtures/rc/subdir/script.sh
@STDOUT
[]
@STDERR (empty)

$ bashcheck -i2006 -fgcc fixtures/rc/near/script.sh
@STDOUT
fixtures/rc/near/script.sh:1:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ bashcheck --norc -sbash -i2006 -fgcc fixtures/rc/script.sh
@STDOUT
fixtures/rc/script.sh:1:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ bashcheck --rcfile fixtures/custom.rc -i2006 -fgcc fixtures/rc/script.sh
@STDOUT
fixtures/rc/script.sh:1:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ bashcheck --rcfile fixtures/custom.rc -i2292 -fgcc fixtures/optional.sh
@STDOUT
fixtures/optional.sh:4:1: note: Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox. [SC2292]
@STDERR (empty)
[1]

$ bashcheck --norc --rcfile fixtures/custom.rc -i2292 -fjson fixtures/optional.sh
@STDOUT
[]
@STDERR (empty)

$ bashcheck --rcfile fixtures/custom.rc --extended-analysis=false -i2154 -fjson fixtures/analysis.sh
@STDOUT
[]
@STDERR (empty)
```
