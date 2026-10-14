# Command usage

Formatting and text tools, builtin arguments, command substitution and find pipelines.

These 13 cases use fixed JSON baselines checked against ShellCheck 0.11.0.
Runtime tests execute bashcheck and the pinned jq tool.

```mooncram-import
jq : cli/jq@0.2.1
```

## Formatting, text tools and builtin usage

### SC2059-SC2060-SC2063

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2059-SC2060-SC2063.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2059,"column":8,"endColumn":14,"endLine":3,"fix":null,"level":"info","line":3,"message":"Don't use variables in the printf format string. Use printf '..%s..' \"$foo\"."},{"code":2060,"column":4,"endColumn":9,"endLine":4,"fix":null,"level":"warning","line":4,"message":"Quote parameters to tr to prevent glob expansion."},{"code":2060,"column":10,"endColumn":15,"endLine":4,"fix":null,"level":"warning","line":4,"message":"Quote parameters to tr to prevent glob expansion."},{"code":2063,"column":6,"endColumn":13,"endLine":5,"fix":null,"level":"warning","line":5,"message":"Grep uses regex, but this looks like a glob."}]
@STDERR (empty)
[1]
```

### SC2020-SC2021-SC2227

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2020-SC2021-SC2227.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2020,"column":4,"endColumn":7,"endLine":2,"fix":null,"level":"info","line":2,"message":"tr replaces sets of chars, not words (mentioned due to duplicates)."},{"code":2021,"column":4,"endColumn":11,"endLine":3,"fix":null,"level":"info","line":3,"message":"Don't use [] around classes in tr, it replaces literal square brackets."},{"code":2021,"column":12,"endColumn":19,"endLine":3,"fix":null,"level":"info","line":3,"message":"Don't use [] around classes in tr, it replaces literal square brackets."},{"code":2227,"column":22,"endColumn":28,"endLine":4,"fix":null,"level":"warning","line":4,"message":"Redirection applies to the find command itself. Rewrite to work per action (or move to end)."}]
@STDERR (empty)
[1]
```

### SC2305-SC2307-SC2308

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2305-SC2307-SC2308.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2308,"column":6,"endColumn":11,"endLine":3,"fix":null,"level":"info","line":3,"message":"'expr match' has unspecified results. Prefer 'expr str : regex'."},{"code":2305,"column":12,"endColumn":15,"endLine":4,"fix":null,"level":"warning","line":4,"message":"Quote regex argument to expr to avoid it expanding as a glob."},{"code":2307,"column":1,"endColumn":10,"endLine":5,"fix":null,"level":"warning","line":5,"message":"'expr' expects 3+ arguments, but sees 2. Make sure each operator/operand is a separate argument, and escape <>&|."}]
@STDERR (empty)
[1]
```

### SC2306

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2306.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2306,"column":12,"endColumn":13,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Escape glob characters in arguments to expr to avoid pathname expansion."},{"code":2306,"column":12,"endColumn":17,"endLine":4,"fix":null,"level":"warning","line":4,"message":"Escape glob characters in arguments to expr to avoid pathname expansion."}]
@STDERR (empty)
[1]
```

### SC2001

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2001.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2001,"column":7,"endColumn":38,"endLine":3,"fix":null,"level":"style","line":3,"message":"See if you can use ${variable//search/replace} instead."}]
@STDERR (empty)
[1]
```

### SC2028

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2028.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2028,"column":6,"endColumn":11,"endLine":2,"fix":null,"level":"info","line":2,"message":"echo may not expand escape sequences. Use printf."}]
@STDERR (empty)
[1]
```

## Command names and command substitution

### SC2289

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2289.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2289,"column":1,"endColumn":12,"endLine":2,"fix":null,"level":"error","line":2,"message":"This is interpreted as a command name containing a tab. Double check syntax."}]
@STDERR (empty)
[1]
```

### SC2256

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2256.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2256,"column":15,"endColumn":26,"endLine":3,"fix":{"replacements":[{"column":15,"endColumn":17,"endLine":3,"insertionPoint":"afterEnd","line":3,"precedence":7,"replacement":"\"$"}]},"level":"warning","line":3,"message":"This translated string is the name of a variable. Flip leading $ and \" if this should be a quoted substitution."}]
@STDERR (empty)
[1]
```

### SC2091

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2091.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2091,"column":1,"endColumn":7,"endLine":2,"fix":null,"level":"warning","line":2,"message":"Remove surrounding $() to avoid executing output (or use eval if intentional)."}]
@STDERR (empty)
[1]
```

### SC2092

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2092.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2092,"column":1,"endColumn":6,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Remove backticks to avoid executing output (or use eval if intentional)."}]
@STDERR (empty)
[1]
```

### SC2116

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2116.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2116,"column":5,"endColumn":16,"endLine":3,"fix":null,"level":"style","line":3,"message":"Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'."}]
@STDERR (empty)
[1]
```

## Pipeline commands and find execution

### SC2009-SC2013-SC2038-SC2126

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2009-SC2013-SC2038-SC2126.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2009,"column":1,"endColumn":7,"endLine":2,"fix":null,"level":"info","line":2,"message":"Consider using pgrep instead of grepping ps output."},{"code":2010,"column":1,"endColumn":3,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Don't use ls | grep. Use a glob or a for loop with a condition to allow non-alphanumeric filenames."},{"code":2011,"column":1,"endColumn":3,"endLine":4,"fix":null,"level":"warning","line":4,"message":"Use 'find .. -print0 | xargs -0 ..' or 'find .. -exec .. +' to allow non-alphanumeric filenames."},{"code":2012,"column":1,"endColumn":3,"endLine":5,"fix":null,"level":"info","line":5,"message":"Use find instead of ls to better handle non-alphanumeric filenames."},{"code":2013,"column":10,"endColumn":20,"endLine":6,"fix":null,"level":"info","line":6,"message":"To read lines rather than words, pipe/redirect to a 'while read' loop."},{"code":2038,"column":1,"endColumn":7,"endLine":7,"fix":null,"level":"warning","line":7,"message":"Use 'find .. -print0 | xargs -0 ..' or 'find .. -exec .. +' to allow non-alphanumeric filenames."},{"code":2126,"column":1,"endColumn":14,"endLine":8,"fix":null,"level":"style","line":8,"message":"Consider using 'grep -c' instead of 'grep|wc -l'."}]
@STDERR (empty)
[1]
```

### SC2014-SC2067

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/commands/SC2014-SC2067.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2046,"column":19,"endColumn":26,"endLine":2,"fix":null,"level":"warning","line":2,"message":"Quote this to prevent word splitting."},{"code":2014,"column":19,"endColumn":26,"endLine":2,"fix":null,"level":"info","line":2,"message":"This will expand once before find runs, not per file found."},{"code":2067,"column":31,"endColumn":33,"endLine":3,"fix":null,"level":"error","line":3,"message":"Missing ';' or + terminating -exec. You can't use |/||/&&, and ';' has to be a separate, quoted argument."}]
@STDERR (empty)
[1]
```
