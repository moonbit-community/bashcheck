# Arithmetic expressions

Integer arithmetic, expansion syntax, evaluation order and arithmetic style.

These 5 cases use fixed JSON baselines checked against ShellCheck 0.11.0.
Runtime tests execute bashcheck and the pinned jq tool.

```mooncram-import
jq : cli/jq@0.2.1
```

## Arithmetic expansion and evaluation

### SC2004-SC2017

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/arithmetic/SC2004-SC2017.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2004,"column":10,"endColumn":14,"endLine":4,"fix":null,"level":"style","line":4,"message":"$/${} is unnecessary on arithmetic variables."},{"code":2017,"column":12,"endColumn":13,"endLine":5,"fix":null,"level":"info","line":5,"message":"Increase precision by replacing a/b*c with a*c/b."}]
@STDERR (empty)
[1]
```

### SC2079

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/arithmetic/SC2079.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2079,"column":3,"endColumn":7,"endLine":2,"fix":null,"level":"error","line":2,"message":"(( )) doesn't support decimals. Use bc or awk."}]
@STDERR (empty)
[1]
```

### SC2007

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/arithmetic/SC2007.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2007,"column":6,"endColumn":12,"endLine":2,"fix":null,"level":"style","line":2,"message":"Use $((..)) instead of deprecated $[..]"}]
@STDERR (empty)
[1]
```

### SC2084

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/arithmetic/SC2084.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2084,"column":1,"endColumn":9,"endLine":2,"fix":null,"level":"error","line":2,"message":"Remove '$' or use '_=$((expr))' to avoid executing output."}]
@STDERR (empty)
[1]
```

## Arithmetic style and assignments

### SC2321-SC2324

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/arithmetic/SC2321-SC2324.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2321,"column":3,"endColumn":11,"endLine":3,"fix":{"replacements":[{"column":3,"endColumn":6,"endLine":3,"insertionPoint":"afterEnd","line":3,"precedence":9,"replacement":""},{"column":9,"endColumn":11,"endLine":3,"insertionPoint":"beforeStart","line":3,"precedence":9,"replacement":""}]},"level":"style","line":3,"message":"Array indices are already arithmetic contexts. Prefer removing the $(( and ))."},{"code":2323,"column":10,"endColumn":17,"endLine":4,"fix":{"replacements":[{"column":10,"endColumn":11,"endLine":4,"insertionPoint":"afterEnd","line":4,"precedence":9,"replacement":""},{"column":16,"endColumn":17,"endLine":4,"insertionPoint":"beforeStart","line":4,"precedence":9,"replacement":""}]},"level":"style","line":4,"message":"$(( (x) )) is the same as $(( x )). Prefer not wrapping in additional parentheses."},{"code":2322,"column":11,"endColumn":16,"endLine":4,"fix":{"replacements":[{"column":11,"endColumn":12,"endLine":4,"insertionPoint":"afterEnd","line":4,"precedence":11,"replacement":""},{"column":15,"endColumn":16,"endLine":4,"insertionPoint":"beforeStart","line":4,"precedence":11,"replacement":""}]},"level":"style","line":4,"message":"In arithmetic contexts, ((x)) is the same as (x). Prefer only one layer of parentheses."},{"code":2323,"column":10,"endColumn":13,"endLine":5,"fix":{"replacements":[{"column":10,"endColumn":11,"endLine":5,"insertionPoint":"afterEnd","line":5,"precedence":9,"replacement":""},{"column":12,"endColumn":13,"endLine":5,"insertionPoint":"beforeStart","line":5,"precedence":9,"replacement":""}]},"level":"style","line":5,"message":"$(( (x) )) is the same as $(( x )). Prefer not wrapping in additional parentheses."},{"code":2324,"column":1,"endColumn":2,"endLine":7,"fix":null,"level":"warning","line":7,"message":"var+=1 will append, not increment. Use (( var += 1 )), typeset -i var, or quote number to silence."},{"code":2324,"column":1,"endColumn":2,"endLine":8,"fix":null,"level":"warning","line":8,"message":"var+=1 will append, not increment. Use (( var += 1 )), typeset -i var, or quote number to silence."}]
@STDERR (empty)
[1]
```
