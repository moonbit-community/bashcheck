# CLI actions

These baselines include argv parsing, the executable entry point, stdout/stderr and actual process status.

## Help

Render the complete option list from the argparse command used for parsing.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --help
@STDOUT
Usage: bashcheck [options] [files...]

Arguments:
  files...  Shell scripts to check ('-' for stdin; default: stdin)

Options:
  -a, --check-sourced                      Include warnings from sourced files
  -x, --external-sources                   Allow 'source' outside of FILES
  --norc                                   Don't look for .shellcheckrc files
  --list-optional                          List checks disabled by default
  -V, --version                            Print version information
  --help                                   Show this usage summary and exit
  -f, --format <format>                    Output format (checkstyle, diff, gcc, json, json1, quiet, tty)
  -s, --shell <shell>                      Specify dialect (sh, bash, dash, ksh, busybox)
  -S, --severity <severity>                Minimum severity of errors to consider (error, warning, info, style)
  -i, --include <include>                  Consider only given types of warnings (comma-separated codes)
  -e, --exclude <exclude>                  Exclude types of warnings (comma-separated codes)
  -o, --enable <enable>                    List of optional checks to enable (or 'all')
  -P, --source-path <source-path>          Specify path when looking for sourced files ("SCRIPTDIR" for script's dir)
  --rcfile <rcfile>                        Prefer the specified configuration file over searching for one
  -C, --color <color>                      Use color (auto, always, never); bare -C/--color means always
  -W, --wiki-link-count <wiki-link-count>  The number of wiki links to show, when applicable (default 3)
  --extended-analysis <extended-analysis>  Perform dataflow analysis (true/false, default true)
@STDERR (empty)
```

## Optional checks

Keep the complete public list; the control-flow extension is not advertised.

```mooncram moonbit-community/bashcheck
$ moonx moonbit-community/bashcheck --list-optional
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
$ moonx moonbit-community/bashcheck --version
@STDOUT
bashcheck 0.1.0
@STDERR (empty)

$ moonx moonbit-community/bashcheck -V missing.sh
@STDOUT
bashcheck 0.1.0
@STDERR (empty)

$ moonx moonbit-community/bashcheck --version --help
@STDOUT
bashcheck 0.1.0
@STDERR (empty)

$ moonx moonbit-community/bashcheck --help --version
@STDOUT
Usage: bashcheck [options] [files...]

Arguments:
  files...  Shell scripts to check ('-' for stdin; default: stdin)

Options:
  -a, --check-sourced                      Include warnings from sourced files
  -x, --external-sources                   Allow 'source' outside of FILES
  --norc                                   Don't look for .shellcheckrc files
  --list-optional                          List checks disabled by default
  -V, --version                            Print version information
  --help                                   Show this usage summary and exit
  -f, --format <format>                    Output format (checkstyle, diff, gcc, json, json1, quiet, tty)
  -s, --shell <shell>                      Specify dialect (sh, bash, dash, ksh, busybox)
  -S, --severity <severity>                Minimum severity of errors to consider (error, warning, info, style)
  -i, --include <include>                  Consider only given types of warnings (comma-separated codes)
  -e, --exclude <exclude>                  Exclude types of warnings (comma-separated codes)
  -o, --enable <enable>                    List of optional checks to enable (or 'all')
  -P, --source-path <source-path>          Specify path when looking for sourced files ("SCRIPTDIR" for script's dir)
  --rcfile <rcfile>                        Prefer the specified configuration file over searching for one
  -C, --color <color>                      Use color (auto, always, never); bare -C/--color means always
  -W, --wiki-link-count <wiki-link-count>  The number of wiki links to show, when applicable (default 3)
  --extended-analysis <extended-analysis>  Perform dataflow analysis (true/false, default true)
@STDERR (empty)
```
