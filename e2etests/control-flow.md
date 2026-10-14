# Control flow and exit status

Loops, cases, negation, set -e, traps, recursion and unreachable code.

These 16 cases use fixed JSON baselines checked against ShellCheck 0.11.0.
Runtime tests execute bashcheck and the pinned jq tool.

```mooncram-import
jq : cli/jq@0.2.1
```

## Loops, cases and subshell structure

### SC2104-SC2105-SC2106

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2104-SC2105-SC2106.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2105,"column":1,"endColumn":11,"endLine":3,"fix":null,"level":"error","line":3,"message":"continue is only valid in loops."},{"code":2104,"column":9,"endColumn":14,"endLine":4,"fix":null,"level":"error","line":4,"message":"In functions, use return instead of break."},{"code":2105,"column":15,"endColumn":23,"endLine":5,"fix":null,"level":"error","line":5,"message":"continue is only valid in loops."},{"code":2106,"column":18,"endColumn":23,"endLine":6,"fix":null,"level":"warning","line":6,"message":"This only exits the subshell caused by the (..) group."},{"code":2106,"column":25,"endColumn":30,"endLine":7,"fix":null,"level":"warning","line":7,"message":"This only exits the subshell caused by the pipeline."}]
@STDERR (empty)
[1]
```

### SC2103

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2103.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2103,"column":35,"endColumn":40,"endLine":3,"fix":null,"level":"info","line":3,"message":"Use a ( subshell ) to avoid having to cd back."}]
@STDERR (empty)
[1]
```

### SC2233-SC2234-SC2235

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2233-SC2234-SC2235.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2234,"column":1,"endColumn":10,"endLine":3,"fix":null,"level":"style","line":3,"message":"Remove superfluous (..) around test command to avoid subshell overhead."},{"code":2233,"column":4,"endColumn":13,"endLine":4,"fix":null,"level":"style","line":4,"message":"Remove superfluous (..) around condition to avoid subshell overhead."},{"code":2235,"column":1,"endColumn":19,"endLine":5,"fix":null,"level":"style","line":5,"message":"Use { ..; } instead of (..) to avoid subshell overhead."}]
@STDERR (empty)
[1]
```

### SC2258

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2258.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2258,"column":10,"endColumn":14,"endLine":3,"fix":{"replacements":[{"column":13,"endColumn":14,"endLine":3,"insertionPoint":"beforeStart","line":3,"precedence":7,"replacement":""}]},"level":"warning","line":3,"message":"The trailing comma is part of the value, not a separator. Delete or quote it."},{"code":2258,"column":15,"endColumn":19,"endLine":3,"fix":{"replacements":[{"column":18,"endColumn":19,"endLine":3,"insertionPoint":"beforeStart","line":3,"precedence":7,"replacement":""}]},"level":"warning","line":3,"message":"The trailing comma is part of the value, not a separator. Delete or quote it."}]
@STDERR (empty)
[1]
```

### SC2194-SC2222

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2194-SC2222.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2194,"column":6,"endColumn":9,"endLine":3,"fix":null,"level":"warning","line":3,"message":"This word is constant. Did you forget the $ on a variable?"},{"code":2195,"column":18,"endColumn":20,"endLine":4,"fix":null,"level":"warning","line":4,"message":"This pattern will never match the case statement's word. Double check them."},{"code":2221,"column":12,"endColumn":15,"endLine":5,"fix":null,"level":"warning","line":5,"message":"This pattern always overrides a later one on line 5."},{"code":2222,"column":28,"endColumn":31,"endLine":5,"fix":null,"level":"warning","line":5,"message":"This pattern never matches because of a previous pattern on line 5."}]
@STDERR (empty)
[1]
```

## Exit status and negation

### SC2251

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2251.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2251,"column":16,"endColumn":17,"endLine":3,"fix":{"replacements":[{"column":16,"endColumn":17,"endLine":3,"insertionPoint":"afterEnd","line":3,"precedence":6,"replacement":""},{"column":22,"endColumn":22,"endLine":3,"insertionPoint":"beforeStart","line":3,"precedence":7,"replacement":" && exit 1"}]},"level":"info","line":3,"message":"This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked."},{"code":2251,"column":3,"endColumn":4,"endLine":4,"fix":{"replacements":[{"column":3,"endColumn":4,"endLine":4,"insertionPoint":"afterEnd","line":4,"precedence":6,"replacement":""},{"column":9,"endColumn":9,"endLine":4,"insertionPoint":"beforeStart","line":4,"precedence":7,"replacement":" && exit 1"}]},"level":"info","line":4,"message":"This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked."},{"code":2251,"column":1,"endColumn":2,"endLine":5,"fix":{"replacements":[{"column":1,"endColumn":2,"endLine":5,"insertionPoint":"afterEnd","line":5,"precedence":3,"replacement":""},{"column":12,"endColumn":12,"endLine":5,"insertionPoint":"beforeStart","line":5,"precedence":4,"replacement":" && exit 1"}]},"level":"info","line":5,"message":"This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked."},{"code":2251,"column":1,"endColumn":2,"endLine":6,"fix":{"replacements":[{"column":1,"endColumn":2,"endLine":6,"insertionPoint":"afterEnd","line":6,"precedence":3,"replacement":""},{"column":7,"endColumn":7,"endLine":6,"insertionPoint":"beforeStart","line":6,"precedence":4,"replacement":" && exit 1"}]},"level":"info","line":6,"message":"This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked."}]
@STDERR (empty)
[1]
```

