# Variables, assignments and scope

Variable references, array assignments, environment variables and subshell scope.

These 12 cases use fixed JSON baselines checked against ShellCheck 0.11.0.
Runtime tests execute bashcheck and the pinned jq tool.

```mooncram-import
jq : cli/jq@0.2.1
```

## Assignments and variable references

### SC2272-SC2276

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2272-SC2276.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2272,"column":1,"endColumn":9,"endLine":3,"fix":null,"level":"error","line":3,"message":"Command name contains ==. For comparison, use [ \"$var\" = value ]."},{"code":2276,"column":1,"endColumn":15,"endLine":4,"fix":null,"level":"error","line":4,"message":"This is interpreted as a command name containing '='. Bad assignment or comparison?"}]
@STDERR (empty)
[1]
```

### SC2034

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2034.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2034,"column":1,"endColumn":4,"endLine":2,"fix":null,"level":"warning","line":2,"message":"foo appears unused. Verify use (or export if used externally)."}]
@STDERR (empty)
[1]
```

### SC2153

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2153.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2153,"column":6,"endColumn":15,"endLine":4,"fix":null,"level":"info","line":4,"message":"Possible misspelling: HOMR_DIR may not be assigned. Did you mean HOME_DIR?"}]
@STDERR (empty)
[1]
```

### SC2283-SC2285

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2283-SC2285.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2283,"column":5,"endColumn":6,"endLine":3,"fix":null,"level":"error","line":3,"message":"Remove spaces around = to assign (or use [ ] to compare, or quote '=' if literal)."},{"code":2284,"column":1,"endColumn":12,"endLine":4,"fix":null,"level":"error","line":4,"message":"Use [ x = y ] to compare values (or quote '==' if literal)."},{"code":2285,"column":1,"endColumn":14,"endLine":5,"fix":null,"level":"error","line":5,"message":"Remove spaces around += to assign (or quote '+=' if literal)."},{"code":2285,"column":1,"endColumn":13,"endLine":6,"fix":null,"level":"error","line":6,"message":"Remove spaces around += to assign (or quote '+=' if literal)."}]
@STDERR (empty)
[1]
```

### SC2270-SC2282

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2270-SC2282.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2277,"column":1,"endColumn":3,"endLine":3,"fix":{"replacements":[{"column":1,"endColumn":2,"endLine":3,"insertionPoint":"afterEnd","line":3,"precedence":7,"replacement":"BASH_ARGV0"}]},"level":"error","line":3,"message":"Use BASH_ARGV0 to assign to $0 in bash (or use [ ] to compare)."},{"code":2270,"column":1,"endColumn":3,"endLine":4,"fix":null,"level":"error","line":4,"message":"To assign positional parameters, use 'set -- first second ..' (or use [ ] to compare)."},{"code":2281,"column":1,"endColumn":5,"endLine":5,"fix":{"replacements":[{"column":1,"endColumn":2,"endLine":5,"insertionPoint":"afterEnd","line":5,"precedence":7,"replacement":""}]},"level":"error","line":5,"message":"Don't use $ on the left side of assignments."},{"code":2281,"column":1,"endColumn":7,"endLine":6,"fix":{"replacements":[{"column":1,"endColumn":3,"endLine":6,"insertionPoint":"afterEnd","line":6,"precedence":7,"replacement":""},{"column":6,"endColumn":7,"endLine":6,"insertionPoint":"beforeStart","line":6,"precedence":7,"replacement":""}]},"level":"error","line":6,"message":"Don't use ${} on the left side of assignments."},{"code":2271,"column":1,"endColumn":14,"endLine":7,"fix":null,"level":"error","line":7,"message":"For indirection, use arrays, declare \"var$n=value\", or (for sh) read/eval."},{"code":2273,"column":1,"endColumn":8,"endLine":8,"fix":null,"level":"error","line":8,"message":"Sequence of ===s found. Merge conflict or intended as a commented border?"},{"code":2274,"column":1,"endColumn":21,"endLine":9,"fix":null,"level":"error","line":9,"message":"Command name starts with ===. Intended as a commented border?"},{"code":2275,"column":1,"endColumn":4,"endLine":11,"fix":null,"level":"error","line":11,"message":"Command name starts with =. Bad line break?"},{"code":2282,"column":1,"endColumn":14,"endLine":12,"fix":null,"level":"error","line":12,"message":"Variable names can't start with numbers, so this is interpreted as a command."}]
@STDERR (empty)
[1]
```

### SC2209

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2209.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2209,"column":1,"endColumn":12,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Use var=$(command) to assign output (or quote to assign string)."},{"code":2209,"column":1,"endColumn":5,"endLine":4,"fix":null,"level":"warning","line":4,"message":"Use var=$(command) to assign output (or quote to assign string)."}]
@STDERR (empty)
[1]
```

## Array assignments and environment variables

