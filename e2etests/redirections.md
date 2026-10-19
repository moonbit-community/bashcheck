# Pipelines, stdin and redirections

Stream ordering, shared input, pipeline consumers, here-documents and conflicting file access.

These 12 cases show source lines, diagnostic locations and suggested fixes
using terminal output. Colors and wiki footers are disabled for exact snapshots.

## Redirection order, grouping and file conflicts

### SC2069

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2069.sh
@STDOUT
In fixtures/redirections/SC2069.sh line 2:
printf x 2>&1 > cow
         ^--^ SC2069 (warning): To redirect stdout+stderr, 2>&1 must be last (or use '{ cmd > file; } 2>&1' to clarify).

In fixtures/redirections/SC2069.sh line 3:
printf x | cat 2>&1 > /dev/null
               ^--^ SC2069 (warning): To redirect stdout+stderr, 2>&1 must be last (or use '{ cmd > file; } 2>&1' to clarify).
@STDERR (empty)
[1]
```

### SC2129-SC2143

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2129-SC2143.sh
@STDOUT
In fixtures/redirections/SC2129-SC2143.sh line 2:
foo >> file; bar >> file; baz >> file;
^---------^ SC2129 (style): Consider using { cmd1; cmd2; } >> file instead of individual redirects.

In fixtures/redirections/SC2129-SC2143.sh line 3:
[[ $(foo | grep bar) ]]
   ^----------------^ SC2143 (style): Use grep -q instead of comparing output with [ -n .. ].

In fixtures/redirections/SC2129-SC2143.sh line 4:
[ -z "$(foo | grep bar)" ]
  ^-- SC2143 (style): Use ! grep -q instead of comparing output with [ -z .. ].
@STDERR (empty)
[1]
```

### SC2257

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2257.sh
@STDOUT
In fixtures/redirections/SC2257.sh line 2:
printf %s x > $((i++))
                  ^-- SC2257 (warning): Arithmetic modifications in command redirections may be discarded. Do them separately.

In fixtures/redirections/SC2257.sh line 3:
printf %s x 2> $((i+=1))
                   ^-- SC2257 (warning): Arithmetic modifications in command redirections may be discarded. Do them separately.
@STDERR (empty)
[1]
```

### SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261.sh
@STDOUT
In fixtures/redirections/SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261.sh line 2:
> file
^----^ SC2188 (warning): This redirection doesn't have a command. Move to its command (or use 'true' as no-op).

In fixtures/redirections/SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261.sh line 3:
> file | grep foo
^-- SC2260 (error): This redirection overrides the output pipe. Use 'tee' to output to both.
^----^ SC2189 (error): You can't have | between this redirection and the command it should apply to.

In fixtures/redirections/SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261.sh line 4:
grep foo | > bar
           ^---^ SC2189 (error): You can't have | between this redirection and the command it should apply to.

In fixtures/redirections/SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261.sh line 5:
foo | echo bar
      ^------^ SC2216 (warning): Piping to 'echo', a command that doesn't read stdin. Did you want 'cat' instead?

In fixtures/redirections/SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261.sh line 6:
foo | basename < file.txt
      ^-----------------^ SC2216 (warning): Piping to 'basename', a command that doesn't read stdin. Wrong command or missing xargs?
      ^-----------------^ SC2217 (warning): Redirecting to 'basename', a command that doesn't read stdin. Bad quoting, wrong command or missing xargs?
               ^-- SC2259 (error): This redirection overrides piped input. To use both, merge or pass filenames.

In fixtures/redirections/SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261.sh line 7:
ls > foo > bar
   ^-- SC2261 (error): Multiple redirections compete for stdout. Use cat, tee, or pass filenames instead.
         ^-- SC2261 (error): Multiple redirections compete for stdout. Use cat, tee, or pass filenames instead.

In fixtures/redirections/SC2188-SC2189-SC2216-SC2217-SC2259-SC2260-SC2261.sh line 8:
ls > foo 2> bar > baz
   ^-- SC2261 (error): Multiple redirections compete for stdout. Use cat, tee, or pass filenames instead.
                ^-- SC2261 (error): Multiple redirections compete for stdout. Use cat, tee, or pass filenames instead.
@STDERR (empty)
[1]
```

### SC2094

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2094.sh
@STDOUT
In fixtures/redirections/SC2094.sh line 2:
cat foo > foo
    ^-^ SC2094 (info): Make sure not to read and write the same file in the same pipeline.
          ^-^ SC2094 (info): Make sure not to read and write the same file in the same pipeline.

In fixtures/redirections/SC2094.sh line 3:
cat lol | sed -e 's/a/b/g' > lol
    ^-^ SC2094 (info): Make sure not to read and write the same file in the same pipeline.
                             ^-^ SC2094 (info): Make sure not to read and write the same file in the same pipeline.
