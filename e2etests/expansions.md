# Expansions and quoting

Quoting, word splitting, parameter expansion, arrays, braces and glob patterns.

These 18 cases show source lines, diagnostic locations and suggested fixes
using terminal output. Colors and wiki footers are disabled for exact snapshots.

## Quoting and word splitting

### SC2086-mixed-word

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2086-mixed-word.sh
@STDOUT
In fixtures/expansions/SC2086-mixed-word.sh line 3:
echo x$foo
      ^--^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
echo x"$foo"
@STDERR (empty)
[1]
```

### SC2247

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2247.sh
@STDOUT
In fixtures/expansions/SC2247.sh line 2:
$"(foo)"
^------^ SC2247 (warning): Flip leading $ and " if this should be a quoted substitution.
^------^ SC2288 (warning): This is interpreted as a command name ending with ')'. Double check syntax.

Did you mean:
"$(foo)"
@STDERR (empty)
[1]
```

### SC2016

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2016.sh
@STDOUT
In fixtures/expansions/SC2016.sh line 2:
echo '$foo'
     ^----^ SC2016 (info): Expressions don't expand in single quotes, use double quotes for that.
@STDERR (empty)
[1]
```

### SC2086

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2086.sh
@STDOUT
In fixtures/expansions/SC2086.sh line 3:
echo $foo
     ^--^ SC2086 (info): Double quote to prevent globbing and word splitting.

Did you mean:
echo "$foo"
@STDERR (empty)
[1]
```

### SC2088

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2088.sh
@STDOUT
In fixtures/expansions/SC2088.sh line 3:
var="~/out.txt"
     ^-------^ SC2088 (warning): Tilde does not expand in quotes. Use $HOME.
@STDERR (empty)
[1]
```

### SC2140

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2140.sh
@STDOUT
In fixtures/expansions/SC2140.sh line 2:
echo "VALUES ("id")"
               ^-- SC2140 (warning): Word is of the form "A"B"C" (B indicated). Did you mean "ABC" or "A\"B\"C"?
@STDERR (empty)
[1]
```

### SC2026

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2026.sh
@STDOUT
In fixtures/expansions/SC2026.sh line 3:
echo 'foo'bar
"          ^-^ SC2026 (info): This word is outside of quotes. Did you intend to 'nest '\"'single quotes'\"' instead'? " (escaped)
@STDERR (empty)
[1]
```

### SC2027

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2027.sh
@STDOUT
In fixtures/expansions/SC2027.sh line 3:
echo "a"$b"c"
        ^-- SC2027 (warning): The surrounding quotes actually unquote this. Remove or escape them.
@STDERR (empty)
[1]
```

### SC2025

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2025.sh
@STDOUT
In fixtures/expansions/SC2025.sh line 2:
PS1='\\033[1;35m\\$ '
    ^---------------^ SC2025 (info): Make sure all escape sequences are enclosed in \[..\] to prevent line wrapping issues
@STDERR (empty)
[1]
```

### SC2089-SC2090-bash

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2089-SC2090-bash.sh
@STDOUT
In fixtures/expansions/SC2089-SC2090-bash.sh line 3:
param='--foo="bar"'; app $param
      ^-----------^ SC2089 (warning): Quotes/backslashes will be treated literally. Use an array.
                         ^----^ SC2090 (warning): Quotes/backslashes in this variable will not be respected.

In fixtures/expansions/SC2089-SC2090-bash.sh line 4:
other='my\ file'; cmd="rm $other"; $cmd
      ^--------^ SC2089 (warning): Quotes/backslashes will be treated literally. Use an array.
                                   ^--^ SC2090 (warning): Quotes/backslashes in this variable will not be respected.
@STDERR (empty)
[1]
```

### SC2089-SC2090-sh

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2089-SC2090-sh.sh
@STDOUT
In fixtures/expansions/SC2089-SC2090-sh.sh line 3:
param='--foo="bar"'; app $param
      ^-----------^ SC2089 (warning): Quotes/backslashes will be treated literally. Rewrite using set/"$@" or functions.
                         ^----^ SC2090 (warning): Quotes/backslashes in this variable will not be respected.
@STDERR (empty)
[1]
```

## Parameter and array expansions

### SC2082-SC2124-SC2125-SC2223

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2082-SC2124-SC2125-SC2223.sh
@STDOUT
In fixtures/expansions/SC2082-SC2124-SC2125-SC2223.sh line 3:
echo ${foo$n}
     ^------^ SC2082 (error): To expand via indirection, use arrays, ${!name} or (for sh only) eval.

In fixtures/expansions/SC2082-SC2124-SC2125-SC2223.sh line 4:
a="$@"
  ^--^ SC2124 (warning): Assigning an array to a string! Assign as array, or use * instead of @ to concatenate.

In fixtures/expansions/SC2082-SC2124-SC2125-SC2223.sh line 5:
b=*.png
  ^---^ SC2125 (warning): Brace expansions and globs are literal in assignments. Quote it or use an array.

In fixtures/expansions/SC2082-SC2124-SC2125-SC2223.sh line 6:
: ${x=*}
  ^----^ SC2223 (info): This default assignment may cause DoS due to globbing. Quote it.
@STDERR (empty)
[1]
```

