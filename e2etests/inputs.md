# File input, stdin and exit status

These cases include real filesystem reads and stdin, including the quiet-mode short circuit.

## Success and diagnostics

Clean input exits 0; lint findings exit 1. No stderr is expected.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc -fquiet fixtures/clean.sh
@STDOUT (empty)
@STDERR (empty)

$ moonx moonbit-community/bashcheck --norc -fquiet fixtures/fix.sh
@STDOUT (empty)
@STDERR (empty)
[1]
```

## Paths and ordering

Quoted filenames and input ordering reach the real driver.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc -i2006 -fgcc "fixtures/with space.sh"
@STDOUT
fixtures/with space.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -i2006 -fgcc fixtures/clean.sh fixtures/fix.sh "fixtures/with space.sh"
@STDOUT
fixtures/fix.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
fixtures/with space.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]
```

## Filename beginning with a dash

With the block working directory set to fixtures, -- makes a leading-dash filename an input.

```mooncram moonbit-community/bashcheck
#cwd(fixtures)
$ moonx moonbit-community/bashcheck --norc -fquiet -- -dash.sh
@STDOUT (empty)
@STDERR (empty)
```

## IO failures: status 2

Only the OS-dependent error detail uses a glob; the path, stream and status remain asserted.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc -fquiet fixtures/does-not-exist.sh
@STDOUT
fixtures/does-not-exist.sh: * (glob)
@STDERR (empty)
[2]

$ moonx moonbit-community/bashcheck --norc -fquiet fixtures/fix.sh fixtures/does-not-exist.sh
@STDOUT (empty)
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -fquiet fixtures/clean.sh fixtures/does-not-exist.sh
@STDOUT
fixtures/does-not-exist.sh: * (glob)
@STDERR (empty)
[2]
```

## Stdin

The pinned MoonBit cat tool reads fix.sh into the pipeline. Both implicit stdin
and an explicit dash label diagnostics as <stdin>.

```mooncram moonbit-community/bashcheck
$ moonx cli/cat@0.2.0 fixtures/fix.sh | moonx moonbit-community/bashcheck --norc -i2006 -fgcc
@STDOUT
<stdin>:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ moonx cli/cat@0.2.0 fixtures/fix.sh | moonx moonbit-community/bashcheck --norc -i2006 -fgcc -
@STDOUT
<stdin>:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ moonx moonbit-community/bashcheck --norc -sbash -fgcc
@STDOUT (empty)
@STDERR (empty)
```
