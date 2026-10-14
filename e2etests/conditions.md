# Condition expressions

Test syntax, logical operators, comparisons, operand expansion and optional condition checks.

These 14 cases use fixed JSON baselines checked against ShellCheck 0.11.0.
Runtime tests execute bashcheck and the pinned jq tool.

```mooncram-import
jq : cli/jq@0.2.1
```

## Test syntax and logical operators

### SC2107-SC2108-SC2109-SC2110

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2107-SC2108-SC2109-SC2110.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2107,"column":8,"endColumn":10,"endLine":2,"fix":null,"level":"error","line":2,"message":"Instead of [ a && b ], use [ a ] && [ b ]."},{"code":2108,"column":9,"endColumn":11,"endLine":3,"fix":null,"level":"error","line":3,"message":"In [[..]], use && instead of -a."},{"code":2109,"column":8,"endColumn":10,"endLine":4,"fix":null,"level":"error","line":4,"message":"Instead of [ a || b ], use [ a ] || [ b ]."},{"code":2110,"column":9,"endColumn":11,"endLine":5,"fix":null,"level":"error","line":5,"message":"In [[..]], use || instead of -o."}]
@STDERR (empty)
[1]
```

### SC2265-SC2266

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2265-SC2266.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2265,"column":10,"endColumn":11,"endLine":4,"fix":{"replacements":[{"column":11,"endColumn":11,"endLine":4,"insertionPoint":"beforeStart","line":4,"precedence":3,"replacement":"&"}]},"level":"error","line":4,"message":"Use && for logical AND. Single & will background and return true."},{"code":2265,"column":13,"endColumn":14,"endLine":5,"fix":{"replacements":[{"column":14,"endColumn":14,"endLine":5,"insertionPoint":"beforeStart","line":5,"precedence":3,"replacement":"&"}]},"level":"error","line":5,"message":"Use && for logical AND. Single & will background and return true."},{"code":2266,"column":10,"endColumn":11,"endLine":6,"fix":{"replacements":[{"column":11,"endColumn":11,"endLine":6,"insertionPoint":"beforeStart","line":6,"precedence":4,"replacement":"|"}]},"level":"warning","line":6,"message":"Use || for logical OR. Single | will pipe."}]
@STDERR (empty)
[1]
```

### SC1033

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC1033.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":1033,"column":11,"endColumn":11,"endLine":3,"fix":null,"level":"error","line":3,"message":"Test expression was opened with double [[ but closed with single ]. Make sure they match."}]
@STDERR (empty)
[1]
```

### SC1034

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC1034.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":1034,"column":1,"endColumn":1,"endLine":3,"fix":null,"level":"error","line":3,"message":"Test expression was opened with single [ but closed with double ]]. Make sure they match."}]
@STDERR (empty)
[1]
```

## Operands, comparisons and glob patterns

### SC2070-SC2074-SC2075-SC2077

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2070-SC2074-SC2075-SC2077.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2070,"column":6,"endColumn":10,"endLine":3,"fix":null,"level":"error","line":3,"message":"-n doesn't work with unquoted arguments. Quote or use [[ ]]."},{"code":2077,"column":7,"endColumn":9,"endLine":4,"fix":null,"level":"error","line":4,"message":"You need spaces around the comparison operator."},{"code":2074,"column":8,"endColumn":10,"endLine":6,"fix":null,"level":"error","line":6,"message":"Can't use =~ in [ ]. Use [[..]] instead."},{"code":2075,"column":7,"endColumn":9,"endLine":8,"fix":null,"level":"error","line":8,"message":"Escaping \\< is required in [..], but invalid in [[..]]"}]
@STDERR (empty)
[1]
```

### SC2144-SC2198-SC2208-SC2255-bash

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2144-SC2198-SC2208-SC2255-bash.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2144,"column":6,"endColumn":11,"endLine":3,"fix":null,"level":"error","line":3,"message":"-f doesn't work with globs. Use a for loop."},{"code":2199,"column":7,"endColumn":16,"endLine":4,"fix":null,"level":"error","line":4,"message":"Arrays implicitly concatenate in [[ ]]. Use a loop (or explicit * instead of @)."},{"code":2198,"column":6,"endColumn":15,"endLine":5,"fix":null,"level":"warning","line":5,"message":"Arrays don't work as operands in [ ]. Use a loop (or concatenate with * instead of @)."},{"code":2070,"column":6,"endColumn":11,"endLine":6,"fix":null,"level":"error","line":6,"message":"-n doesn't work with unquoted arguments. Quote or use [[ ]]."},{"code":2200,"column":6,"endColumn":11,"endLine":6,"fix":null,"level":"warning","line":6,"message":"Brace expansions don't work as operands in [ ]. Use a loop."},{"code":2201,"column":7,"endColumn":12,"endLine":7,"fix":null,"level":"error","line":7,"message":"Brace expansion doesn't happen in [[ ]]. Use a loop."},{"code":2202,"column":3,"endColumn":8,"endLine":8,"fix":null,"level":"warning","line":8,"message":"Globs don't work as operands in [ ]. Use a loop."},{"code":2203,"column":4,"endColumn":9,"endLine":9,"fix":null,"level":"error","line":9,"message":"Globs are ignored in [[ ]] except right of =/!=. Use a loop."},{"code":2255,"column":9,"endColumn":12,"endLine":10,"fix":null,"level":"error","line":10,"message":"[ ] does not apply arithmetic evaluation. Evaluate with $((..)) for numbers, or use string comparator for strings."},{"code":2208,"column":6,"endColumn":11,"endLine":11,"fix":null,"level":"error","line":11,"message":"Use [[ ]] or quote arguments to -v to avoid glob expansion."}]
@STDERR (empty)
[1]
```

