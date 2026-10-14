# Expansions and quoting

Quoting, word splitting, parameter expansion, arrays, braces and glob patterns.

These 18 cases use fixed JSON baselines checked against ShellCheck 0.11.0.
Runtime tests execute bashcheck and the pinned jq tool.

```mooncram-import
jq : cli/jq@0.2.1
```

## Quoting and word splitting

### SC2086-mixed-word

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2086-mixed-word.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2086,"column":7,"endColumn":11,"endLine":3,"fix":{"replacements":[{"column":7,"endColumn":7,"endLine":3,"insertionPoint":"afterEnd","line":3,"precedence":7,"replacement":"\""},{"column":11,"endColumn":11,"endLine":3,"insertionPoint":"beforeStart","line":3,"precedence":7,"replacement":"\""}]},"level":"info","line":3,"message":"Double quote to prevent globbing and word splitting."}]
@STDERR (empty)
[1]
```

### SC2247

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2247.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2247,"column":1,"endColumn":9,"endLine":2,"fix":{"replacements":[{"column":1,"endColumn":3,"endLine":2,"insertionPoint":"afterEnd","line":2,"precedence":7,"replacement":"\"$"}]},"level":"warning","line":2,"message":"Flip leading $ and \" if this should be a quoted substitution."},{"code":2288,"column":1,"endColumn":9,"endLine":2,"fix":null,"level":"warning","line":2,"message":"This is interpreted as a command name ending with ')'. Double check syntax."}]
@STDERR (empty)
[1]
```

### SC2016

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2016.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2016,"column":6,"endColumn":12,"endLine":2,"fix":null,"level":"info","line":2,"message":"Expressions don't expand in single quotes, use double quotes for that."}]
@STDERR (empty)
[1]
```

### SC2086

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2086.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2086,"column":6,"endColumn":10,"endLine":3,"fix":{"replacements":[{"column":6,"endColumn":6,"endLine":3,"insertionPoint":"afterEnd","line":3,"precedence":7,"replacement":"\""},{"column":10,"endColumn":10,"endLine":3,"insertionPoint":"beforeStart","line":3,"precedence":7,"replacement":"\""}]},"level":"info","line":3,"message":"Double quote to prevent globbing and word splitting."}]
@STDERR (empty)
[1]
```

### SC2088

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2088.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2088,"column":6,"endColumn":15,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Tilde does not expand in quotes. Use $HOME."}]
@STDERR (empty)
[1]
```

### SC2140

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2140.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2140,"column":16,"endColumn":18,"endLine":2,"fix":null,"level":"warning","line":2,"message":"Word is of the form \"A\"B\"C\" (B indicated). Did you mean \"ABC\" or \"A\\\"B\\\"C\"?"}]
@STDERR (empty)
[1]
```

### SC2026

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2026.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2026,"column":11,"endColumn":14,"endLine":3,"fix":null,"level":"info","line":3,"message":"This word is outside of quotes. Did you intend to 'nest '\"'single quotes'\"' instead'? "}]
@STDERR (empty)
[1]
```

### SC2027

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2027.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2027,"column":9,"endColumn":11,"endLine":3,"fix":null,"level":"warning","line":3,"message":"The surrounding quotes actually unquote this. Remove or escape them."}]
@STDERR (empty)
[1]
```

### SC2025

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2025.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2025,"column":5,"endColumn":22,"endLine":2,"fix":null,"level":"info","line":2,"message":"Make sure all escape sequences are enclosed in \\[..\\] to prevent line wrapping issues"}]
@STDERR (empty)
[1]
```

### SC2089-SC2090-bash

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2089-SC2090-bash.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2089,"column":7,"endColumn":20,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Quotes/backslashes will be treated literally. Use an array."},{"code":2090,"column":26,"endColumn":32,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Quotes/backslashes in this variable will not be respected."},{"code":2089,"column":7,"endColumn":17,"endLine":4,"fix":null,"level":"warning","line":4,"message":"Quotes/backslashes will be treated literally. Use an array."},{"code":2090,"column":36,"endColumn":40,"endLine":4,"fix":null,"level":"warning","line":4,"message":"Quotes/backslashes in this variable will not be respected."}]
@STDERR (empty)
[1]
```