### analytics bad parameter substitutions

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/analytics-bad-parameter-substitutions.sh
@STDOUT
In fixtures/expansions/analytics-bad-parameter-substitutions.sh line 3:
echo ${"bar"}
       ^---^ SC2297 (error): Double quotes must be outside ${}: ${"invalid"} vs "${valid}".

In fixtures/expansions/analytics-bad-parameter-substitutions.sh line 4:
echo ${{var}
       ^--^ SC2296 (error): Parameter expansions can't start with {. Double check syntax.

In fixtures/expansions/analytics-bad-parameter-substitutions.sh line 5:
echo ${$(x)//x/y}
       ^--^ SC2300 (error): Parameter expansion can't be applied to command substitutions. Use temporary variables.

In fixtures/expansions/analytics-bad-parameter-substitutions.sh line 6:
echo ${'foo'}
       ^---^ SC2301 (error): Parameter expansion starts with unexpected quotes. Double check syntax.

In fixtures/expansions/analytics-bad-parameter-substitutions.sh line 7:
echo ${${x%.*}##*/}
       ^-----^ SC2299 (error): Parameter expansions can't be nested. Use temporary variables.

In fixtures/expansions/analytics-bad-parameter-substitutions.sh line 8:
echo ${${x}foo!}
       ^--^ SC2298 (error): ${${x}} is invalid. For expansion, use ${x}. For indirection, use arrays, ${!x} or (for sh) eval.
@STDERR (empty)
[1]
```

### SC2145-SC2295

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2145-SC2295.sh
@STDOUT
In fixtures/expansions/SC2145-SC2295.sh line 2:
echo "foo$@"
         ^-- SC2145 (error): Argument mixes string and array. Use * or separate argument.

In fixtures/expansions/SC2145-SC2295.sh line 3:
echo ${var#$x}
     ^-------^ SC2154 (warning): var is referenced but not assigned.
     ^-------^ SC2086 (info): Double quote to prevent globbing and word splitting.
           ^-- SC2295 (info): Expansions inside ${..} need to be quoted separately, otherwise they match as patterns.

Did you mean:
echo "${var#"$x"}"

In fixtures/expansions/SC2145-SC2295.sh line 4:
echo "${name#$y}"
      ^--------^ SC2154 (warning): name is referenced but not assigned.
             ^-- SC2295 (info): Expansions inside ${..} need to be quoted separately, otherwise they match as patterns.

Did you mean:
echo "${name#"$y"}"
@STDERR (empty)
[1]
```

### SC2180

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2180.sh
@STDOUT
In fixtures/expansions/SC2180.sh line 3:
echo ${foo[1][2]}
     ^----------^ SC2180 (warning): Bash does not support multidimensional arrays. Use 1D or associative arrays.
@STDERR (empty)
[1]
```

## Brace expansion and glob patterns

### SC2101-SC2102-SC2171-SC2193

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2101-SC2102-SC2171-SC2193.sh
@STDOUT
In fixtures/expansions/SC2101-SC2102-SC2171-SC2193.sh line 3:
ls *[:digit:].jpg
    ^-------^ SC2101 (warning): Named class needs outer [], e.g. [[:digit:]].

In fixtures/expansions/SC2101-SC2102-SC2171-SC2193.sh line 4:
ls [10-15]
   ^-----^ SC2102 (info): Ranges can only match single chars (mentioned due to duplicates).

In fixtures/expansions/SC2101-SC2102-SC2171-SC2193.sh line 5:
if -z n ]]; then true; fi
        ^-- SC2171 (warning): Found trailing ]] outside test. Add missing [[ or quote if intentional.

In fixtures/expansions/SC2101-SC2102-SC2171-SC2193.sh line 6:
[[ *.png == [a-z] ]]
         ^-- SC2193 (warning): The arguments to this comparison can never be equal. Make sure your syntax is correct.
@STDERR (empty)
[1]
```

### SC2051

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2051.sh
@STDOUT
In fixtures/expansions/SC2051.sh line 3:
echo {1..$n}
     ^-----^ SC2051 (warning): Bash doesn't support variables in brace range expansions.
@STDERR (empty)
[1]
```

### SC2175

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/expansions/SC2175.sh
@STDOUT
In fixtures/expansions/SC2175.sh line 3:
eval echo DSC{0001..$n}.jpg
             ^--------^ SC2175 (style): Quote this invalid brace expansion since it should be passed literally to eval.
@STDERR (empty)
[1]
```
