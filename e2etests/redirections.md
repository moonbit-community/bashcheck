# Pipelines, stdin and redirections

Stream ordering, shared input, pipeline consumers, here-documents and conflicting file access.

These 12 cases use fixed JSON baselines checked against ShellCheck 0.11.0.
Runtime tests execute bashcheck and the pinned jq tool.

```mooncram-import
jq : cli/jq@0.2.1
```

## Redirection order, grouping and file conflicts

### SC2069

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2069.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2069,"column":10,"endColumn":14,"endLine":2,"fix":null,"level":"warning","line":2,"message":"To redirect stdout+stderr, 2>&1 must be last (or use '{ cmd > file; } 2>&1' to clarify)."},{"code":2069,"column":16,"endColumn":20,"endLine":3,"fix":null,"level":"warning","line":3,"message":"To redirect stdout+stderr, 2>&1 must be last (or use '{ cmd > file; } 2>&1' to clarify)."}]
@STDERR (empty)
[1]
```

### SC2129-SC2143

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2129-SC2143.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2129,"column":1,"endColumn":12,"endLine":2,"fix":null,"level":"style","line":2,"message":"Consider using { cmd1; cmd2; } >> file instead of individual redirects."},{"code":2143,"column":4,"endColumn":22,"endLine":3,"fix":null,"level":"style","line":3,"message":"Use grep -q instead of comparing output with [ -n .. ]."},{"code":2143,"column":3,"endColumn":5,"endLine":4,"fix":null,"level":"style","line":4,"message":"Use ! grep -q instead of comparing output with [ -z .. ]."}]
@STDERR (empty)
[1]
```

### SC2257

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2257.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2257,"column":19,"endColumn":21,"endLine":2,"fix":null,"level":"warning","line":2,"message":"Arithmetic modifications in command redirections may be discarded. Do them separately."},{"code":2257,"column":20,"endColumn":22,"endLine":3,"fix":null,"level":"warning","line":3,"message":"Arithmetic modifications in command redirections may be discarded. Do them separately."}]
@STDERR (empty)
[1]
```

### SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2188,"column":1,"endColumn":7,"endLine":2,"fix":null,"level":"warning","line":2,"message":"This redirection doesn't have a command. Move to its command (or use 'true' as no-op)."},{"code":2260,"column":1,"endColumn":2,"endLine":3,"fix":null,"level":"error","line":3,"message":"This redirection overrides the output pipe. Use 'tee' to output to both."},{"code":2189,"column":1,"endColumn":7,"endLine":3,"fix":null,"level":"error","line":3,"message":"You can't have | between this redirection and the command it should apply to."},{"code":2189,"column":12,"endColumn":17,"endLine":4,"fix":null,"level":"error","line":4,"message":"You can't have | between this redirection and the command it should apply to."},{"code":2216,"column":7,"endColumn":15,"endLine":5,"fix":null,"level":"warning","line":5,"message":"Piping to 'echo', a command that doesn't read stdin. Did you want 'cat' instead?"},{"code":2216,"column":7,"endColumn":26,"endLine":6,"fix":null,"level":"warning","line":6,"message":"Piping to 'basename', a command that doesn't read stdin. Wrong command or missing xargs?"},{"code":2217,"column":7,"endColumn":26,"endLine":6,"fix":null,"level":"warning","line":6,"message":"Redirecting to 'basename', a command that doesn't read stdin. Bad quoting, wrong command or missing xargs?"},{"code":2259,"column":16,"endColumn":17,"endLine":6,"fix":null,"level":"error","line":6,"message":"This redirection overrides piped input. To use both, merge or pass filenames."},{"code":2261,"column":4,"endColumn":5,"endLine":7,"fix":null,"level":"error","line":7,"message":"Multiple redirections compete for stdout. Use cat, tee, or pass filenames instead."},{"code":2261,"column":10,"endColumn":11,"endLine":7,"fix":null,"level":"error","line":7,"message":"Multiple redirections compete for stdout. Use cat, tee, or pass filenames instead."},{"code":2261,"column":4,"endColumn":5,"endLine":8,"fix":null,"level":"error","line":8,"message":"Multiple redirections compete for stdout. Use cat, tee, or pass filenames instead."},{"code":2261,"column":17,"endColumn":18,"endLine":8,"fix":null,"level":"error","line":8,"message":"Multiple redirections compete for stdout. Use cat, tee, or pass filenames instead."}]
@STDERR (empty)
[1]
```

