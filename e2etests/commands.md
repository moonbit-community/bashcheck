# Command usage

Formatting and text tools, builtin arguments, command substitution and find pipelines.

These 13 cases show source lines, diagnostic locations and suggested fixes
using terminal output. Colors and wiki footers are disabled for exact snapshots.

## Formatting, text tools and builtin usage

### SC2059-SC2060-SC2063

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2059-SC2060-SC2063.sh
@STDOUT
In fixtures/commands/SC2059-SC2060-SC2063.sh line 3:
printf "$fmt" foo
       ^----^ SC2059 (info): Don't use variables in the printf format string. Use printf '..%s..' "$foo".

In fixtures/commands/SC2059-SC2060-SC2063.sh line 4:
tr [a-f] [A-F]
   ^---^ SC2060 (warning): Quote parameters to tr to prevent glob expansion.
         ^---^ SC2060 (warning): Quote parameters to tr to prevent glob expansion.

In fixtures/commands/SC2059-SC2060-SC2063.sh line 5:
grep '*foo*' file
     ^-----^ SC2063 (warning): Grep uses regex, but this looks like a glob.
@STDERR (empty)
[1]
```

### SC2020-SC2021-SC2227

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2020-SC2021-SC2227.sh
@STDOUT
In fixtures/commands/SC2020-SC2021-SC2227.sh line 2:
tr foo bar
   ^-^ SC2020 (info): tr replaces sets of chars, not words (mentioned due to duplicates).

In fixtures/commands/SC2020-SC2021-SC2227.sh line 3:
tr '[a-z]' '[A-Z]'
   ^-----^ SC2021 (info): Don't use [] around classes in tr, it replaces literal square brackets.
           ^-----^ SC2021 (info): Don't use [] around classes in tr, it replaces literal square brackets.

In fixtures/commands/SC2020-SC2021-SC2227.sh line 4:
find . -exec echo {} > file \;
                     ^----^ SC2227 (warning): Redirection applies to the find command itself. Rewrite to work per action (or move to end).
@STDERR (empty)
[1]
```

### SC2305-SC2307-SC2308

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2305-SC2307-SC2308.sh
@STDOUT
In fixtures/commands/SC2305-SC2307-SC2308.sh line 3:
expr match foo bar
     ^---^ SC2308 (info): 'expr match' has unspecified results. Prefer 'expr str : regex'.

In fixtures/commands/SC2305-SC2307-SC2308.sh line 4:
expr foo : fo*
           ^-^ SC2305 (warning): Quote regex argument to expr to avoid it expanding as a glob.

In fixtures/commands/SC2305-SC2307-SC2308.sh line 5:
expr 5 -3
^-------^ SC2307 (warning): 'expr' expects 3+ arguments, but sees 2. Make sure each operator/operand is a separate argument, and escape <>&|.
@STDERR (empty)
[1]
```

### SC2306

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2306.sh
@STDOUT
In fixtures/commands/SC2306.sh line 3:
expr 1 + 2 *
           ^-- SC2306 (warning): Escape glob characters in arguments to expr to avoid pathname expansion.

In fixtures/commands/SC2306.sh line 4:
expr 1 + 2 *.txt
           ^---^ SC2306 (warning): Escape glob characters in arguments to expr to avoid pathname expansion.
@STDERR (empty)
[1]
```

