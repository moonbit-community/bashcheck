# Shell dialects and interpreter selection

Shebang validation, dialect-specific syntax and portable shell features.

These 13 cases use fixed JSON baselines checked against ShellCheck 0.11.0.
Runtime tests execute bashcheck and the pinned jq tool.

```mooncram-import
jq : cli/jq@0.2.1
```

## Shebangs and interpreter arguments

### SC2096

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC2096.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2096,"column":1,"endColumn":23,"endLine":1,"fix":null,"level":"error","line":1,"message":"On most OS, shebangs can only specify a single parameter."}]
@STDERR (empty)
[1]
```

### SC2187

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC2187.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2239,"column":1,"endColumn":10,"endLine":1,"fix":null,"level":"error","line":1,"message":"Ensure the shebang uses an absolute path to the interpreter."},{"code":2187,"column":1,"endColumn":10,"endLine":1,"fix":null,"level":"warning","line":1,"message":"Ash scripts will be checked as Dash. Add '# shellcheck shell=dash' to silence."}]
@STDERR (empty)
[1]
```

### SC2239

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC2239.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2239,"column":1,"endColumn":9,"endLine":1,"fix":null,"level":"error","line":1,"message":"Ensure the shebang uses an absolute path to the interpreter."}]
@STDERR (empty)
[1]
```

### SC2246

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC2246.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2246,"column":1,"endColumn":11,"endLine":1,"fix":null,"level":"error","line":1,"message":"This shebang specifies a directory. Ensure the interpreter is a file."}]
@STDERR (empty)
[1]
```

## Dialect-specific syntax

### SC2118

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC2118.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2118,"column":4,"endColumn":6,"endLine":2,"fix":null,"level":"error","line":2,"message":"Ksh does not support |&. Use 2>&1 |."}]
@STDERR (empty)
[1]
```

### SC2127-case-fallthrough

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC2127-case-fallthrough.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2127,"column":1,"endColumn":30,"endLine":3,"fix":null,"level":"error","line":3,"message":"To use cases with ;&, specify #!/usr/bin/env bash or ksh"}]
@STDERR (empty)
[1]
```

### SC2127-case-continue

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC2127-case-continue.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2127,"column":1,"endColumn":31,"endLine":3,"fix":null,"level":"error","line":3,"message":"To use cases with ;;&, specify #!/usr/bin/env bash"}]
@STDERR (empty)
[1]
```

### SC2127-brace-command-expansion

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC2127-brace-command-expansion.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2127,"column":4,"endColumn":12,"endLine":2,"fix":null,"level":"error","line":2,"message":"To use ${ ..; } command expansion, specify #!/usr/bin/env bash or ksh"}]
@STDERR (empty)
[1]
```

### SC2112-SC2113

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC2112-SC2113.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2112,"column":1,"endColumn":25,"endLine":2,"fix":null,"level":"warning","line":2,"message":"'function' keyword is non-standard. Delete it."},{"code":2113,"column":1,"endColumn":23,"endLine":3,"fix":null,"level":"warning","line":3,"message":"'function' keyword is non-standard. Use 'foo()' instead of 'function foo'."}]
@STDERR (empty)
[1]
```

### SC2111

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC2111.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2111,"column":1,"endColumn":25,"endLine":2,"fix":null,"level":"error","line":2,"message":"ksh does not allow 'function' keyword and '()' at the same time."}]
@STDERR (empty)
[1]
```

## Portable variables and builtins

### SC3028-SC3029

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC3028-SC3029.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":3028,"column":6,"endColumn":13,"endLine":3,"fix":null,"level":"warning","line":3,"message":"In POSIX sh, RANDOM is undefined."},{"code":3029,"column":9,"endColumn":11,"endLine":4,"fix":null,"level":"warning","line":4,"message":"In POSIX sh, |& in place of 2>&1 | is undefined."}]
@STDERR (empty)
[1]
```

### SC3036-SC3039

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC3036-SC3039.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":3036,"column":6,"endColumn":9,"endLine":3,"fix":null,"level":"error","line":3,"message":"In dash, echo flags besides -n not supported."},{"code":3039,"column":1,"endColumn":8,"endLine":4,"fix":null,"level":"error","line":4,"message":"In dash, 'let' is not supported."}]
@STDERR (empty)
[1]
```

### SC3041-SC3043-SC3044-SC3061

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/shell-dialects/SC3041-SC3043-SC3044-SC3061.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":3041,"column":5,"endColumn":7,"endLine":2,"fix":null,"level":"warning","line":2,"message":"In POSIX sh, set flag -B is undefined."},{"code":3043,"column":1,"endColumn":6,"endLine":3,"fix":null,"level":"warning","line":3,"message":"In POSIX sh, 'local' is undefined."},{"code":3044,"column":1,"endColumn":8,"endLine":4,"fix":null,"level":"warning","line":4,"message":"In POSIX sh, 'declare' is undefined."},{"code":3061,"column":1,"endColumn":5,"endLine":5,"fix":null,"level":"warning","line":5,"message":"In POSIX sh, read without a variable is undefined."}]
@STDERR (empty)
[1]
```
