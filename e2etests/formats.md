# Output formats and fixes

These cover the user-visible rendering scenarios in `formatter/formatter_test.mbt`
through file IO, checking, CLI format selection and process status. Unit tests for
formatter helpers and replacement algorithms remain useful independently.

## Every public format

A single SC2006 fix gives a small, precise snapshot for every renderer.

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -iSC2006 -W1 -ftty fixtures/fix.sh
@STDOUT
In fixtures/fix.sh line 2:
printf '%s' `foo`
            ^---^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
printf '%s' $(foo)

For more information:
  https://www.shellcheck.net/wiki/SC2006 -- Use $(...) notation instead of le...
@STDERR (empty)
[1]

$ bashcheck --norc --color=never -iSC2006 -W1 -fgcc fixtures/fix.sh
@STDOUT
fixtures/fix.sh:2:13: note: Use $(...) notation instead of legacy backticks `...`. [SC2006]
@STDERR (empty)
[1]

$ bashcheck --norc --color=never -iSC2006 -W1 -fjson fixtures/fix.sh
@STDOUT
[{"file":"fixtures/fix.sh","line":2,"endLine":2,"column":13,"endColumn":18,"level":"style","code":2006,"message":"Use $(...) notation instead of legacy backticks `...`.","fix":{"replacements":[{"column":13,"endColumn":14,"endLine":2,"insertionPoint":"afterEnd","line":2,"precedence":5,"replacement":"$("},{"column":17,"endColumn":18,"endLine":2,"insertionPoint":"beforeStart","line":2,"precedence":5,"replacement":")"}]}}]
@STDERR (empty)
[1]

$ bashcheck --norc --color=never -iSC2006 -W1 -fjson1 fixtures/fix.sh
@STDOUT
{"comments":[{"file":"fixtures/fix.sh","line":2,"endLine":2,"column":13,"endColumn":18,"level":"style","code":2006,"message":"Use $(...) notation instead of legacy backticks `...`.","fix":{"replacements":[{"column":13,"endColumn":14,"endLine":2,"insertionPoint":"afterEnd","line":2,"precedence":5,"replacement":"$("},{"column":17,"endColumn":18,"endLine":2,"insertionPoint":"beforeStart","line":2,"precedence":5,"replacement":")"}]}}]}
@STDERR (empty)
[1]

$ bashcheck --norc --color=never -iSC2006 -W1 -fcheckstyle fixtures/fix.sh
@STDOUT
<?xml version='1.0' encoding='UTF-8'?>
<checkstyle version='4.3'>
<file name='fixtures/fix.sh'>
<error line='2' column='13' severity='info' message='Use $(...) notation instead of legacy backticks `...`.' source='ShellCheck.SC2006' />
</file>
</checkstyle>
@STDERR (empty)
[1]

$ bashcheck --norc --color=never -iSC2006 -W1 -fdiff fixtures/fix.sh
@STDOUT
--- a/fixtures/fix.sh
+++ b/fixtures/fix.sh
@@ -1,2 +1,2 @@
 #!/bin/bash
-printf '%s' `foo`
+printf '%s' $(foo)
@STDERR (empty)
[1]

$ bashcheck --norc --color=never -iSC2006 -W1 -fquiet fixtures/fix.sh
@STDOUT (empty)
@STDERR (empty)
[1]
```

## Empty results

Structured formats have explicit empty containers; quiet output stays empty.

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/clean.sh
@STDOUT
[]
@STDERR (empty)

$ bashcheck --norc -fjson1 fixtures/clean.sh
@STDOUT
{"comments":[]}
@STDERR (empty)

$ bashcheck --norc -fcheckstyle fixtures/clean.sh
@STDOUT
<?xml version='1.0' encoding='UTF-8'?>
<checkstyle version='4.3'>
<file name='fixtures/clean.sh'>
</file>
</checkstyle>
@STDERR (empty)

$ bashcheck --norc -fquiet fixtures/clean.sh
@STDOUT (empty)
@STDERR (empty)
```

## Diff without a trailing newline

The diff marks the source line that has no trailing newline.

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -i2006 -fdiff fixtures/no-newline.sh
@STDOUT
--- a/fixtures/no-newline.sh
+++ b/fixtures/no-newline.sh
@@ -1,2 +1,2 @@
 #!/bin/bash
-printf '%s' `foo`
\ No newline at end of file
+printf '%s' $(foo)
@STDERR (empty)
[1]
```

## Color environment and options

Use escaped exact output for ANSI sequences. NO_COLOR disables auto color; an explicit always overrides it.

```mooncram moonbit-community/bashcheck
$ TERM=xterm NO_COLOR=1 bashcheck --norc -i2006 -W0 fixtures/fix.sh
@STDOUT
In fixtures/fix.sh line 2:
printf '%s' `foo`
            ^---^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
printf '%s' $(foo)
@STDERR (empty)
[1]

$ TERM=dumb bashcheck --norc --color=auto -i2006 -W0 fixtures/fix.sh
@STDOUT
In fixtures/fix.sh line 2:
printf '%s' `foo`
            ^---^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.

Did you mean:
printf '%s' $(foo)
@STDERR (empty)
[1]

$ TERM=dumb NO_COLOR=1 bashcheck --norc --color=always -i2006 -W0 fixtures/fix.sh
@STDOUT
"\u001b[1mIn fixtures/fix.sh line 2:\u001b[0m" (escaped)
printf '%s' `foo`
"\u001b[32m            ^---^ SC2006 (style): Use $(...) notation instead of legacy backticks `...`.\u001b[0m" (escaped)

"\u001b[1mDid you mean:\u001b[0m" (escaped)
printf '%s' $(foo)
@STDERR (empty)
[1]

$ bashcheck --norc -Calways -i2006 -fdiff fixtures/fix.sh
@STDOUT
"\u001b[1m--- a/fixtures/fix.sh\u001b[0m" (escaped)
"\u001b[1m+++ b/fixtures/fix.sh\u001b[0m" (escaped)
"\u001b[36m@@ -1,2 +1,2 @@\u001b[0m" (escaped)
 #!/bin/bash
"\u001b[31m-printf '%s' `foo`\u001b[0m" (escaped)
"\u001b[32m+printf '%s' $(foo)\u001b[0m" (escaped)
@STDERR (empty)
[1]
```
