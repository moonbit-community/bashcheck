# Shell dialects and interpreter selection

Shebang validation, dialect-specific syntax and portable shell features.

These 13 cases show source lines, diagnostic locations and suggested fixes
using terminal output. Colors and wiki footers are disabled for exact snapshots.

## Shebangs and interpreter arguments

### SC2096

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC2096.sh
@STDOUT
In fixtures/shell-dialects/SC2096.sh line 1:
#!/usr/bin/env bash -x
^--------------------^ SC2096 (error): On most OS, shebangs can only specify a single parameter.
@STDERR (empty)
[1]
```

### SC2187

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC2187.sh
@STDOUT
In fixtures/shell-dialects/SC2187.sh line 1:
#!bin/ash
^-------^ SC2239 (error): Ensure the shebang uses an absolute path to the interpreter.
^-------^ SC2187 (warning): Ash scripts will be checked as Dash. Add '# shellcheck shell=dash' to silence.
@STDERR (empty)
[1]
```

### SC2239

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC2239.sh
@STDOUT
In fixtures/shell-dialects/SC2239.sh line 1:
#!bin/sh
^------^ SC2239 (error): Ensure the shebang uses an absolute path to the interpreter.
@STDERR (empty)
[1]
```

### SC2246

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC2246.sh
@STDOUT
In fixtures/shell-dialects/SC2246.sh line 1:
#!/bin/sh/
^--------^ SC2246 (error): This shebang specifies a directory. Ensure the interpreter is a file.
@STDERR (empty)
[1]
```

## Dialect-specific syntax

### SC2118

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC2118.sh
@STDOUT
In fixtures/shell-dialects/SC2118.sh line 2:
foo|&bar
   ^-- SC2118 (error): Ksh does not support |&. Use 2>&1 |.
@STDERR (empty)
[1]
```

### SC2127-case-fallthrough

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC2127-case-fallthrough.sh
@STDOUT
In fixtures/shell-dialects/SC2127-case-fallthrough.sh line 3:
case "$x" in bar) baz ;& esac
^---------------------------^ SC2127 (error): To use cases with ;&, specify #!/usr/bin/env bash or ksh
@STDERR (empty)
[1]
```

### SC2127-case-continue

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC2127-case-continue.sh
@STDOUT
In fixtures/shell-dialects/SC2127-case-continue.sh line 3:
case "$x" in bar) baz ;;& esac
^----------------------------^ SC2127 (error): To use cases with ;;&, specify #!/usr/bin/env bash
@STDERR (empty)
[1]
```

### SC2127-brace-command-expansion

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC2127-brace-command-expansion.sh
@STDOUT
In fixtures/shell-dialects/SC2127-brace-command-expansion.sh line 2:
: "${ ls; }"
   ^------^ SC2127 (error): To use ${ ..; } command expansion, specify #!/usr/bin/env bash or ksh
@STDERR (empty)
[1]
```

### SC2112-SC2113

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC2112-SC2113.sh
@STDOUT
In fixtures/shell-dialects/SC2112-SC2113.sh line 2:
function foo() { true; }
^----------------------^ SC2112 (warning): 'function' keyword is non-standard. Delete it.

In fixtures/shell-dialects/SC2112-SC2113.sh line 3:
function bar { true; }
^--------------------^ SC2113 (warning): 'function' keyword is non-standard. Use 'foo()' instead of 'function foo'.
@STDERR (empty)
[1]
```

### SC2111

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC2111.sh
@STDOUT
In fixtures/shell-dialects/SC2111.sh line 2:
function foo() { true; }
^----------------------^ SC2111 (error): ksh does not allow 'function' keyword and '()' at the same time.
@STDERR (empty)
[1]
```

## Portable variables and builtins

### SC3028-SC3029

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC3028-SC3029.sh
@STDOUT
In fixtures/shell-dialects/SC3028-SC3029.sh line 3:
echo $RANDOM
     ^-----^ SC3028 (warning): In POSIX sh, RANDOM is undefined.

In fixtures/shell-dialects/SC3028-SC3029.sh line 4:
echo foo|&cat
        ^-- SC3029 (warning): In POSIX sh, |& in place of 2>&1 | is undefined.
@STDERR (empty)
[1]
```

### SC3036-SC3039

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC3036-SC3039.sh
@STDOUT
In fixtures/shell-dialects/SC3036-SC3039.sh line 3:
echo -ne foo
     ^-^ SC3036 (error): In dash, echo flags besides -n not supported.

In fixtures/shell-dialects/SC3036-SC3039.sh line 4:
let x=1
^-----^ SC3039 (error): In dash, 'let' is not supported.
@STDERR (empty)
[1]
```

### SC3041-SC3043-SC3044-SC3061

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/shell-dialects/SC3041-SC3043-SC3044-SC3061.sh
@STDOUT
In fixtures/shell-dialects/SC3041-SC3043-SC3044-SC3061.sh line 2:
set -B
    ^-- SC3041 (warning): In POSIX sh, set flag -B is undefined.

In fixtures/shell-dialects/SC3041-SC3043-SC3044-SC3061.sh line 3:
local
^---^ SC3043 (warning): In POSIX sh, 'local' is undefined.

In fixtures/shell-dialects/SC3041-SC3043-SC3044-SC3061.sh line 4:
declare
^-----^ SC3044 (warning): In POSIX sh, 'declare' is undefined.

In fixtures/shell-dialects/SC3041-SC3043-SC3044-SC3061.sh line 5:
read -r
^--^ SC3061 (warning): In POSIX sh, read without a variable is undefined.
@STDERR (empty)
[1]
```