### SC2094

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2094.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2094,"column":5,"endColumn":8,"endLine":2,"fix":null,"level":"info","line":2,"message":"Make sure not to read and write the same file in the same pipeline."},{"code":2094,"column":11,"endColumn":14,"endLine":2,"fix":null,"level":"info","line":2,"message":"Make sure not to read and write the same file in the same pipeline."},{"code":2094,"column":5,"endColumn":8,"endLine":3,"fix":null,"level":"info","line":3,"message":"Make sure not to read and write the same file in the same pipeline."},{"code":2094,"column":30,"endColumn":33,"endLine":3,"fix":null,"level":"info","line":3,"message":"Make sure not to read and write the same file in the same pipeline."}]
@STDERR (empty)
[1]
```

## Shared stdin in read loops

### SC2095-direct

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2095-direct.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2095,"column":1,"endColumn":46,"endLine":2,"fix":null,"level":"info","line":2,"message":"ssh may swallow stdin, preventing this loop from working properly."},{"code":2095,"column":23,"endColumn":40,"endLine":2,"fix":{"replacements":[{"column":26,"endColumn":26,"endLine":2,"insertionPoint":"beforeStart","line":2,"precedence":9,"replacement":" -n"}]},"level":"warning","line":2,"message":"Use ssh -n to prevent ssh from swallowing stdin."},{"code":2095,"column":1,"endColumn":58,"endLine":3,"fix":null,"level":"info","line":3,"message":"ffmpeg may swallow stdin, preventing this loop from working properly."},{"code":2095,"column":23,"endColumn":52,"endLine":3,"fix":{"replacements":[{"column":29,"endColumn":29,"endLine":3,"insertionPoint":"beforeStart","line":3,"precedence":9,"replacement":" -nostdin"}]},"level":"warning","line":3,"message":"Use ffmpeg -nostdin to prevent ffmpeg from swallowing stdin."},{"code":2095,"column":1,"endColumn":51,"endLine":4,"fix":null,"level":"info","line":4,"message":"mplayer may swallow stdin, preventing this loop from working properly."},{"code":2095,"column":23,"endColumn":45,"endLine":4,"fix":{"replacements":[{"column":30,"endColumn":30,"endLine":4,"insertionPoint":"beforeStart","line":4,"precedence":9,"replacement":" -noconsolecontrols"}]},"level":"warning","line":4,"message":"Use mplayer -noconsolecontrols to prevent mplayer from swallowing stdin."},{"code":2095,"column":1,"endColumn":60,"endLine":5,"fix":null,"level":"info","line":5,"message":"HandBrakeCLI may swallow stdin, preventing this loop from working properly."},{"code":2095,"column":23,"endColumn":54,"endLine":5,"fix":{"replacements":[{"column":54,"endColumn":54,"endLine":5,"insertionPoint":"beforeStart","line":5,"precedence":8,"replacement":" < /dev/null"}]},"level":"warning","line":5,"message":"Use HandBrakeCLI < /dev/null to prevent HandBrakeCLI from swallowing stdin."}]
@STDERR (empty)
[1]
```

### SC2095-nested-assignment

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2095-nested-assignment.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2095,"column":1,"endColumn":46,"endLine":3,"fix":null,"level":"info","line":3,"message":"ssh may swallow stdin, preventing this loop from working properly."},{"code":2095,"column":27,"endColumn":39,"endLine":3,"fix":{"replacements":[{"column":30,"endColumn":30,"endLine":3,"insertionPoint":"beforeStart","line":3,"precedence":15,"replacement":" -n"}]},"level":"warning","line":3,"message":"Use ssh -n to prevent ssh from swallowing stdin."}]
@STDERR (empty)
[1]
```

### SC2095-nested-if-and-background

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2095-nested-if-and-background.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2095,"column":1,"endColumn":64,"endLine":2,"fix":null,"level":"info","line":2,"message":"ssh may swallow stdin, preventing this loop from working properly."},{"code":2095,"column":37,"endColumn":54,"endLine":2,"fix":{"replacements":[{"column":40,"endColumn":40,"endLine":2,"insertionPoint":"beforeStart","line":2,"precedence":12,"replacement":" -n"}]},"level":"warning","line":2,"message":"Use ssh -n to prevent ssh from swallowing stdin."},{"code":2095,"column":1,"endColumn":47,"endLine":3,"fix":null,"level":"info","line":3,"message":"ssh may swallow stdin, preventing this loop from working properly."},{"code":2095,"column":23,"endColumn":40,"endLine":3,"fix":{"replacements":[{"column":26,"endColumn":26,"endLine":3,"insertionPoint":"beforeStart","line":3,"precedence":10,"replacement":" -n"}]},"level":"warning","line":3,"message":"Use ssh -n to prevent ssh from swallowing stdin."}]
@STDERR (empty)
[1]
```

## Pipeline consumers and here-documents

### SC2216-nested-pipeline-in-command-substitution

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2216-nested-pipeline-in-command-substitution.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2046,"column":6,"endColumn":23,"endLine":2,"fix":null,"level":"warning","line":2,"message":"Quote this to prevent word splitting."},{"code":2005,"column":6,"endColumn":23,"endLine":2,"fix":null,"level":"style","line":2,"message":"Useless echo? Instead of 'echo $(cmd)', just use 'cmd'."},{"code":2216,"column":14,"endColumn":22,"endLine":2,"fix":null,"level":"warning","line":2,"message":"Piping to 'echo', a command that doesn't read stdin. Did you want 'cat' instead?"}]
@STDERR (empty)
[1]
```

### SC2216-here-doc-nested-consumer

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2216-here-doc-nested-consumer.sh | jq -c -S -M -f normalize.jq
@STDOUT
[]
@STDERR (empty)
```

### SC2259-quoted-here-doc

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2259-quoted-here-doc.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2259,"column":21,"endColumn":26,"endLine":2,"fix":null,"level":"error","line":2,"message":"This redirection overrides piped input. To use both, merge or pass filenames."}]
@STDERR (empty)
[1]
```

### SC2216-command-exceptions-and-fd-dup

```mooncram moonbit-community/bashcheck
$ bashcheck --norc -fjson fixtures/redirections/SC2216-command-exceptions-and-fd-dup.sh | jq -c -S -M -f normalize.jq
@STDOUT
[{"code":2035,"column":24,"endColumn":25,"endLine":5,"fix":null,"level":"info","line":5,"message":"Use ./*glob* or -- *glob* so names with dashes won't become options."}]
@STDERR (empty)
[1]
```
