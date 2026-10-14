# Control flow and exit status

Loops, cases, negation, set -e, traps, recursion and unreachable code.

These 16 cases show source lines, diagnostic locations and suggested fixes
using terminal output. Colors and wiki footers are disabled for exact snapshots.

## Loops, cases and subshell structure

### SC2104-SC2105-SC2106

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2104-SC2105-SC2106.sh
@STDOUT
In fixtures/control-flow/SC2104-SC2105-SC2106.sh line 3:
continue 2
^--------^ SC2105 (error): continue is only valid in loops.

In fixtures/control-flow/SC2104-SC2105-SC2106.sh line 4:
foo() { break; }
        ^---^ SC2104 (error): In functions, use return instead of break.

In fixtures/control-flow/SC2104-SC2105-SC2106.sh line 5:
if true; then continue; fi
              ^------^ SC2105 (error): continue is only valid in loops.

In fixtures/control-flow/SC2104-SC2105-SC2106.sh line 6:
for f in a; do ( break; ); done
                 ^---^ SC2106 (warning): This only exits the subshell caused by the (..) group.

In fixtures/control-flow/SC2104-SC2105-SC2106.sh line 7:
while true; do true | { break; }; done
                        ^---^ SC2106 (warning): This only exits the subshell caused by the pipeline.
@STDERR (empty)
[1]
```

### SC2103

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2103.sh
@STDOUT
In fixtures/control-flow/SC2103.sh line 3:
for f in *; do cd "$f"; git pull; cd ..; done
                                  ^---^ SC2103 (info): Use a ( subshell ) to avoid having to cd back.
@STDERR (empty)
[1]
```

### SC2233-SC2234-SC2235

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2233-SC2234-SC2235.sh
@STDOUT
In fixtures/control-flow/SC2233-SC2234-SC2235.sh line 3:
( [ a ] )
^-------^ SC2234 (style): Remove superfluous (..) around test command to avoid subshell overhead.

In fixtures/control-flow/SC2233-SC2234-SC2235.sh line 4:
if ( [ a ] ); then :; fi
   ^-------^ SC2233 (style): Remove superfluous (..) around condition to avoid subshell overhead.

In fixtures/control-flow/SC2233-SC2234-SC2235.sh line 5:
( [ a ] && [ b ] )
^----------------^ SC2235 (style): Use { ..; } instead of (..) to avoid subshell overhead.
@STDERR (empty)
[1]
```

### SC2258

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2258.sh
@STDOUT
In fixtures/control-flow/SC2258.sh line 3:
for f in foo, bar,; do true; done
         ^--^ SC2258 (warning): The trailing comma is part of the value, not a separator. Delete or quote it.
              ^--^ SC2258 (warning): The trailing comma is part of the value, not a separator. Delete or quote it.

Did you mean:
for f in foo bar; do true; done
@STDERR (empty)
[1]
```

### SC2194-SC2222

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2194-SC2222.sh
@STDOUT
In fixtures/control-flow/SC2194-SC2222.sh line 3:
case foo in bar) true; esac
     ^-^ SC2194 (warning): This word is constant. Did you forget the $ on a variable?

In fixtures/control-flow/SC2194-SC2222.sh line 4:
case foo-$bar in ??|*) true; esac
                 ^-- SC2195 (warning): This pattern will never match the case statement's word. Double check them.

In fixtures/control-flow/SC2194-SC2222.sh line 5:
case $f in cow) true;; bar|cow) false;; esac
           ^-^ SC2221 (warning): This pattern always overrides a later one on line 5.
                           ^-^ SC2222 (warning): This pattern never matches because of a previous pattern on line 5.
@STDERR (empty)
[1]
```

## Exit status and negation

### SC2251

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2251.sh
@STDOUT
In fixtures/control-flow/SC2251.sh line 3:
while true; do ! true; done
               ^-- SC2251 (info): This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked.

Did you mean:
while true; do  true && exit 1; done

In fixtures/control-flow/SC2251.sh line 4:
{ ! true; }
  ^-- SC2251 (info): This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked.

Did you mean:
{  true && exit 1; }

In fixtures/control-flow/SC2251.sh line 5:
! foo | bar
^-- SC2251 (info): This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked.

Did you mean:
 foo | bar && exit 1

In fixtures/control-flow/SC2251.sh line 6:
! true
^-- SC2251 (info): This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked.

Did you mean:
 true && exit 1
@STDERR (empty)
[1]
```

### SC2310

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2310.sh
@STDOUT
In fixtures/control-flow/SC2310.sh line 5:
f && echo ok
^-- SC2310 (info): This function is invoked in an && condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.

