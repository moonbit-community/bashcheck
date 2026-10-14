# Variables, assignments and scope

Variable references, array assignments, environment variables and subshell scope.

These 12 cases show source lines, diagnostic locations and suggested fixes
using terminal output. Colors and wiki footers are disabled for exact snapshots.

## Assignments and variable references

### SC2272-SC2276

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2272-SC2276.sh
@STDOUT
In fixtures/variables/SC2272-SC2276.sh line 3:
$var==42
^------^ SC2272 (error): Command name contains ==. For comparison, use [ "$var" = value ].

In fixtures/variables/SC2272-SC2276.sh line 4:
var${x}/=value
^------------^ SC2276 (error): This is interpreted as a command name containing '='. Bad assignment or comparison?
@STDERR (empty)
[1]
```

### SC2034

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2034.sh
@STDOUT
In fixtures/variables/SC2034.sh line 2:
foo=bar
^-^ SC2034 (warning): foo appears unused. Verify use (or export if used externally).
@STDERR (empty)
[1]
```

### SC2153

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2153.sh
@STDOUT
In fixtures/variables/SC2153.sh line 4:
echo $HOMR_DIR
     ^-------^ SC2153 (info): Possible misspelling: HOMR_DIR may not be assigned. Did you mean HOME_DIR?
@STDERR (empty)
[1]
```

### SC2283-SC2285

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2283-SC2285.sh
@STDOUT
In fixtures/variables/SC2283-SC2285.sh line 3:
foo = $bar
    ^-- SC2283 (error): Remove spaces around = to assign (or use [ ] to compare, or quote '=' if literal).

In fixtures/variables/SC2283-SC2285.sh line 4:
foo == $bar
^---------^ SC2284 (error): Use [ x = y ] to compare values (or quote '==' if literal).

In fixtures/variables/SC2283-SC2285.sh line 5:
var += $(foo)
^-----------^ SC2285 (error): Remove spaces around += to assign (or quote '+=' if literal).

In fixtures/variables/SC2283-SC2285.sh line 6:
var +=$(foo)
^----------^ SC2285 (error): Remove spaces around += to assign (or quote '+=' if literal).
@STDERR (empty)
[1]
```

### SC2270-SC2282

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2270-SC2282.sh
@STDOUT
In fixtures/variables/SC2270-SC2282.sh line 3:
0='foo'
^-- SC2277 (error): Use BASH_ARGV0 to assign to $0 in bash (or use [ ] to compare).

Did you mean:
BASH_ARGV0='foo'

In fixtures/variables/SC2270-SC2282.sh line 4:
1='foo'
^-- SC2270 (error): To assign positional parameters, use 'set -- first second ..' (or use [ ] to compare).

In fixtures/variables/SC2270-SC2282.sh line 5:
$var=foo
^--^ SC2281 (error): Don't use $ on the left side of assignments.

Did you mean:
var=foo

In fixtures/variables/SC2270-SC2282.sh line 6:
${var}=foo
^----^ SC2281 (error): Don't use ${} on the left side of assignments.

Did you mean:
var=foo

In fixtures/variables/SC2270-SC2282.sh line 7:
var${x}=value
^-----------^ SC2271 (error): For indirection, use arrays, declare "var$n=value", or (for sh) read/eval.

In fixtures/variables/SC2270-SC2282.sh line 8:
"=======" (escaped)
^-----^ SC2273 (error): Sequence of ===s found. Merge conflict or intended as a commented border?

In fixtures/variables/SC2270-SC2282.sh line 9:
"======= Here =======" (escaped)
^------------------^ SC2274 (error): Command name starts with ===. Intended as a commented border?

In fixtures/variables/SC2270-SC2282.sh line 11:
=42
^-^ SC2275 (error): Command name starts with =. Bad line break?

In fixtures/variables/SC2270-SC2282.sh line 12:
411toppm=true
^-----------^ SC2282 (error): Variable names can't start with numbers, so this is interpreted as a command.
@STDERR (empty)
[1]
```

### SC2209

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2209.sh
@STDOUT
In fixtures/variables/SC2209.sh line 3:
out=cat foo
^---------^ SC2209 (warning): Use var=$(command) to assign output (or quote to assign string).

In fixtures/variables/SC2209.sh line 4:
here=pwd
^--^ SC2209 (warning): Use var=$(command) to assign output (or quote to assign string).
@STDERR (empty)
[1]
```

## Array assignments and environment variables