### SC2245-ksh

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2245-ksh.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2245,"column":6,"endColumn":11,"endLine":2,"fix":null,"level":"warning","line":2,"message":"-f only applies to the first expansion of this glob. Use a loop to check any/all."}]
@STDERR (empty)
[1]
```

### SC2050

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2050.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2050,"column":6,"endColumn":8,"endLine":2,"fix":null,"level":"warning","line":2,"message":"This expression is constant. Did you forget the $ on a variable?"}]
@STDERR (empty)
[1]
```

### SC2268

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2268.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2268,"column":3,"endColumn":10,"endLine":3,"fix":{"replacements":[{"column":3,"endColumn":4,"endLine":3,"insertionPoint":"afterEnd","line":3,"precedence":8,"replacement":""},{"column":13,"endColumn":14,"endLine":3,"insertionPoint":"afterEnd","line":3,"precedence":8,"replacement":""}]},"level":"style","line":3,"message":"Avoid x-prefix in comparisons as it no longer serves a purpose."},{"code":2268,"column":6,"endColumn":11,"endLine":4,"fix":{"replacements":[{"column":6,"endColumn":7,"endLine":4,"insertionPoint":"afterEnd","line":4,"precedence":7,"replacement":""},{"column":14,"endColumn":15,"endLine":4,"insertionPoint":"afterEnd","line":4,"precedence":7,"replacement":""}]},"level":"style","line":4,"message":"Avoid x-prefix in comparisons as it no longer serves a purpose."}]
@STDERR (empty)
[1]
```

## Constant and optional conditions

### SC2158-SC2159-SC2160-SC2161

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2158-SC2159-SC2160-SC2161.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2158,"column":3,"endColumn":8,"endLine":2,"fix":null,"level":"error","line":2,"message":"[ false ] is true. Remove the brackets."},{"code":2159,"column":3,"endColumn":4,"endLine":3,"fix":null,"level":"error","line":3,"message":"[ 0 ] is true. Use 'false' instead."},{"code":2160,"column":3,"endColumn":7,"endLine":4,"fix":null,"level":"style","line":4,"message":"Instead of '[ true ]', just use 'true'."},{"code":2161,"column":3,"endColumn":4,"endLine":5,"fix":null,"level":"style","line":5,"message":"Instead of '[ 1 ]', use 'true'."}]
@STDERR (empty)
[1]
```

### SC2237-SC2243-SC2335

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2237-SC2243-SC2335.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2237,"column":1,"endColumn":2,"endLine":4,"fix":null,"level":"style","line":4,"message":"Use [ -z .. ] instead of ! [ -n .. ]."},{"code":2243,"column":4,"endColumn":10,"endLine":5,"fix":{"replacements":[{"column":4,"endColumn":4,"endLine":5,"insertionPoint":"afterEnd","line":5,"precedence":7,"replacement":"-n "}]},"level":"style","line":5,"message":"Prefer explicit -n to check for output (or run command without [/[[ to check for success)."},{"code":2335,"column":1,"endColumn":2,"endLine":6,"fix":null,"level":"style","line":6,"message":"Use [[ a -le b ]] instead of ! [[ a -gt b ]]."}]
@STDERR (empty)
[1]
```

## Unary file tests

### SC2332

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2332.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2332,"column":3,"endColumn":4,"endLine":3,"fix":null,"level":"error","line":3,"message":"[ ! -a file ] is always true because -a becomes logical AND. Use -e instead."}]
@STDERR (empty)
[1]
```

### SC2331

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2331.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2331,"column":3,"endColumn":5,"endLine":2,"fix":{"replacements":[{"column":3,"endColumn":5,"endLine":2,"insertionPoint":"afterEnd","line":2,"precedence":6,"replacement":"-e"}]},"level":"style","line":2,"message":"For file existence, prefer standard -e over legacy -a."}]
@STDERR (empty)
[1]
```

### SC2331 (repeat regression)

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/conditions/SC2331.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2331,"column":3,"endColumn":5,"endLine":2,"fix":{"replacements":[{"column":3,"endColumn":5,"endLine":2,"insertionPoint":"afterEnd","line":2,"precedence":6,"replacement":"-e"}]},"level":"style","line":2,"message":"For file existence, prefer standard -e over legacy -a."}]
@STDERR (empty)
[1]
```
