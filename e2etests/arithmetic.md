# Arithmetic expressions

Integer arithmetic, expansion syntax, evaluation order and arithmetic style.

These 5 cases show source lines, diagnostic locations and suggested fixes
using terminal output. Colors and wiki footers are disabled for exact snapshots.

## Arithmetic expansion and evaluation

### SC2004-SC2017

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/arithmetic/SC2004-SC2017.sh
@STDOUT
In fixtures/arithmetic/SC2004-SC2017.sh line 4:
echo $(( $foo + 1 ))
         ^--^ SC2004 (style): $/${} is unnecessary on arithmetic variables.

In fixtures/arithmetic/SC2004-SC2017.sh line 5:
echo $(( 3 / 2 * 100 ))
           ^-- SC2017 (info): Increase precision by replacing a/b*c with a*c/b.
@STDERR (empty)
[1]
```

### SC2079

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/arithmetic/SC2079.sh
@STDOUT
In fixtures/arithmetic/SC2079.sh line 2:
((3.14*1))
  ^--^ SC2079 (error): (( )) doesn't support decimals. Use bc or awk.
@STDERR (empty)
[1]
```

### SC2007

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/arithmetic/SC2007.sh
@STDOUT
In fixtures/arithmetic/SC2007.sh line 2:
echo $[1+2]
     ^----^ SC2007 (style): Use $((..)) instead of deprecated $[..]
@STDERR (empty)
[1]
```

### SC2084

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/arithmetic/SC2084.sh
@STDOUT
In fixtures/arithmetic/SC2084.sh line 2:
$((i++))
^------^ SC2084 (error): Remove '$' or use '_=$((expr))' to avoid executing output.
@STDERR (empty)
[1]
```

## Arithmetic style and assignments

### SC2321-SC2324

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --norc --color=never -W0 -ftty fixtures/arithmetic/SC2321-SC2324.sh
@STDOUT
In fixtures/arithmetic/SC2321-SC2324.sh line 3:
a[$((1+1))]=n
  ^------^ SC2321 (style): Array indices are already arithmetic contexts. Prefer removing the $(( and )).

Did you mean:
a[1+1]=n

In fixtures/arithmetic/SC2321-SC2324.sh line 4:
echo $(( ((1+1)) ))
         ^-----^ SC2323 (style): $(( (x) )) is the same as $(( x )). Prefer not wrapping in additional parentheses.
          ^---^ SC2322 (style): In arithmetic contexts, ((x)) is the same as (x). Prefer only one layer of parentheses.

Did you mean:
echo $(( 1+1 ))

In fixtures/arithmetic/SC2321-SC2324.sh line 5:
echo $(( (x) ))
         ^-^ SC2323 (style): $(( (x) )) is the same as $(( x )). Prefer not wrapping in additional parentheses.

Did you mean:
echo $(( x ))

In fixtures/arithmetic/SC2321-SC2324.sh line 7:
x+=1
^-- SC2324 (warning): var+=1 will append, not increment. Use (( var += 1 )), typeset -i var, or quote number to silence.

In fixtures/arithmetic/SC2321-SC2324.sh line 8:
y+=n
^-- SC2324 (warning): var+=1 will append, not increment. Use (( var += 1 )), typeset -i var, or quote number to silence.
@STDERR (empty)
[1]
```