### SC2089-SC2090-sh

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2089-SC2090-sh.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2089,"column":7,"endColumn":20,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Quotes/backslashes will be treated literally. Rewrite using set/\"$@\" or functions."},{"code":2090,"column":26,"endColumn":32,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Quotes/backslashes in this variable will not be respected."}]
@STDERR (empty)
[1]
```

## Parameter and array expansions

### SC2082-SC2124-SC2125-SC2223

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2082-SC2124-SC2125-SC2223.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2082,"column":6,"endColumn":14,"endLine":3,"fix":null,"level":"error","line":3,"message":"To expand via indirection, use arrays, ${!name} or (for sh only) eval."},{"code":2124,"column":3,"endColumn":7,"endLine":4,"fix":null,"level":"warning","line":4,"message":"Assigning an array to a string! Assign as array, or use * instead of @ to concatenate."},{"code":2125,"column":3,"endColumn":8,"endLine":5,"fix":null,"level":"warning","line":5,"message":"Brace expansions and globs are literal in assignments. Quote it or use an array."},{"code":2223,"column":3,"endColumn":9,"endLine":6,"fix":null,"level":"info","line":6,"message":"This default assignment may cause DoS due to globbing. Quote it."}]
@STDERR (empty)
[1]
```

### analytics bad parameter substitutions

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/analytics-bad-parameter-substitutions.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2297,"column":8,"endColumn":13,"endLine":3,"fix":null,"level":"error","line":3,"message":"Double quotes must be outside ${}: ${\"invalid\"} vs \"${valid}\"."},{"code":2296,"column":8,"endColumn":12,"endLine":4,"fix":null,"level":"error","line":4,"message":"Parameter expansions can't start with {. Double check syntax."},{"code":2300,"column":8,"endColumn":12,"endLine":5,"fix":null,"level":"error","line":5,"message":"Parameter expansion can't be applied to command substitutions. Use temporary variables."},{"code":2301,"column":8,"endColumn":13,"endLine":6,"fix":null,"level":"error","line":6,"message":"Parameter expansion starts with unexpected quotes. Double check syntax."},{"code":2299,"column":8,"endColumn":15,"endLine":7,"fix":null,"level":"error","line":7,"message":"Parameter expansions can't be nested. Use temporary variables."},{"code":2298,"column":8,"endColumn":12,"endLine":8,"fix":null,"level":"error","line":8,"message":"${${x}} is invalid. For expansion, use ${x}. For indirection, use arrays, ${!x} or (for sh) eval."}]
@STDERR (empty)
[1]
```

### SC2145-SC2295

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2145-SC2295.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2145,"column":10,"endColumn":12,"endLine":2,"fix":null,"level":"error","line":2,"message":"Argument mixes string and array. Use * or separate argument."},{"code":2154,"column":6,"endColumn":15,"endLine":3,"fix":null,"level":"warning","line":3,"message":"var is referenced but not assigned."},{"code":2086,"column":6,"endColumn":15,"endLine":3,"fix":{"replacements":[{"column":6,"endColumn":6,"endLine":3,"insertionPoint":"afterEnd","line":3,"precedence":7,"replacement":"\""},{"column":15,"endColumn":15,"endLine":3,"insertionPoint":"beforeStart","line":3,"precedence":7,"replacement":"\""}]},"level":"info","line":3,"message":"Double quote to prevent globbing and word splitting."},{"code":2295,"column":12,"endColumn":14,"endLine":3,"fix":{"replacements":[{"column":12,"endColumn":12,"endLine":3,"insertionPoint":"afterEnd","line":3,"precedence":9,"replacement":"\""},{"column":14,"endColumn":14,"endLine":3,"insertionPoint":"beforeStart","line":3,"precedence":9,"replacement":"\""}]},"level":"info","line":3,"message":"Expansions inside ${..} need to be quoted separately, otherwise they match as patterns."},{"code":2154,"column":7,"endColumn":17,"endLine":4,"fix":null,"level":"warning","line":4,"message":"name is referenced but not assigned."},{"code":2295,"column":14,"endColumn":16,"endLine":4,"fix":{"replacements":[{"column":14,"endColumn":14,"endLine":4,"insertionPoint":"afterEnd","line":4,"precedence":10,"replacement":"\""},{"column":16,"endColumn":16,"endLine":4,"insertionPoint":"beforeStart","line":4,"precedence":10,"replacement":"\""}]},"level":"info","line":4,"message":"Expansions inside ${..} need to be quoted separately, otherwise they match as patterns."}]
@STDERR (empty)
[1]
```

### SC2180

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2180.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2180,"column":6,"endColumn":18,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Bash does not support multidimensional arrays. Use 1D or associative arrays."}]
@STDERR (empty)
[1]
```

## Brace expansion and glob patterns

### SC2101-SC2102-SC2171-SC2193

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2101-SC2102-SC2171-SC2193.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2101,"column":5,"endColumn":14,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Named class needs outer [], e.g. [[:digit:]]."},{"code":2102,"column":4,"endColumn":11,"endLine":4,"fix":null,"level":"info","line":4,"message":"Ranges can only match single chars (mentioned due to duplicates)."},{"code":2171,"column":9,"endColumn":11,"endLine":5,"fix":null,"level":"warning","line":5,"message":"Found trailing ]] outside test. Add missing [[ or quote if intentional."},{"code":2193,"column":10,"endColumn":12,"endLine":6,"fix":null,"level":"warning","line":6,"message":"The arguments to this comparison can never be equal. Make sure your syntax is correct."}]
@STDERR (empty)
[1]
```

### SC2051

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2051.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2051,"column":6,"endColumn":13,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Bash doesn't support variables in brace range expansions."}]
@STDERR (empty)
[1]
```

### SC2175

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/expansions/SC2175.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2175,"column":14,"endColumn":24,"endLine":3,"fix":null,"level":"style","line":3,"message":"Quote this invalid brace expansion since it should be passed literally to eval."}]
@STDERR (empty)
[1]
```
