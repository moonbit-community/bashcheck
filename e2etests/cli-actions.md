# CLI actions

These baselines include argv parsing, the executable entry point, stdout/stderr and actual process status.

## Help

Keep the complete ShellCheck-compatible option list.

```mooncram moonbit-community/bashcheck
$ bashcheck --help
@STDOUT
Usage: bashcheck [OPTIONS...] FILES...
  -a                  --check-sourced            Include warnings from sourced files
  -C[WHEN]            --color[=WHEN]             Use color (auto, always, never)
  -i CODE1,CODE2..    --include=CODE1,CODE2..    Consider only given types of warnings
  -e CODE1,CODE2..    --exclude=CODE1,CODE2..    Exclude types of warnings
                      --extended-analysis=bool   Perform dataflow analysis (default true)
  -f FORMAT           --format=FORMAT            Output format (checkstyle, diff, gcc, json, json1, quiet, tty)
                      --list-optional            List checks disabled by default
                      --norc                     Don't look for .shellcheckrc files
                      --rcfile=RCFILE            Prefer the specified configuration file over searching for one
  -o check1,check2..  --enable=check1,check2..   List of optional checks to enable (or 'all')
  -P SOURCEPATHS      --source-path=SOURCEPATHS  Specify path when looking for sourced files ("SCRIPTDIR" for script's dir)
  -s SHELLNAME        --shell=SHELLNAME          Specify dialect (sh, bash, dash, ksh, busybox)
  -S SEVERITY         --severity=SEVERITY        Minimum severity of errors to consider (error, warning, info, style)
  -V                  --version                  Print version information
  -W NUM              --wiki-link-count=NUM      The number of wiki links to show, when applicable
  -x                  --external-sources         Allow 'source' outside of FILES
                      --help                     Show this usage summary and exit
@STDERR (empty)
```

## Optional checks

Keep the complete public list; the control-flow extension is not advertised.

```mooncram moonbit-community/bashcheck
$ bashcheck --list-optional
@STDOUT
name:    add-default-case
desc:    Suggest adding a default case in `case` statements
example: case $? in 0) echo 'Success';; esac
fix:     case $? in 0) echo 'Success';; *) echo 'Fail' ;; esac

name:    avoid-negated-conditions
desc:    Suggest removing unnecessary comparison negations
example: [ ! "$var" -eq 1 ]
fix:     [ "$var" -ne 1 ]

name:    avoid-nullary-conditions
desc:    Suggest explicitly using -n in `[ $var ]`
example: [ "$var" ]
fix:     [ -n "$var" ]

name:    check-extra-masked-returns
desc:    Check for additional cases where exit codes are masked
example: rm -r "$(get_chroot_dir)/home"
fix:     set -e; dir="$(get_chroot_dir)"; rm -r "$dir/home"

name:    check-set-e-suppressed
desc:    Notify when set -e is suppressed during function invocation
example: set -e; func() { cp *.txt ~/backup; rm *.txt; }; func && echo ok
fix:     set -e; func() { cp *.txt ~/backup; rm *.txt; }; func; echo ok

name:    check-unassigned-uppercase
desc:    Warn when uppercase variables are unassigned
example: echo $VAR
fix:     VAR=hello; echo $VAR

name:    deprecate-which
desc:    Suggest 'command -v' instead of 'which'
example: which javac
fix:     command -v javac

name:    quote-safe-variables
desc:    Suggest quoting variables without metacharacters
example: var=hello; echo $var
fix:     var=hello; echo "$var"

name:    require-double-brackets
desc:    Require [[ and warn about [ in Bash/Ksh
example: [ -e /etc/issue ]
fix:     [[ -e /etc/issue ]]

name:    require-variable-braces
desc:    Suggest putting braces around all variable references
example: var=hello; echo $var
fix:     var=hello; echo ${var}

name:    useless-use-of-cat
desc:    Check for Useless Use Of Cat (UUOC)
example: cat foo | grep bar
fix:     grep bar foo
@STDERR (empty)
```

## Version and action precedence

The first meta action wins, and actions do not try to open input files.

```mooncram moonbit-community/bashcheck
$ bashcheck --version
@STDOUT
bashcheck 0.1.0
@STDERR (empty)

$ bashcheck -V missing.sh
@STDOUT
bashcheck 0.1.0
@STDERR (empty)

$ bashcheck --version --help
@STDOUT
bashcheck 0.1.0
@STDERR (empty)

$ bashcheck --help --version
@STDOUT
Usage: bashcheck [OPTIONS...] FILES...
  -a                  --check-sourced            Include warnings from sourced files
  -C[WHEN]            --color[=WHEN]             Use color (auto, always, never)
  -i CODE1,CODE2..    --include=CODE1,CODE2..    Consider only given types of warnings
  -e CODE1,CODE2..    --exclude=CODE1,CODE2..    Exclude types of warnings
                      --extended-analysis=bool   Perform dataflow analysis (default true)
  -f FORMAT           --format=FORMAT            Output format (checkstyle, diff, gcc, json, json1, quiet, tty)
                      --list-optional            List checks disabled by default
                      --norc                     Don't look for .shellcheckrc files
                      --rcfile=RCFILE            Prefer the specified configuration file over searching for one
  -o check1,check2..  --enable=check1,check2..   List of optional checks to enable (or 'all')
  -P SOURCEPATHS      --source-path=SOURCEPATHS  Specify path when looking for sourced files ("SCRIPTDIR" for script's dir)
  -s SHELLNAME        --shell=SHELLNAME          Specify dialect (sh, bash, dash, ksh, busybox)
  -S SEVERITY         --severity=SEVERITY        Minimum severity of errors to consider (error, warning, info, style)
  -V                  --version                  Print version information
  -W NUM              --wiki-link-count=NUM      The number of wiki links to show, when applicable
  -x                  --external-sources         Allow 'source' outside of FILES
                      --help                     Show this usage summary and exit
@STDERR (empty)
```