In fixtures/control-flow/SC2310.sh line 6:
if f; then :; fi
   ^-- SC2310 (info): This function is invoked in an 'if' condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.

In fixtures/control-flow/SC2310.sh line 7:
while f; do :; done
      ^-- SC2310 (info): This function is invoked in a 'while' condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.

In fixtures/control-flow/SC2310.sh line 8:
! f
  ^-- SC2310 (info): This function is invoked in a ! condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.
@STDERR (empty)
[1]
```

### SC2152-SC2241

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2152-SC2241.sh
@STDOUT
In fixtures/control-flow/SC2152-SC2241.sh line 2:
f(){ return -1; }
            ^-- SC2152 (error): Can only return 0-255. Other data should be written to stdout.

In fixtures/control-flow/SC2152-SC2241.sh line 4:
exit 1 2
     ^-- SC2241 (error): The exit status can only be one integer 0-255. Use stdout for other data.
@STDERR (empty)
[1]
```

### SC2155

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2155.sh
@STDOUT
In fixtures/control-flow/SC2155.sh line 3:
f(){ local x=$(false); }
           ^-- SC2155 (warning): Declare and assign separately to avoid masking return values.
@STDERR (empty)
[1]
```

### SC2181

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2181.sh
@STDOUT
In fixtures/control-flow/SC2181.sh line 3:
[ $? == 0 ]
  ^-- SC2181 (style): Check exit code directly with e.g. 'if mycmd;', not indirectly with $?.
@STDERR (empty)
[1]
```

### SC2325

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2325.sh
@STDOUT
In fixtures/control-flow/SC2325.sh line 2:
! ! true
^-- SC2325 (error): Multiple ! in front of pipelines are a bash/ksh extension. Use only 0 or 1.
@STDERR (empty)
[1]
```

### SC2326

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2326.sh
@STDOUT
In fixtures/control-flow/SC2326.sh line 2:
true | ! true
       ^-- SC2326 (error): ! is not allowed in the middle of pipelines. Use command group as in cmd | { ! cmd; } if necessary.
@STDERR (empty)
[1]
```

## Traps, recursion and unreachable code

### SC2172-SC2173

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2172-SC2173.sh
@STDOUT
In fixtures/control-flow/SC2172-SC2173.sh line 2:
trap foo 16 KILL 9
         ^-- SC2172 (warning): Trapping signals by number is not well defined. Prefer signal names.
            ^--^ SC2173 (error): SIGKILL/SIGSTOP can not be trapped.
                 ^-- SC2173 (error): SIGKILL/SIGSTOP can not be trapped.
@STDERR (empty)
[1]
```

### SC2314-SC2315-SC2329

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2314-SC2315-SC2329.sh
@STDOUT
In fixtures/control-flow/SC2314-SC2315-SC2329.sh line 2:
@test "negation" { ! true; false; }
                   ^-- SC2314 (error): In Bats, ! does not cause a test failure. Use 'run ! ' (on Bats >= 1.5.0) instead.

Did you mean:
@test "negation" { run ! true; false; }

In fixtures/control-flow/SC2314-SC2315-SC2329.sh line 3:
@test "condition" { ! [[ -e test ]]; }
                    ^-- SC2315 (style): In Bats, ! will not fail the test if it is not the last command anymore. Fold the `!` into the conditional!

In fixtures/control-flow/SC2314-SC2315-SC2329.sh line 4:
f() { echo hidden; }
^------------------^ SC2329 (info): This function is never invoked. Check usage (or ignored if invoked indirectly).
@STDERR (empty)
[1]
```

### SC2264

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2264.sh
@STDOUT
In fixtures/control-flow/SC2264.sh line 2:
f() { f; }
      ^-- SC2264 (error): This function unconditionally re-invokes itself. Missing 'command'?

Did you mean:
f() { command f; }

In fixtures/control-flow/SC2264.sh line 3:
cd() { cd "$1" || exit; }
       ^-- SC2264 (error): This function unconditionally re-invokes itself. Missing 'command'?

Did you mean:
cd() { command cd "$1" || exit; }
@STDERR (empty)
[1]
```

### SC2093

```mooncram moonbit-community/bashcheck
$ bashcheck --norc --color=never -W0 -ftty fixtures/control-flow/SC2093.sh
@STDOUT
In fixtures/control-flow/SC2093.sh line 2:
exec foo; true
^------^ SC2093 (warning): Remove "exec " if script should continue after this command.

In fixtures/control-flow/SC2093.sh line 3:
for f in *; do exec "$f"; done
               ^-------^ SC2093 (warning): Remove "exec " if script should continue after this command.
@STDERR (empty)
[1]
```