### SC2310

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2310.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2310,"column":1,"endColumn":2,"endLine":5,"fix":null,"level":"info","line":5,"message":"This function is invoked in an && condition so set -e will be disabled. Invoke separately if failures should cause the script to exit."},{"code":2310,"column":4,"endColumn":5,"endLine":6,"fix":null,"level":"info","line":6,"message":"This function is invoked in an 'if' condition so set -e will be disabled. Invoke separately if failures should cause the script to exit."},{"code":2310,"column":7,"endColumn":8,"endLine":7,"fix":null,"level":"info","line":7,"message":"This function is invoked in a 'while' condition so set -e will be disabled. Invoke separately if failures should cause the script to exit."},{"code":2310,"column":3,"endColumn":4,"endLine":8,"fix":null,"level":"info","line":8,"message":"This function is invoked in a ! condition so set -e will be disabled. Invoke separately if failures should cause the script to exit."}]
@STDERR (empty)
[1]
```

### SC2152-SC2241

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2152-SC2241.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2152,"column":13,"endColumn":15,"endLine":2,"fix":null,"level":"error","line":2,"message":"Can only return 0-255. Other data should be written to stdout."},{"code":2241,"column":6,"endColumn":7,"endLine":4,"fix":null,"level":"error","line":4,"message":"The exit status can only be one integer 0-255. Use stdout for other data."}]
@STDERR (empty)
[1]
```

### SC2155

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2155.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2155,"column":12,"endColumn":13,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Declare and assign separately to avoid masking return values."}]
@STDERR (empty)
[1]
```

### SC2181

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2181.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2181,"column":3,"endColumn":5,"endLine":3,"fix":null,"level":"style","line":3,"message":"Check exit code directly with e.g. 'if mycmd;', not indirectly with $?."}]
@STDERR (empty)
[1]
```

### SC2325

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2325.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2325,"column":1,"endColumn":2,"endLine":2,"fix":null,"level":"error","line":2,"message":"Multiple ! in front of pipelines are a bash/ksh extension. Use only 0 or 1."}]
@STDERR (empty)
[1]
```

### SC2326

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2326.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2326,"column":8,"endColumn":9,"endLine":2,"fix":null,"level":"error","line":2,"message":"! is not allowed in the middle of pipelines. Use command group as in cmd | { ! cmd; } if necessary."}]
@STDERR (empty)
[1]
```

## Traps, recursion and unreachable code

### SC2172-SC2173

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2172-SC2173.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2172,"column":10,"endColumn":12,"endLine":2,"fix":null,"level":"warning","line":2,"message":"Trapping signals by number is not well defined. Prefer signal names."},{"code":2173,"column":13,"endColumn":17,"endLine":2,"fix":null,"level":"error","line":2,"message":"SIGKILL/SIGSTOP can not be trapped."},{"code":2173,"column":18,"endColumn":19,"endLine":2,"fix":null,"level":"error","line":2,"message":"SIGKILL/SIGSTOP can not be trapped."}]
@STDERR (empty)
[1]
```

### SC2314-SC2315-SC2329

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2314-SC2315-SC2329.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2314,"column":20,"endColumn":21,"endLine":2,"fix":{"replacements":[{"column":20,"endColumn":20,"endLine":2,"insertionPoint":"afterEnd","line":2,"precedence":7,"replacement":"run "}]},"level":"error","line":2,"message":"In Bats, ! does not cause a test failure. Use 'run ! ' (on Bats >= 1.5.0) instead."},{"code":2315,"column":21,"endColumn":22,"endLine":3,"fix":null,"level":"style","line":3,"message":"In Bats, ! will not fail the test if it is not the last command anymore. Fold the `!` into the conditional!"},{"code":2329,"column":1,"endColumn":21,"endLine":4,"fix":null,"level":"info","line":4,"message":"This function is never invoked. Check usage (or ignored if invoked indirectly)."}]
@STDERR (empty)
[1]
```

### SC2264

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2264.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2264,"column":7,"endColumn":8,"endLine":2,"fix":{"replacements":[{"column":7,"endColumn":7,"endLine":2,"insertionPoint":"afterEnd","line":2,"precedence":10,"replacement":"command "}]},"level":"error","line":2,"message":"This function unconditionally re-invokes itself. Missing 'command'?"},{"code":2264,"column":8,"endColumn":10,"endLine":3,"fix":{"replacements":[{"column":8,"endColumn":8,"endLine":3,"insertionPoint":"afterEnd","line":3,"precedence":11,"replacement":"command "}]},"level":"error","line":3,"message":"This function unconditionally re-invokes itself. Missing 'command'?"}]
@STDERR (empty)
[1]
```

### SC2093

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/control-flow/SC2093.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2093,"column":1,"endColumn":9,"endLine":2,"fix":null,"level":"warning","line":2,"message":"Remove \"exec \" if script should continue after this command."},{"code":2093,"column":16,"endColumn":25,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Remove \"exec \" if script should continue after this command."}]
@STDERR (empty)
[1]
```