### SC2001

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2001.sh
@STDOUT
In fixtures/commands/SC2001.sh line 3:
FOO=$(echo "$cow" | sed 's/foo/bar/g')
      ^-----------------------------^ SC2001 (style): See if you can use ${variable//search/replace} instead.
@STDERR (empty)
[1]
```

### SC2028

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2028.sh
@STDOUT
In fixtures/commands/SC2028.sh line 2:
echo "\\n"
     ^---^ SC2028 (info): echo may not expand escape sequences. Use printf.
@STDERR (empty)
[1]
```

## Command names and command substitution

### SC2289

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2289.sh
@STDOUT
In fixtures/commands/SC2289.sh line 2:
$'foo\tbar'
^---------^ SC2289 (error): This is interpreted as a command name containing a tab. Double check syntax.
@STDERR (empty)
[1]
```

### SC2256

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2256.sh
@STDOUT
In fixtures/commands/SC2256.sh line 3:
foo_bar2=val; $"foo_bar2"
              ^---------^ SC2256 (warning): This translated string is the name of a variable. Flip leading $ and " if this should be a quoted substitution.

Did you mean:
foo_bar2=val; "$foo_bar2"
@STDERR (empty)
[1]
```

### SC2091

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2091.sh
@STDOUT
In fixtures/commands/SC2091.sh line 2:
$(foo)
^----^ SC2091 (warning): Remove surrounding $() to avoid executing output (or use eval if intentional).
@STDERR (empty)
[1]
```

### SC2092

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2092.sh
@STDOUT
In fixtures/commands/SC2092.sh line 3:
`foo`
^---^ SC2092 (warning): Remove backticks to avoid executing output (or use eval if intentional).
@STDERR (empty)
[1]
```

### SC2116

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2116.sh
@STDOUT
In fixtures/commands/SC2116.sh line 3:
cmd $(echo foo)
    ^---------^ SC2116 (style): Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'.
@STDERR (empty)
[1]
```

## Pipeline commands and find execution

### SC2009-SC2013-SC2038-SC2126

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2009-SC2013-SC2038-SC2126.sh
@STDOUT
In fixtures/commands/SC2009-SC2013-SC2038-SC2126.sh line 2:
ps aux | grep foo
^----^ SC2009 (info): Consider using pgrep instead of grepping ps output.

In fixtures/commands/SC2009-SC2013-SC2038-SC2126.sh line 3:
ls | grep foo
^-- SC2010 (warning): Don't use ls | grep. Use a glob or a for loop with a condition to allow non-alphanumeric filenames.

In fixtures/commands/SC2009-SC2013-SC2038-SC2126.sh line 4:
ls | xargs rm
^-- SC2011 (warning): Use 'find .. -print0 | xargs -0 ..' or 'find .. -exec .. +' to allow non-alphanumeric filenames.

In fixtures/commands/SC2009-SC2013-SC2038-SC2126.sh line 5:
ls | sort
^-- SC2012 (info): Use find instead of ls to better handle non-alphanumeric filenames.

In fixtures/commands/SC2009-SC2013-SC2038-SC2126.sh line 6:
for f in $(cat foo); do printf '%s\n' "$f"; done
         ^--------^ SC2013 (info): To read lines rather than words, pipe/redirect to a 'while read' loop.

In fixtures/commands/SC2009-SC2013-SC2038-SC2126.sh line 7:
find . | xargs rm
^----^ SC2038 (warning): Use 'find .. -print0 | xargs -0 ..' or 'find .. -exec .. +' to allow non-alphanumeric filenames.

In fixtures/commands/SC2009-SC2013-SC2038-SC2126.sh line 8:
grep foo file | wc -l
^-----------^ SC2126 (style): Consider using 'grep -c' instead of 'grep|wc -l'.
@STDERR (empty)
[1]
```

### SC2014-SC2067

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/commands/SC2014-SC2067.sh
@STDOUT
In fixtures/commands/SC2014-SC2067.sh line 2:
find . -exec echo $(date) \;
                  ^-----^ SC2046 (warning): Quote this to prevent word splitting.
                  ^-----^ SC2014 (info): This will expand once before find runs, not per file found.

In fixtures/commands/SC2014-SC2067.sh line 3:
find . -name '*.php' -exec rm {};
                              ^-- SC2067 (error): Missing ';' or + terminating -exec. You can't use |/||/&&, and ';' has to be a separate, quoted argument.
@STDERR (empty)
[1]
```
