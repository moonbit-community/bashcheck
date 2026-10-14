# File input, stdin and exit status

These cases include real filesystem reads and stdin, including the quiet-mode short circuit.

## Success and diagnostics

Clean input exits 0; lint findings exit 1. No stderr is expected.

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fquiet fixtures/clean.sh
@STDOUT (empty)
@STDERR (empty)

$ bashcheck --norc -fquiet fixtures/fix.sh
@STDOUT (empty)
@STDERR (empty)
[1]
```

## Paths and ordering

Quoted filenames and input ordering reach the real driver.

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -i2006 -fgcc "fixtures/with space.sh"
@STDOUT
fixtures/with space.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ bashcheck --norc -i2006 -fgcc fixtures/clean.sh fixtures/fix.sh "fixtures/with space.sh"
@STDOUT
fixtures/fix.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
fixtures/with space.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]
```

## Filename beginning with a dash

After changing to the fixture directory, -- makes a leading-dash filename an input.

```mooncram moonbit-community/bashcheck
$ set-current-working-directory fixtures
$ bashcheck --norc -fquiet -- -dash.sh
@STDOUT (empty)
@STDERR (empty)
```

## IO failures: status 2

Only the OS-dependent error detail uses a glob; the path, stream and status remain asserted.

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fquiet fixtures/does-not-exist.sh
@STDOUT
fixtures/does-not-exist.sh: * (glob)
@STDERR (empty)
[2]

$ bashcheck --norc -fquiet fixtures/fix.sh fixtures/does-not-exist.sh
@STDOUT (empty)
@STDERR (empty)
[1]

$ bashcheck --norc -fquiet fixtures/clean.sh fixtures/does-not-exist.sh
@STDOUT
fixtures/does-not-exist.sh: * (glob)
@STDERR (empty)
[2]
```

## Stdin

The pinned MoonBit cat tool reads fix.sh into the pipeline. Both implicit stdin
and an explicit dash label diagnostics as <stdin>.

```mooncram-import
cat : cli/cat@0.2.0
```

```mooncram moonbit-community/bashcheck
$ cat fixtures/fix.sh | bashcheck --norc -i2006 -fgcc
@STDOUT
<stdin>:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ cat fixtures/fix.sh | bashcheck --norc -i2006 -fgcc -
@STDOUT
<stdin>:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ bashcheck --norc -sbash -fjson
@STDOUT
[]
@STDERR (empty)
```