@STDERR (empty)
[1]
```

## Shared stdin in read loops

### SC2095-direct

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2095-direct.sh
@STDOUT
In fixtures/redirections/SC2095-direct.sh line 2:
while read -r foo; do ssh "$foo" uptime; done
^-- SC2095 (info): ssh may swallow stdin, preventing this loop from working properly.
                      ^---------------^ SC2095 (warning): Use ssh -n to prevent ssh from swallowing stdin.

Did you mean:
while read -r foo; do ssh -n "$foo" uptime; done

In fixtures/redirections/SC2095-direct.sh line 3:
while read -r foo; do ffmpeg -i foo.mkv bar.mkv -an; done
^-- SC2095 (info): ffmpeg may swallow stdin, preventing this loop from working properly.
                      ^---------------------------^ SC2095 (warning): Use ffmpeg -nostdin to prevent ffmpeg from swallowing stdin.

Did you mean:
while read -r foo; do ffmpeg -nostdin -i foo.mkv bar.mkv -an; done

In fixtures/redirections/SC2095-direct.sh line 4:
while read -r foo; do mplayer foo.ogv > file; done
^-- SC2095 (info): mplayer may swallow stdin, preventing this loop from working properly.
                      ^--------------------^ SC2095 (warning): Use mplayer -noconsolecontrols to prevent mplayer from swallowing stdin.

Did you mean:
while read -r foo; do mplayer -noconsolecontrols foo.ogv > file; done

In fixtures/redirections/SC2095-direct.sh line 5:
while read -r foo; do HandBrakeCLI foo.mkv -o out.mkv; done
^-- SC2095 (info): HandBrakeCLI may swallow stdin, preventing this loop from working properly.
                      ^-----------------------------^ SC2095 (warning): Use HandBrakeCLI < /dev/null to prevent HandBrakeCLI from swallowing stdin.

Did you mean:
while read -r foo; do HandBrakeCLI foo.mkv -o out.mkv < /dev/null; done
@STDERR (empty)
[1]
```

### SC2095-nested-assignment

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2095-nested-assignment.sh
@STDOUT
In fixtures/redirections/SC2095-nested-assignment.sh line 3:
while read -r foo; do x=$(ssh host cmd); done
^-- SC2095 (info): ssh may swallow stdin, preventing this loop from working properly.
                          ^----------^ SC2095 (warning): Use ssh -n to prevent ssh from swallowing stdin.

Did you mean:
while read -r foo; do x=$(ssh -n host cmd); done
@STDERR (empty)
[1]
```

### SC2095-nested-if-and-background

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2095-nested-if-and-background.sh
@STDOUT
In fixtures/redirections/SC2095-nested-if-and-background.sh line 2:
while read -r foo; do if true; then ssh "$foo" uptime; fi; done
^-- SC2095 (info): ssh may swallow stdin, preventing this loop from working properly.
                                    ^---------------^ SC2095 (warning): Use ssh -n to prevent ssh from swallowing stdin.

Did you mean:
while read -r foo; do if true; then ssh -n "$foo" uptime; fi; done

In fixtures/redirections/SC2095-nested-if-and-background.sh line 3:
while read -r foo; do ssh "$foo" uptime & done
^-- SC2095 (info): ssh may swallow stdin, preventing this loop from working properly.
                      ^---------------^ SC2095 (warning): Use ssh -n to prevent ssh from swallowing stdin.

Did you mean:
while read -r foo; do ssh -n "$foo" uptime & done
@STDERR (empty)
[1]
```

## Pipeline consumers and here-documents

### SC2216-nested-pipeline-in-command-substitution

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2216-nested-pipeline-in-command-substitution.sh
@STDOUT
In fixtures/redirections/SC2216-nested-pipeline-in-command-substitution.sh line 2:
echo $(foo | echo bar)
     ^---------------^ SC2046 (warning): Quote this to prevent word splitting.
     ^---------------^ SC2005 (style): Useless echo? Instead of 'echo $(cmd)', just use 'cmd'.
             ^------^ SC2216 (warning): Piping to 'echo', a command that doesn't read stdin. Did you want 'cat' instead?
@STDERR (empty)
[1]
```

### SC2216-here-doc-nested-consumer

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2216-here-doc-nested-consumer.sh
@STDOUT (empty)
@STDERR (empty)
```

### SC2259-quoted-here-doc

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2259-quoted-here-doc.sh
@STDOUT
In fixtures/redirections/SC2259-quoted-here-doc.sh line 2:
echo World | cat << 'EOF'
                    ^---^ SC2259 (error): This redirection overrides piped input. To use both, merge or pass filenames.
@STDERR (empty)
[1]
```

### SC2216-command-exceptions-and-fd-dup

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/redirections/SC2216-command-exceptions-and-fd-dup.sh
@STDOUT
In fixtures/redirections/SC2216-command-exceptions-and-fd-dup.sh line 5:
yes | rm --interactive *
                       ^-- SC2035 (info): Use ./*glob* or -- *glob* so names with dashes won't become options.
@STDERR (empty)
[1]
```