### SC2123

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2123.sh
@STDOUT
In fixtures/variables/SC2123.sh line 3:
PATH="$var/$foo"
^--^ SC2123 (warning): PATH is the shell search path. Use another name.

In fixtures/variables/SC2123.sh line 4:
PATH="mydir"
^--^ SC2123 (warning): PATH is the shell search path. Use another name.

In fixtures/variables/SC2123.sh line 5:
PATH=/cow/foo
^--^ SC2123 (warning): PATH is the shell search path. Use another name.
@STDERR (empty)
[1]
```

### SC2054

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2054.sh
@STDOUT
In fixtures/variables/SC2054.sh line 3:
a=(1, 2)
  ^----^ SC2054 (warning): Use spaces, not commas, to separate array elements.

In fixtures/variables/SC2054.sh line 4:
a+=(1,2,3)
   ^-----^ SC2054 (warning): Use spaces, not commas, to separate array elements.

In fixtures/variables/SC2054.sh line 7:
a=([a]=b,[c]=d,[e]=f)
  ^-----------------^ SC2054 (warning): Use spaces, not commas, to separate array elements.
@STDERR (empty)
[1]
```

### SC2190-SC2192

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2190-SC2192.sh
@STDOUT
In fixtures/variables/SC2190-SC2192.sh line 3:
declare -A foo; foo=(bar)
                     ^-^ SC2190 (warning): Elements in associative arrays need index, e.g. array=( [index]=value ) .

In fixtures/variables/SC2190-SC2192.sh line 4:
arr=( [foo]= bar )
            ^-- SC2192 (warning): This array element has no value. Remove spaces after = or use "" for empty string.

In fixtures/variables/SC2190-SC2192.sh line 5:
declare -A map; map=( var=value )
                      ^-------^ SC2190 (warning): Elements in associative arrays need index, e.g. array=( [index]=value ) .

In fixtures/variables/SC2190-SC2192.sh line 6:
arr=( 1=value )
      ^-----^ SC2191 (warning): The = here is literal. To assign by index, use ( [index]=value ) with no spaces. To keep as literal, quote it.

Did you mean:
arr=( "1=value" )

In fixtures/variables/SC2190-SC2192.sh line 7:
arr=( $a=value )
        ^----^ SC2191 (warning): The = here is literal. To assign by index, use ( [index]=value ) with no spaces. To keep as literal, quote it.

Did you mean:
arr=( $a"=value" )

In fixtures/variables/SC2190-SC2192.sh line 8:
arr=( $((1+1))=value )
              ^----^ SC2191 (warning): The = here is literal. To assign by index, use ( [index]=value ) with no spaces. To keep as literal, quote it.

Did you mean:
arr=( $((1+1))"=value" )

In fixtures/variables/SC2190-SC2192.sh line 9:
arr=( [foo] = bar )
            ^-- SC2191 (warning): The = here is literal. To assign by index, use ( [index]=value ) with no spaces. To keep as literal, quote it.

Did you mean:
arr=( [foo] "=" bar )
@STDERR (empty)
[1]
```

## Loop variables and subshell scope

### SC2165-SC2167

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2165-SC2167.sh
@STDOUT
In fixtures/variables/SC2165-SC2167.sh line 3:
for i in a; do
^-^ SC2167 (warning): This parent loop has its index variable overridden.

In fixtures/variables/SC2165-SC2167.sh line 4:
  for ((i = 0; i < 3; i++)); do
  ^-^ SC2165 (warning): This nested loop overrides the index variable of its parent.
@STDERR (empty)
[1]
```

### SC2030-SC2031-pipeline

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2030-SC2031-pipeline.sh
@STDOUT
In fixtures/variables/SC2030-SC2031-pipeline.sh line 2:
cat foo | while read -r bar; do a=$bar; done
                                ^-- SC2030 (info): Modification of a is local (to subshell caused by pipeline).

In fixtures/variables/SC2030-SC2031-pipeline.sh line 3:
echo "${a:-}"
      ^----^ SC2031 (info): a was modified in a subshell. That change might be lost.
@STDERR (empty)
[1]
```

### SC2030-SC2031-background

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/variables/SC2030-SC2031-background.sh
@STDOUT
In fixtures/variables/SC2030-SC2031-background.sh line 2:
read -r n & n=foo$n
        ^-- SC2030 (info): Modification of n is local (to subshell caused by backgrounding &).
                 ^-- SC2031 (info): n was modified in a subshell. That change might be lost.
@STDERR (empty)
[1]
```