### SC2123

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2123.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2123,"column":1,"endColumn":5,"endLine":3,"fix":null,"level":"warning","line":3,"message":"PATH is the shell search path. Use another name."},{"code":2123,"column":1,"endColumn":5,"endLine":4,"fix":null,"level":"warning","line":4,"message":"PATH is the shell search path. Use another name."},{"code":2123,"column":1,"endColumn":5,"endLine":5,"fix":null,"level":"warning","line":5,"message":"PATH is the shell search path. Use another name."}]
@STDERR (empty)
[1]
```

### SC2054

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2054.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2054,"column":3,"endColumn":9,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Use spaces, not commas, to separate array elements."},{"code":2054,"column":4,"endColumn":11,"endLine":4,"fix":null,"level":"warning","line":4,"message":"Use spaces, not commas, to separate array elements."},{"code":2054,"column":3,"endColumn":22,"endLine":7,"fix":null,"level":"warning","line":7,"message":"Use spaces, not commas, to separate array elements."}]
@STDERR (empty)
[1]
```

### SC2190-SC2192

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2190-SC2192.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2190,"column":22,"endColumn":25,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Elements in associative arrays need index, e.g. array=( [index]=value ) ."},{"code":2192,"column":13,"endColumn":13,"endLine":4,"fix":null,"level":"warning","line":4,"message":"This array element has no value. Remove spaces after = or use \"\" for empty string."},{"code":2190,"column":23,"endColumn":32,"endLine":5,"fix":null,"level":"warning","line":5,"message":"Elements in associative arrays need index, e.g. array=( [index]=value ) ."},{"code":2191,"column":7,"endColumn":14,"endLine":6,"fix":{"replacements":[{"column":7,"endColumn":7,"endLine":6,"insertionPoint":"afterEnd","line":6,"precedence":9,"replacement":"\""},{"column":14,"endColumn":14,"endLine":6,"insertionPoint":"beforeStart","line":6,"precedence":9,"replacement":"\""}]},"level":"warning","line":6,"message":"The = here is literal. To assign by index, use ( [index]=value ) with no spaces. To keep as literal, quote it."},{"code":2191,"column":9,"endColumn":15,"endLine":7,"fix":{"replacements":[{"column":9,"endColumn":9,"endLine":7,"insertionPoint":"afterEnd","line":7,"precedence":9,"replacement":"\""},{"column":15,"endColumn":15,"endLine":7,"insertionPoint":"beforeStart","line":7,"precedence":9,"replacement":"\""}]},"level":"warning","line":7,"message":"The = here is literal. To assign by index, use ( [index]=value ) with no spaces. To keep as literal, quote it."},{"code":2191,"column":15,"endColumn":21,"endLine":8,"fix":{"replacements":[{"column":15,"endColumn":15,"endLine":8,"insertionPoint":"afterEnd","line":8,"precedence":9,"replacement":"\""},{"column":21,"endColumn":21,"endLine":8,"insertionPoint":"beforeStart","line":8,"precedence":9,"replacement":"\""}]},"level":"warning","line":8,"message":"The = here is literal. To assign by index, use ( [index]=value ) with no spaces. To keep as literal, quote it."},{"code":2191,"column":13,"endColumn":14,"endLine":9,"fix":{"replacements":[{"column":13,"endColumn":13,"endLine":9,"insertionPoint":"afterEnd","line":9,"precedence":9,"replacement":"\""},{"column":14,"endColumn":14,"endLine":9,"insertionPoint":"beforeStart","line":9,"precedence":9,"replacement":"\""}]},"level":"warning","line":9,"message":"The = here is literal. To assign by index, use ( [index]=value ) with no spaces. To keep as literal, quote it."}]
@STDERR (empty)
[1]
```

## Loop variables and subshell scope

### SC2165-SC2167

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2165-SC2167.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2167,"column":1,"endColumn":4,"endLine":3,"fix":null,"level":"warning","line":3,"message":"This parent loop has its index variable overridden."},{"code":2165,"column":3,"endColumn":6,"endLine":4,"fix":null,"level":"warning","line":4,"message":"This nested loop overrides the index variable of its parent."}]
@STDERR (empty)
[1]
```

### SC2030-SC2031-pipeline

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2030-SC2031-pipeline.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2030,"column":33,"endColumn":34,"endLine":2,"fix":null,"level":"info","line":2,"message":"Modification of a is local (to subshell caused by pipeline)."},{"code":2031,"column":7,"endColumn":13,"endLine":3,"fix":null,"level":"info","line":3,"message":"a was modified in a subshell. That change might be lost."}]
@STDERR (empty)
[1]
```

### SC2030-SC2031-background

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/variables/SC2030-SC2031-background.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2030,"column":9,"endColumn":10,"endLine":2,"fix":null,"level":"info","line":2,"message":"Modification of n is local (to subshell caused by backgrounding &)."},{"code":2031,"column":18,"endColumn":20,"endLine":2,"fix":null,"level":"info","line":2,"message":"n was modified in a subshell. That change might be lost."}]
@STDERR (empty)
[1]
```
