# Condition expressions

Test syntax, logical operators, comparisons, operand expansion and optional condition checks.

These 14 cases show source lines, diagnostic locations and suggested fixes
using terminal output. Colors and wiki footers are disabled for exact snapshots.

## Test syntax and logical operators

### SC2107-SC2108-SC2109-SC2110

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2107-SC2108-SC2109-SC2110.sh
@STDOUT
In fixtures/conditions/SC2107-SC2108-SC2109-SC2110.sh line 2:
[ "$1" && "$2" ]
       ^-- SC2107 (error): Instead of [ a && b ], use [ a ] && [ b ].

In fixtures/conditions/SC2107-SC2108-SC2109-SC2110.sh line 3:
[[ "$1" -a "$2" ]]
        ^-- SC2108 (error): In [[..]], use && instead of -a.

In fixtures/conditions/SC2107-SC2108-SC2109-SC2110.sh line 4:
[ "$1" || "$2" ]
       ^-- SC2109 (error): Instead of [ a || b ], use [ a ] || [ b ].

In fixtures/conditions/SC2107-SC2108-SC2109-SC2110.sh line 5:
[[ "$1" -o "$2" ]]
        ^-- SC2110 (error): In [[..]], use || instead of -o.
@STDERR (empty)
[1]
```

### SC2265-SC2266

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2265-SC2266.sh
@STDOUT
In fixtures/conditions/SC2265-SC2266.sh line 4:
[ "$a" ] & [ "$a" ]
         ^-- SC2265 (error): Use && for logical AND. Single & will background and return true.

Did you mean:
[ "$a" ] && [ "$a" ]

In fixtures/conditions/SC2265-SC2266.sh line 5:
test -e foo & [ "$a" ]
            ^-- SC2265 (error): Use && for logical AND. Single & will background and return true.

Did you mean:
test -e foo && [ "$a" ]

In fixtures/conditions/SC2265-SC2266.sh line 6:
[ "$a" ] | [ "$a" ]
         ^-- SC2266 (warning): Use || for logical OR. Single | will pipe.

Did you mean:
[ "$a" ] || [ "$a" ]
@STDERR (empty)
[1]
```

### SC1033

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC1033.sh
@STDOUT
In fixtures/conditions/SC1033.sh line 3:
[[ "$foo" ]
          ^-- SC1033 (error): Test expression was opened with double [[ but closed with single ]. Make sure they match.
@STDERR (empty)
[1]
```

### SC1034

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC1034.sh
@STDOUT
In fixtures/conditions/SC1034.sh line 3:
[ "$foo" ]]
^-- SC1034 (error): Test expression was opened with single [ but closed with double ]]. Make sure they match.
@STDERR (empty)
[1]
```

## Operands, comparisons and glob patterns

### SC2070-SC2074-SC2075-SC2077

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2070-SC2074-SC2075-SC2077.sh
@STDOUT
In fixtures/conditions/SC2070-SC2074-SC2075-SC2077.sh line 3:
[ -n $foo ]
     ^--^ SC2070 (error): -n doesn't work with unquoted arguments. Quote or use [[ ]].

In fixtures/conditions/SC2070-SC2074-SC2075-SC2077.sh line 4:
[ $foo=3 ]
      ^-- SC2077 (error): You need spaces around the comparison operator.

In fixtures/conditions/SC2070-SC2074-SC2075-SC2077.sh line 6:
[ "$a" =~ foo ]
       ^-- SC2074 (error): Can't use =~ in [ ]. Use [[..]] instead.

In fixtures/conditions/SC2070-SC2074-SC2075-SC2077.sh line 8:
[[ $a \< $b ]]
      ^-- SC2075 (error): Escaping \< is required in [..], but invalid in [[..]]
@STDERR (empty)
[1]
```

### SC2144-SC2198-SC2208-SC2255-bash

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2144-SC2198-SC2208-SC2255-bash.sh
@STDOUT
In fixtures/conditions/SC2144-SC2198-SC2208-SC2255-bash.sh line 3:
[ -f *.mp3 ]
     ^---^ SC2144 (error): -f doesn't work with globs. Use a for loop.

In fixtures/conditions/SC2144-SC2198-SC2208-SC2255-bash.sh line 4:
[[ -n ${arr[@]} ]]
      ^-------^ SC2199 (error): Arrays implicitly concatenate in [[ ]]. Use a loop (or explicit * instead of @).

In fixtures/conditions/SC2144-SC2198-SC2208-SC2255-bash.sh line 5:
[ -n ${arr[@]} ]
     ^-------^ SC2198 (warning): Arrays don't work as operands in [ ]. Use a loop (or concatenate with * instead of @).

In fixtures/conditions/SC2144-SC2198-SC2208-SC2255-bash.sh line 6:
[ -n {a,b} ]
     ^---^ SC2070 (error): -n doesn't work with unquoted arguments. Quote or use [[ ]].
     ^---^ SC2200 (warning): Brace expansions don't work as operands in [ ]. Use a loop.

In fixtures/conditions/SC2144-SC2198-SC2208-SC2255-bash.sh line 7:
[[ -n {a,b} ]]
      ^---^ SC2201 (error): Brace expansion doesn't happen in [[ ]]. Use a loop.

In fixtures/conditions/SC2144-SC2198-SC2208-SC2255-bash.sh line 8:
[ *.mp3 ]
  ^---^ SC2202 (warning): Globs don't work as operands in [ ]. Use a loop.

In fixtures/conditions/SC2144-SC2198-SC2208-SC2255-bash.sh line 9:
[[ *.mp3 ]]
   ^---^ SC2203 (error): Globs are ignored in [[ ]] except right of =/!=. Use a loop.

In fixtures/conditions/SC2144-SC2198-SC2208-SC2255-bash.sh line 10:
[ 6 -eq 2*3 ]
        ^-^ SC2255 (error): [ ] does not apply arithmetic evaluation. Evaluate with $((..)) for numbers, or use string comparator for strings.

In fixtures/conditions/SC2144-SC2198-SC2208-SC2255-bash.sh line 11:
[ -v *.mp3 ]
     ^---^ SC2208 (error): Use [[ ]] or quote arguments to -v to avoid glob expansion.
@STDERR (empty)
[1]
```

### SC2245-ksh

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2245-ksh.sh
@STDOUT
In fixtures/conditions/SC2245-ksh.sh line 2:
[ -f *.mp3 ]
     ^---^ SC2245 (warning): -f only applies to the first expansion of this glob. Use a loop to check any/all.
@STDERR (empty)
[1]
```

### SC2050

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2050.sh
@STDOUT
In fixtures/conditions/SC2050.sh line 2:
[[ x == y ]]
     ^-- SC2050 (warning): This expression is constant. Did you forget the $ on a variable?
@STDERR (empty)
[1]
```

### SC2268

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2268.sh
@STDOUT
In fixtures/conditions/SC2268.sh line 3:
[ x"$foo" = x'lol' ]
  ^-----^ SC2268 (style): Avoid x-prefix in comparisons as it no longer serves a purpose.

Did you mean:
[ "$foo" = 'lol' ]

In fixtures/conditions/SC2268.sh line 4:
test X$foo = Xbar
     ^---^ SC2268 (style): Avoid x-prefix in comparisons as it no longer serves a purpose.

Did you mean:
test $foo = bar
@STDERR (empty)
[1]
```

## Constant and optional conditions

### SC2158-SC2159-SC2160-SC2161

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2158-SC2159-SC2160-SC2161.sh
@STDOUT
In fixtures/conditions/SC2158-SC2159-SC2160-SC2161.sh line 2:
[ false ]
  ^---^ SC2158 (error): [ false ] is true. Remove the brackets.

In fixtures/conditions/SC2158-SC2159-SC2160-SC2161.sh line 3:
[ 0 ]
  ^-- SC2159 (error): [ 0 ] is true. Use 'false' instead.

In fixtures/conditions/SC2158-SC2159-SC2160-SC2161.sh line 4:
[ true ]
  ^--^ SC2160 (style): Instead of '[ true ]', just use 'true'.

In fixtures/conditions/SC2158-SC2159-SC2160-SC2161.sh line 5:
[ 1 ]
  ^-- SC2161 (style): Instead of '[ 1 ]', use 'true'.
@STDERR (empty)
[1]
```

### SC2237-SC2243-SC2335

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2237-SC2243-SC2335.sh
@STDOUT
In fixtures/conditions/SC2237-SC2243-SC2335.sh line 4:
! [ -n "$var" ]
^-- SC2237 (style): Use [ -z .. ] instead of ! [ -n .. ].

In fixtures/conditions/SC2237-SC2243-SC2335.sh line 5:
[[ $(cmd) ]]
   ^----^ SC2243 (style): Prefer explicit -n to check for output (or run command without [/[[ to check for success).

Did you mean:
[[ -n $(cmd) ]]

In fixtures/conditions/SC2237-SC2243-SC2335.sh line 6:
! [[ $var -gt 3 ]]
^-- SC2335 (style): Use [[ a -le b ]] instead of ! [[ a -gt b ]].
@STDERR (empty)
[1]
```

## Unary file tests

### SC2332

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2332.sh
@STDOUT
In fixtures/conditions/SC2332.sh line 3:
[ ! -a file ]
  ^-- SC2332 (error): [ ! -a file ] is always true because -a becomes logical AND. Use -e instead.
@STDERR (empty)
[1]
```

### SC2331

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2331.sh
@STDOUT
In fixtures/conditions/SC2331.sh line 2:
[ -a file ]
  ^-- SC2331 (style): For file existence, prefer standard -e over legacy -a.

Did you mean:
[ -e file ]
@STDERR (empty)
[1]
```

### SC2331 (repeat regression)

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/conditions/SC2331.sh
@STDOUT
In fixtures/conditions/SC2331.sh line 2:
[ -a file ]
  ^-- SC2331 (style): For file existence, prefer standard -e over legacy -a.

Did you mean:
[ -e file ]
@STDERR (empty)
[1]
```
