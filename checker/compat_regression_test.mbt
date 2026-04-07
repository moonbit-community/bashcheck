///|
struct CompatDiagnostic {
  severity : String
  code : Int
  line : Int
  end_line : Int
  column : Int
  end_column : Int
  message : String
} derive(Eq, Debug)

///|
fn compat_diagnostic(
  severity : String,
  code : Int,
  line : Int,
  column : Int,
  end_column : Int,
  message : String,
) -> CompatDiagnostic {
  { severity, code, line, end_line: line, column, end_column, message }
}

///|
fn compat_warning(
  code : Int,
  line : Int,
  column : Int,
  end_column : Int,
  message : String,
) -> CompatDiagnostic {
  compat_diagnostic("warning", code, line, column, end_column, message)
}

///|
fn compat_error(
  code : Int,
  line : Int,
  column : Int,
  end_column : Int,
  message : String,
) -> CompatDiagnostic {
  compat_diagnostic("error", code, line, column, end_column, message)
}

///|
fn compat_info(
  code : Int,
  line : Int,
  column : Int,
  end_column : Int,
  message : String,
) -> CompatDiagnostic {
  compat_diagnostic("info", code, line, column, end_column, message)
}

///|
fn compat_style(
  code : Int,
  line : Int,
  column : Int,
  end_column : Int,
  message : String,
) -> CompatDiagnostic {
  compat_diagnostic("style", code, line, column, end_column, message)
}

///|
fn normalize_compat_diagnostics(
  diagnostics : Array[PositionedDiagnostic],
) -> Array[CompatDiagnostic] {
  let normalized : Array[CompatDiagnostic] = []
  for diagnostic in diagnostics {
    let code = match diagnostic.code {
      Some(code) => code
      None => abort("expected lint diagnostic code")
    }
    normalized.push({
      severity: compat_severity_name(diagnostic.severity),
      code,
      line: diagnostic.span.start.line,
      end_line: diagnostic.span.end.line,
      column: diagnostic.span.start.column,
      end_column: diagnostic.span.end.column,
      message: diagnostic.message,
    })
  }
  normalized
}

///|
fn compat_severity_name(severity : DiagnosticSeverity) -> String {
  match severity {
    DiagnosticSeverity::Error => "error"
    DiagnosticSeverity::Warning => "warning"
    DiagnosticSeverity::Info => "info"
    DiagnosticSeverity::Style => "style"
  }
}

///|
fn assert_compat_case(
  label : String,
  source : String,
  expected : Array[CompatDiagnostic],
) -> Unit {
  assert_compat_case_with_spec(label, source, expected, CheckSpec::default())
}

///|
fn assert_compat_case_with_optional_checks(
  label : String,
  source : String,
  expected : Array[CompatDiagnostic],
  optional_checks : Array[String],
) -> Unit {
  assert_compat_case_with_spec(
    label,
    source,
    expected,
    CheckSpec::default().with_optional_checks(optional_checks),
  )
}

///|
fn assert_compat_case_with_spec(
  label : String,
  source : String,
  expected : Array[CompatDiagnostic],
  spec : CheckSpec,
) -> Unit {
  let result = check_script(source, spec~)
  let actual = normalize_compat_diagnostics(result.diagnostics)
  if actual != expected {
    abort(
      "\{label}: expected \{@debug.to_string(expected)}, got \{@debug.to_string(actual)}",
    )
  }
}

///|
fn assert_no_compat_case(label : String, source : String) -> Unit {
  assert_compat_case(label, source, [])
}

///|
fn assert_no_compat_case_with_optional_checks(
  label : String,
  source : String,
  optional_checks : Array[String],
) -> Unit {
  assert_compat_case_with_optional_checks(label, source, [], optional_checks)
}

///|
fn assert_no_compat_case_with_spec(
  label : String,
  source : String,
  spec : CheckSpec,
) -> Unit {
  assert_compat_case_with_spec(label, source, [], spec)
}

///|
test "compat regression covers analytics core diagnostics" {
  assert_compat_case(
    "analytics-core",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2086
      #|echo `foo`
      #|printf "%s\n" $* $@
      #|
    ),
    [
      compat_warning(2046, 3, 6, 11, "Quote this to prevent word splitting."),
      compat_style(
        2005, 3, 6, 11, "Useless echo? Instead of 'echo $(cmd)', just use 'cmd'.",
      ),
      compat_style(
        2006, 3, 6, 11, "Use $(...) notation instead of legacy backticks `...`.",
      ),
      compat_warning(
        2048, 4, 15, 17, "Use \"$@\" (with quotes) to prevent whitespace problems.",
      ),
      compat_error(
        2068, 4, 18, 20, "Double quote array expansions to avoid re-splitting elements.",
      ),
    ],
  )

  assert_compat_case(
    "analytics-for-in",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2035
      #|for f in 'ls'; do :; done
      #|for f in a,b; do :; done
      #|for f in ls; do :; done
      #|for f in "$(ls)"; do :; done
      #|for f in $(find . -name '*.mp3'); do :; done
      #|for f in $(ls *.mp3); do :; done
      #|
    ),
    [
      compat_warning(
        2041, 3, 10, 14, "This is a literal string. To run as a command, use $(..) instead of '..' . ",
      ),
      compat_warning(
        2042, 4, 10, 13, "Use spaces, not commas, to separate loop elements.",
      ),
      compat_warning(
        2043, 5, 10, 12, "This loop will only ever run once. Bad quoting or missing glob/expansion?",
      ),
      compat_error(
        2066, 6, 10, 17, "Since you double quoted this, it will not word split, and the loop will only run once.",
      ),
      compat_warning(
        2044, 7, 10, 33, "For loops over find output are fragile. Use find -exec or a while read loop.",
      ),
      compat_error(
        2045, 8, 10, 21, "Iterating over ls output is fragile. Use globs.",
      ),
    ],
  )
}

///|
test "compat regression covers optional analytics diagnostics" {
  assert_compat_case_with_optional_checks(
    "optional-analytics",
    (
      #|#!/bin/bash
      #|cat foo | grep bar
      #|case $1 in a) true ;; esac
      #|
    ),
    [
      compat_style(
        2002, 2, 5, 8, "Useless cat. Consider 'cmd < file | ..' or 'cmd file | ..' instead.",
      ),
      compat_info(
        2249, 3, 1, 27, "Consider adding a default *) case, even if it just exits with error.",
      ),
    ],
    ["useless-use-of-cat", "add-default-case"],
  )
}

///|
test "compat regression covers phase 7 optional analytics diagnostics" {
  assert_compat_case_with_optional_checks(
    "optional-analytics-phase-7",
    (
      #|#!/bin/bash
      #|safe=hello
      #|name=hello
      #|var=hello
      #|echo $safe
      #|[ "$name" ]
      #|[ ! -z "$var" ]
      #|printf '%s' prefix=$var
      #|[ -x foo ]
      #|
    ),
    [
      compat_style(
        2248, 5, 6, 11, "Prefer double quoting even when variables don't contain special characters.",
      ),
      compat_style(
        2250, 5, 6, 11, "Prefer putting braces around variable references even when not strictly required.",
      ),
      compat_style(
        2292, 6, 1, 12, "Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox.",
      ),
      compat_style(
        2244, 6, 3, 10, "Prefer explicit -n to check non-empty string (or use =/-ne to check boolean/integer).",
      ),
      compat_style(2236, 7, 1, 16, "Use -n instead of ! -z."),
      compat_style(
        2292, 7, 1, 16, "Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox.",
      ),
      compat_style(
        2250, 8, 13, 24, "Prefer putting braces around variable references even when not strictly required.",
      ),
      compat_style(
        2292, 9, 1, 11, "Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox.",
      ),
    ],
    [
      "quote-safe-variables", "avoid-nullary-conditions", "avoid-negated-conditions",
      "require-variable-braces", "require-double-brackets",
    ],
  )
}

///|
test "compat regression covers phase 7 set-e and masked-return diagnostics" {
  assert_compat_case_with_optional_checks(
    "optional-analytics-phase-7-set-e",
    (
      #|#!/bin/bash
      #|set -e
      #|f(){ false; }
      #|result=$(f)
      #|false | true
      #|
    ),
    [
      compat_warning(
        2034, 4, 1, 7, "result appears unused. Verify use (or export if used externally).",
      ),
      compat_info(
        2311, 4, 10, 11, "Bash implicitly disabled set -e for this function invocation because it's inside a command substitution. Add set -e; before it or enable inherit_errexit.",
      ),
      compat_info(
        2312, 5, 1, 6, "Consider invoking this command separately to avoid masking its return value (or use '|| true' to ignore).",
      ),
    ],
    ["check-set-e-suppressed", "check-extra-masked-returns"],
  )
}

///|
test "compat regression covers analytics assignment and loop diagnostics" {
  assert_compat_case(
    "analytics-batch-a-assignments",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|foo=bar | grep x
      #|out=ls -l
      #|prefix=hello printf '%s\n' "$prefix"
      #|same="$same"
      #|arr=( $var $(cmd) )
      #|for file in $dir/*.txt; do :; done
      #|( -e file )
      #|( 1 -gt 2 )
      #|
    ),
    [
      compat_warning(
        2034, 3, 1, 4, "foo appears unused. Verify use (or export if used externally).",
      ),
      compat_warning(
        2036, 3, 1, 8, "If you wanted to assign the output of the pipeline, use a=$(b | c) .",
      ),
      compat_error(
        2037, 4, 1, 7, "To assign the output of a command, use var=$(cmd) .",
      ),
      compat_warning(
        2097, 5, 1, 13, "This assignment is only seen by the forked process.",
      ),
      compat_warning(
        2098, 5, 28, 37, "This expansion will not see the mentioned assignment.",
      ),
      compat_info(
        2269, 6, 1, 13, "This variable is assigned to itself, so the assignment does nothing.",
      ),
      compat_warning(
        2034, 7, 1, 4, "arr appears unused. Verify use (or export if used externally).",
      ),
      compat_warning(
        2206, 7, 7, 11, "Quote to prevent word splitting/globbing, or split robustly with mapfile or read -a.",
      ),
      compat_warning(
        2207, 7, 12, 18, "Prefer mapfile or read -a to split command output (or quote to avoid splitting).",
      ),
      compat_info(
        2231, 8, 13, 23, "Quote expansions in this for loop glob to prevent wordsplitting, e.g. \"$dir\"/*.txt .",
      ),
      compat_error(
        2204, 9, 1, 12, "(..) is a subshell. Did you mean [ .. ], a test expression?",
      ),
      compat_warning(
        2205, 10, 1, 12, "(..) is a subshell. Did you mean [ .. ], a test expression?",
      ),
    ],
  )
}

///|
test "compat regression covers analytics condition diagnostics" {
  assert_compat_case(
    "analytics-batch-a-conditions",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|[ foo -a -f bar ]
      #|[ -z 3 -o a = b ]
      #|[[ $foo =~ 'cow|bar' ]]
      #|
    ),
    [
      compat_warning(
        2166, 3, 1, 18, "Prefer [ p ] && [ q ] as [ p -a q ] is not well defined.",
      ),
      compat_warning(
        2166, 4, 1, 18, "Prefer [ p ] || [ q ] as [ p -o q ] is not well defined.",
      ),
      compat_warning(
        2050, 4, 13, 14, "This expression is constant. Did you forget the $ on a variable?",
      ),
      compat_warning(
        2076, 5, 12, 21, "Remove quotes from right-hand side of =~ to match as a regex rather than literally.",
      ),
    ],
  )
}

///|
test "compat regression covers analytics unused assignment diagnostics" {
  assert_compat_case(
    "analytics-batch-a-unused-assignments",
    (
      #|#!/bin/bash
      #|foo=bar
      #|readonly baz=qux
      #|declare zap
      #|typeset t=3
      #|f(){ local x=1; }
      #|export nope=1
      #|used=1
      #|echo $used
      #|
    ),
    [
      compat_warning(
        2034, 2, 1, 4, "foo appears unused. Verify use (or export if used externally).",
      ),
      compat_warning(
        2034, 3, 10, 13, "baz appears unused. Verify use (or export if used externally).",
      ),
      compat_warning(
        2034, 4, 9, 12, "zap appears unused. Verify use (or export if used externally).",
      ),
      compat_warning(
        2034, 5, 9, 10, "t appears unused. Verify use (or export if used externally).",
      ),
      compat_warning(
        2034, 6, 12, 13, "x appears unused. Verify use (or export if used externally).",
      ),
    ],
  )
}

///|
test "compat regression covers analytics unquoted parameter diagnostics" {
  assert_compat_case(
    "analytics-batch-a-unquoted-parameters",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|echo $foo
      #|echo ${foo:-bar}
      #|echo $1
      #|echo $*
      #|echo ${array[*]}
      #|echo ${array[@]}
      #|echo ${foo:+bar}
      #|echo ${#foo}
      #|
    ),
    [
      compat_info(
        2086, 3, 6, 10, "Double quote to prevent globbing and word splitting.",
      ),
      compat_info(
        2086, 4, 6, 17, "Double quote to prevent globbing and word splitting.",
      ),
      compat_info(
        2086, 5, 6, 8, "Double quote to prevent globbing and word splitting.",
      ),
      compat_warning(
        2048, 6, 6, 8, "Use \"$@\" (with quotes) to prevent whitespace problems.",
      ),
      compat_info(
        2086, 6, 6, 8, "Double quote to prevent globbing and word splitting.",
      ),
      compat_warning(
        2048, 7, 6, 17, "Use \"${array[@]}\" (with quotes) to prevent whitespace problems.",
      ),
      compat_info(
        2086, 7, 6, 17, "Double quote to prevent globbing and word splitting.",
      ),
      compat_error(
        2068, 8, 6, 17, "Double quote array expansions to avoid re-splitting elements.",
      ),
    ],
  )
}

///|
test "compat regression covers analytics uppercase misspelling diagnostics" {
  assert_compat_case(
    "analytics-batch-a-uppercase-misspellings",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2086
      #|HOME_DIR=1
      #|PATHS=1
      #|echo $HOMR_DIR
      #|echo ${PATS}
      #|
    ),
    [
      compat_info(
        2153, 5, 6, 15, "Possible misspelling: HOMR_DIR may not be assigned. Did you mean HOME_DIR?",
      ),
      compat_info(
        2153, 6, 6, 13, "Possible misspelling: PATS may not be assigned. Did you mean PATHS?",
      ),
    ],
  )
}

///|
test "compat regression covers analytics bad parameter substitution diagnostics" {
  assert_compat_case(
    "analytics-bad-parameter-substitutions",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2086,SC2154
      #|echo ${"bar"}
      #|echo ${{var}
      #|echo ${$(x)//x/y}
      #|echo ${'foo'}
      #|echo ${${x%.*}##*/}
      #|echo ${${x}foo!}
      #|
    ),
    [
      compat_error(
        2297, 3, 8, 13, "Double quotes must be outside ${}: ${\"invalid\"} vs \"${valid}\".",
      ),
      compat_error(
        2296, 4, 8, 12, "Parameter expansions can't start with {. Double check syntax.",
      ),
      compat_error(
        2300, 5, 8, 12, "Parameter expansion can't be applied to command substitutions. Use temporary variables.",
      ),
      compat_error(
        2301, 6, 8, 13, "Parameter expansion starts with unexpected quotes. Double check syntax.",
      ),
      compat_error(
        2299, 7, 8, 15, "Parameter expansions can't be nested. Use temporary variables.",
      ),
      compat_error(
        2298, 8, 8, 12, "${${x}} is invalid. For expansion, use ${x}. For indirection, use arrays, ${!x} or (for sh) eval.",
      ),
    ],
  )
}

///|
test "compat regression covers analytics batch b condition diagnostics" {
  assert_compat_case(
    "analytics-batch-b-conditions",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|[[ $cow == $bar ]]
      #|[ $cow = *foo* ]
      #|[[ $foo =~ *foo* ]]
      #|if [ ]; then :; fi
      #|
    ),
    [
      compat_warning(
        2053, 3, 12, 16, "Quote the right-hand side of == in [[ ]] to prevent glob matching.",
      ),
      compat_info(
        2086, 4, 3, 7, "Double quote to prevent globbing and word splitting.",
      ),
      compat_error(
        2081, 4, 10, 15, "[ .. ] can't match globs. Use [[ .. ]] or case statement.",
      ),
      compat_warning(
        2049, 5, 12, 17, "=~ is for regex, but this looks like a glob. Use = instead.",
      ),
      compat_style(
        2212, 6, 4, 7, "Use 'false' instead of empty [/[[ conditionals.",
      ),
    ],
  )

  assert_compat_case(
    "analytics-batch-b-busybox",
    (
      #|#!/bin/busybox sh
      #|[[ x == *foo* ]]
      #|
    ),
    [
      compat_error(
        2330, 2, 9, 14, "BusyBox [[ .. ]] does not support glob matching. Use a case statement.",
      ),
    ],
  )
}

///|
test "compat regression covers analytics batch b command diagnostics" {
  assert_compat_case(
    "analytics-batch-b-commands",
    (
      #|./ file
      #|i=i + 1
      #|n=2
      #|i=n*2
      #|foo*
      #|-e file
      #|''
      #|/
      #|foo,
      #|
    ),
    [
      compat_error(
        2083, 1, 1, 3, "Don't add spaces after the slash in './file'.",
      ),
      {
        severity: "error",
        code: 2148,
        line: 1,
        end_line: 10,
        column: 1,
        end_column: 1,
        message: "Tips depend on target shell and yours is unknown. Add a shebang or a 'shell' directive.",
      },
      compat_warning(
        2099, 2, 5, 6, "Use $((..)) for arithmetics, e.g. i=$((i + 2))",
      ),
      compat_warning(
        2034, 3, 1, 2, "n appears unused. Verify use (or export if used externally).",
      ),
      compat_warning(
        2034, 4, 1, 2, "i appears unused. Verify use (or export if used externally).",
      ),
      compat_warning(
        2100, 4, 3, 6, "Use $((..)) for arithmetics, e.g. i=$((i * 2))",
      ),
      compat_warning(
        2211, 5, 1, 5, "This is a glob used as a command name. Was it supposed to be in ${..}, array, or is it missing quoting?",
      ),
      compat_warning(
        2215, 6, 1, 3, "This flag is used as a command name. Bad line break or missing [ .. ]?",
      ),
      compat_error(
        2286, 7, 1, 3, "This empty string is interpreted as a command name. Double check syntax (or use 'true' as a no-op).",
      ),
      compat_error(
        2287, 8, 1, 2, "This is interpreted as a command name ending with '/'. Double check syntax.",
      ),
      compat_warning(
        2288, 9, 1, 5, "This is interpreted as a command name ending with ','. Double check syntax.",
      ),
    ],
  )
}

///|
test "compat regression covers analytics batch b redirection diagnostics" {
  assert_compat_case(
    "analytics-batch-b-redirections",
    (
      #|test 3 > 1
      #|/usr/bin/test value > file
      #|foo 1>2
      #|ls > rm
      #|out=$(foo > log)
      #|
    ),
    [
      {
        severity: "error",
        code: 2148,
        line: 1,
        end_line: 6,
        column: 1,
        end_column: 1,
        message: "Tips depend on target shell and yours is unknown. Add a shebang or a 'shell' directive.",
      },
      compat_warning(
        2065, 1, 8, 11, "This is interpreted as a shell file redirection, not a comparison.",
      ),
      compat_warning(
        2065, 2, 21, 27, "This is interpreted as a shell file redirection, not a comparison.",
      ),
      compat_warning(
        2210, 3, 5, 8, "This is a file redirection. Was it supposed to be a comparison or fd operation?",
      ),
      compat_warning(
        2238, 4, 6, 8, "Redirecting to/from command name instead of file. Did you want pipes/xargs (or quote to ignore)?",
      ),
      compat_warning(
        2034, 5, 1, 4, "out appears unused. Verify use (or export if used externally).",
      ),
      compat_warning(
        2327, 5, 5, 17, "This command substitution will be empty because the command's output gets redirected away.",
      ),
      compat_error(
        2328, 5, 11, 16, "This redirection takes output away from the command substitution (use tee to duplicate).",
      ),
    ],
  )
}

///|
test "compat regression covers analytics batch c diagnostics" {
  assert_compat_case(
    "analytics-batch-c",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|echo "$foo" | wc -c
      #|ssh host <<EOF2
      #|echo $HOME
      #|EOF2
      #|f
      #|f() { true; }
      #|x(){ return 1; }
      #|x
      #|[ $? -eq 1 ] || [ $? -eq 2 ]
      #|echo "$?"
      #|echo "$?"
      #|
    ),
    [
      compat_style(2000, 3, 1, 20, "See if you can use ${#variable} instead."),
      compat_warning(
        2087, 4, 12, 16, "Quote 'EOF2' to make here document expansions happen on the server side rather than on the client.",
      ),
      compat_error(
        2218, 7, 1, 2, "This function is only defined later. Move the definition up.",
      ),
      compat_warning(
        2319, 11, 19, 21, "This $? refers to a condition, not a command. Assign to a variable to avoid it being overwritten.",
      ),
      compat_warning(
        2320, 13, 7, 9, "This $? refers to echo/printf, not a previous command. Assign to variable to avoid it being overwritten.",
      ),
    ],
  )
}

///|
test "compat regression covers command diagnostics" {
  assert_compat_case_with_optional_checks(
    "commands",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|time -f '%E' sleep 1
      #|sudo cat < input
      #|sudo cat > output
      #|sudo cat >> output
      #|find -type f
      #|read foo
      #|tempfile
      #|egrep '.+'
      #|fgrep '*' files
      #|which bash
      #|
    ),
    [
      compat_info(
        2023, 3, 1, 5, "The shell may override 'time' as seen in man time(1). Use 'command time ..' for that one.",
      ),
      compat_info(
        2024, 4, 10, 11, "sudo doesn't affect redirects. Use sudo cat file | ..",
      ),
      compat_warning(
        2024, 5, 10, 11, "sudo doesn't affect redirects. Use ..| sudo tee file",
      ),
      compat_warning(
        2024, 6, 10, 12, "sudo doesn't affect redirects. Use .. | sudo tee -a file",
      ),
      compat_info(
        2185, 7, 1, 5, "Some finds don't have a default path. Specify '.' explicitly.",
      ),
      compat_info(2162, 8, 1, 5, "read without -r will mangle backslashes."),
      compat_warning(
        2186, 9, 1, 9, "tempfile is deprecated. Use mktemp instead.",
      ),
      compat_info(
        2196, 10, 1, 6, "egrep is non-standard and deprecated. Use grep -E instead.",
      ),
      compat_info(
        2197, 11, 1, 6, "fgrep is non-standard and deprecated. Use grep -F instead.",
      ),
      compat_info(
        2230, 12, 1, 6, "'which' is non-standard. Use builtin 'command -v' instead.",
      ),
    ],
    ["deprecate-which"],
  )
}

///|
test "compat regression covers control-flow diagnostics" {
  assert_compat_case(
    "control-flow",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2086
      #|echo $foo
      #|arr=(a)
      #|arr=foo
      #|arr+=bar
      #|exit 0
      #|echo never
      #|
    ),
    [
      compat_warning(2154, 3, 6, 10, "foo is referenced but not assigned."),
      compat_warning(
        2178, 5, 1, 4, "Variable was used as an array but is now assigned a string.",
      ),
      compat_warning(
        2179, 6, 1, 4, "Use array+=(\"item\") to append items to an array.",
      ),
      compat_info(
        2317, 8, 1, 11, "Command appears to be unreachable. Check usage (or ignore if invoked indirectly).",
      ),
    ],
  )
}

///|
test "compat regression covers shell-support word diagnostics" {
  assert_compat_case(
    "shell-support-words",
    (
      #|#!/bin/sh
      #|# shellcheck disable=SC2007,SC2034,SC2086,SC2068
      #|x=value
      #|prefix=foo
      #|echo @(foo)
      #|echo $"msg"
      #|echo $[1 + 1]
      #|echo {a,b}
      #|echo ${!x}
      #|echo ${x[1]}
      #|echo ${!x[@]}
      #|echo ${!prefix*}
      #|echo ${x:0:3}
      #|echo ${x^^}
      #|echo ${x/st/xt}
      #|
    ),
    [
      compat_warning(3002, 5, 6, 12, "In POSIX sh, extglob is undefined."),
      compat_warning(3004, 6, 6, 12, "In POSIX sh, $\"..\" is undefined."),
      compat_warning(
        3007, 7, 6, 14, "In POSIX sh, $[..] in place of $((..)) is undefined.",
      ),
      compat_warning(
        3009, 8, 6, 11, "In POSIX sh, brace expansion is undefined.",
      ),
      compat_warning(
        3053, 9, 6, 11, "In POSIX sh, indirect expansion is undefined.",
      ),
      compat_warning(
        3054, 10, 6, 13, "In POSIX sh, array references are undefined.",
      ),
      compat_warning(
        3053, 11, 6, 14, "In POSIX sh, indirect expansion is undefined.",
      ),
      compat_warning(
        3055, 11, 6, 14, "In POSIX sh, array key expansion is undefined.",
      ),
      compat_warning(
        3053, 12, 6, 17, "In POSIX sh, indirect expansion is undefined.",
      ),
      compat_warning(
        3056, 12, 6, 17, "In POSIX sh, name matching prefixes are undefined.",
      ),
      compat_warning(
        3057, 13, 6, 14, "In POSIX sh, string indexing is undefined.",
      ),
      compat_warning(
        3059, 14, 6, 12, "In POSIX sh, case modification is undefined.",
      ),
      compat_warning(
        3060, 15, 6, 16, "In POSIX sh, string replacement is undefined.",
      ),
    ],
  )
}

///|
test "compat regression covers shell-support command diagnostics" {
  assert_compat_case(
    "shell-support-commands",
    (
      #|#!/bin/sh
      #|# shellcheck disable=SC1091,SC2034,SC2078,SC3018,SC2154
      #|cat < <(echo x)
      #|for ((i=0; i<1; i++)); do :; done
      #|((1))
      #|select x in a; do break; done
      #|[[ x ]]
      #|cat <<< hi
      #|x+=y
      #|arr=(a b)
      #|cat > *.txt
      #|coproc foo { echo hi; }
      #|source lib.sh
      #|
    ),
    [
      compat_warning(
        3001, 3, 7, 16, "In POSIX sh, process substitution is undefined.",
      ),
      compat_warning(
        3005, 4, 1, 4, "In POSIX sh, arithmetic for loops are undefined.",
      ),
      compat_warning(
        3006, 5, 1, 6, "In POSIX sh, standalone ((..)) is undefined.",
      ),
      compat_warning(3008, 6, 1, 7, "In POSIX sh, select loops are undefined."),
      compat_warning(3010, 7, 1, 8, "In POSIX sh, [[ ]] is undefined."),
      compat_warning(3011, 8, 5, 8, "In POSIX sh, here-strings are undefined."),
      compat_warning(3024, 9, 1, 2, "In POSIX sh, += is undefined."),
      compat_warning(3030, 10, 5, 10, "In POSIX sh, arrays are undefined."),
      compat_warning(
        3031, 11, 5, 12, "In POSIX sh, redirecting to/from globs is undefined.",
      ),
      compat_warning(3032, 12, 1, 24, "In POSIX sh, coproc is undefined."),
      compat_warning(
        3046, 13, 1, 14, "In POSIX sh, 'source' in place of '.' is undefined.",
      ),
    ],
  )
}

///|
test "compat regression covers dash shell-support severity" {
  assert_compat_case(
    "dash-shell-support",
    (
      #|#!/bin/dash
      #|((1))
      #|
    ),
    [
      compat_error(
        3006, 2, 1, 6, "In dash, standalone ((..)) is not supported.",
      ),
    ],
  )
}

///|
test "compat regression covers shell-support operator and arithmetic diagnostics" {
  assert_compat_case(
    "shell-support-operators-and-arithmetic",
    (
      #|#!/bin/sh
      #|# shellcheck disable=SC2068
      #|test x \< y
      #|[ x == y ]
      #|test foo =~ bar
      #|test -v var
      #|test -a file
      #|test -o errexit
      #|test -R ref
      #|test -N file
      #|test -k /tmp
      #|test -G file
      #|test -O file
      #|echo $((i++))
      #|echo $((2**3))
      #|echo $((16#FF))
      #|echo ${@%foo}
      #|
    ),
    [
      compat_warning(
        3012, 3, 8, 10, "In POSIX sh, lexicographical < is undefined.",
      ),
      compat_warning(
        3014, 4, 1, 11, "In POSIX sh, == in place of = is undefined.",
      ),
      compat_warning(
        2050, 4, 5, 7, "This expression is constant. Did you forget the $ on a variable?",
      ),
      compat_warning(
        3015, 5, 10, 12, "In POSIX sh, =~ regex matching is undefined.",
      ),
      compat_warning(
        3016, 6, 6, 8, "In POSIX sh, test -v (in place of [ -n \"${var+x}\" ]) is undefined.",
      ),
      compat_warning(
        3017, 7, 6, 8, "In POSIX sh, unary -a in place of -e is undefined.",
      ),
      compat_warning(
        3062, 8, 6, 8, "In POSIX sh, test -o to check options is undefined.",
      ),
      compat_warning(
        3063, 9, 6, 8, "In POSIX sh, test -R and namerefs in general are undefined.",
      ),
      compat_warning(3064, 10, 6, 8, "In POSIX sh, test -N is undefined."),
      compat_warning(3065, 11, 6, 8, "In POSIX sh, test -k is undefined."),
      compat_warning(3066, 12, 6, 8, "In POSIX sh, test -G is undefined."),
      compat_warning(3067, 13, 6, 8, "In POSIX sh, test -O is undefined."),
      compat_warning(3018, 14, 6, 14, "In POSIX sh, ++/-- is undefined."),
      compat_warning(
        3019, 15, 6, 15, "In POSIX sh, exponentials are undefined.",
      ),
      compat_warning(
        3052, 16, 6, 16, "In POSIX sh, arithmetic base conversion is undefined.",
      ),
      compat_warning(
        3058, 17, 6, 14, "In POSIX sh, string operations on $@/$* are undefined.",
      ),
    ],
  )
}

///|
test "compat regression covers shell-support redirect and wrapped command diagnostics" {
  assert_compat_case(
    "shell-support-redirects-and-wrappers",
    (
      #|#!/bin/sh
      #|# shellcheck disable=SC2046,SC2006,SC2182
      #|foo &> /dev/null
      #|cmd >& file
      #|exec {fd}>&2
      #|echo foo 42>/dev/null
      #|cat < /dev/tcp/host/123
      #|echo *[^0-9]*
      #|foo-bar() { true; }
      #|echo $(<file)
      #|echo `<file`
      #|trap foo ERR SIGINT sigterm
      #|printf '%q' "$1"
      #|command source lib.sh
      #|
    ),
    [
      compat_warning(3020, 3, 5, 7, "In POSIX sh, &> is undefined."),
      compat_warning(
        3021, 4, 5, 7, "In POSIX sh, >& filename (as opposed to >& fd) is undefined.",
      ),
      compat_warning(
        3022, 5, 6, 10, "In POSIX sh, named file descriptors are undefined.",
      ),
      compat_warning(
        3023, 6, 10, 12, "In POSIX sh, FDs outside 0-9 are undefined.",
      ),
      compat_warning(
        3025, 7, 7, 24, "In POSIX sh, /dev/{tcp,udp} is undefined.",
      ),
      compat_warning(
        3026, 8, 6, 14, "In POSIX sh, ^ in place of ! in glob bracket expressions is undefined.",
      ),
      compat_warning(
        3033, 9, 1, 20, "In POSIX sh, naming functions outside [a-zA-Z_][a-zA-Z0-9_]* is undefined.",
      ),
      compat_warning(
        3034, 10, 6, 14, "In POSIX sh, $(<file) to read files is undefined.",
      ),
      compat_warning(
        3035, 11, 6, 13, "In POSIX sh, `<file` to read files is undefined.",
      ),
      compat_warning(
        3047, 12, 10, 13, "In POSIX sh, trapping ERR is undefined.",
      ),
      compat_warning(
        3048, 12, 14, 20, "In POSIX sh, prefixing signal names with 'SIG' is undefined.",
      ),
      compat_warning(
        3048, 12, 21, 28, "In POSIX sh, prefixing signal names with 'SIG' is undefined.",
      ),
      compat_warning(
        3049, 12, 21, 28, "In POSIX sh, using lower/mixed case for signal names is undefined.",
      ),
      compat_warning(3050, 13, 8, 12, "In POSIX sh, printf %q is undefined."),
      compat_warning(
        3051, 14, 9, 15, "In POSIX sh, 'source' in place of '.' is undefined.",
      ),
    ],
  )
}

///|
test "compat regression covers shell-support builtin flag diagnostics" {
  assert_compat_case(
    "shell-support-builtin-flags",
    (
      #|#!/bin/sh
      #|# shellcheck disable=SC2162
      #|read -a foo
      #|printf -v out %s foo
      #|export -f foo
      #|readonly -a bar
      #|hash -l
      #|cd -P -e .
      #|type -a ls
      #|ulimit -x unlimited
      #|set -o emacs
      #|set --bad
      #|exec -c env
      #|echo -ne foo
      #|
    ),
    [
      compat_warning(3045, 3, 7, 8, "In POSIX sh, read -a is undefined."),
      compat_warning(3045, 4, 9, 10, "In POSIX sh, printf -v is undefined."),
      compat_warning(3045, 5, 9, 10, "In POSIX sh, export -f is undefined."),
      compat_warning(3045, 6, 11, 12, "In POSIX sh, readonly -a is undefined."),
      compat_warning(
        2034, 6, 13, 16, "bar appears unused. Verify use (or export if used externally).",
      ),
      compat_warning(3045, 7, 7, 8, "In POSIX sh, hash -l is undefined."),
      compat_warning(3045, 8, 8, 9, "In POSIX sh, cd -e is undefined."),
      compat_warning(3045, 9, 7, 8, "In POSIX sh, type -a is undefined."),
      compat_warning(3045, 10, 9, 10, "In POSIX sh, ulimit -x is undefined."),
      compat_warning(
        3040, 11, 8, 13, "In POSIX sh, set option emacs is undefined.",
      ),
      compat_warning(
        3042, 12, 5, 10, "In POSIX sh, set flag --bad is undefined.",
      ),
      compat_warning(3038, 13, 6, 8, "In POSIX sh, exec flags are undefined."),
      compat_warning(3045, 13, 7, 8, "In POSIX sh, exec -c is undefined."),
      compat_warning(3037, 14, 6, 9, "In POSIX sh, echo flags are undefined."),
    ],
  )
}

///|
test "compat regression covers commands batch a core diagnostics" {
  assert_compat_case(
    "commands-batch-a-core",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|tr 'a-z' 'A-Z'
      #|find / -name *.php
      #|find . -exec 'cat {} | wc -l' \;
      #|expr 1 * 2
      #|grep 'cow*test' file
      #|trap "echo $num" INT
      #|
    ),
    [
      compat_info(
        2018, 3, 4, 9, "Use '[:lower:]' to support accents and foreign alphabets.",
      ),
      compat_info(
        2019, 3, 10, 15, "Use '[:upper:]' to support accents and foreign alphabets.",
      ),
      compat_warning(
        2061, 4, 14, 19, "Quote the parameter to -name so the shell won't interpret it.",
      ),
      compat_warning(
        2150, 5, 8, 13, "-exec does not invoke a shell. Rewrite or use -exec sh -c .. .",
      ),
      compat_style(
        2003, 6, 1, 5, "expr is antiquated. Consider rewriting this using $((..)), ${} or [[ ]].",
      ),
      compat_error(
        2304, 6, 8, 9, "* must be escaped to multiply: \\*. Modern $((x * y)) avoids this issue.",
      ),
      compat_info(
        2022, 7, 6, 16, "Note that unlike globs, w* here matches 'www' but not 'whiskey'.",
      ),
      compat_warning(
        2064, 8, 6, 17, "Use single quotes, otherwise this expands now rather than when signalled.",
      ),
    ],
  )
}

///|
test "compat regression covers commands batch a builtin diagnostics" {
  assert_compat_case(
    "commands-batch-a-builtins",
    (
      #|#!/bin/sh
      #|# shellcheck disable=SC2154,SC2317
      #|. script arg
      #|sudo cd /root
      #|read $var
      #|read arr[val]
      #|printf '%s %s' 1
      #|return 1 2
      #|exit 1000
      #|
    ),
    [
      compat_warning(
        2240, 3, 10, 13, "The dot command does not support arguments in sh/dash. Set them as variables.",
      ),
      compat_warning(
        2232, 4, 1, 5, "Can't use sudo with builtins like cd. Did you want sudo sh -c .. instead?",
      ),
      compat_info(2162, 5, 1, 5, "read without -r will mangle backslashes."),
      compat_warning(
        2229, 5, 6, 10, "This does not read 'var'. Remove $/${} for that, or use ${var?} to quiet.",
      ),
      compat_info(
        2086, 5, 6, 10, "Double quote to prevent globbing and word splitting.",
      ),
      compat_info(2162, 6, 1, 5, "read without -r will mangle backslashes."),
      compat_warning(
        2313, 6, 6, 14, "Quote array indices to avoid them expanding as globs.",
      ),
      compat_warning(
        2183, 7, 8, 15, "This format string has 2 variables, but is passed 1 argument.",
      ),
      compat_error(
        2151, 8, 8, 9, "Only one integer 0-255 can be returned. Use stdout for other data.",
      ),
      compat_error(
        2242, 9, 6, 10, "Can only exit with status 0-255. Other data should be written to stdout/stderr.",
      ),
    ],
  )
}

///|
test "compat regression covers commands batch a find and printf follow-ups" {
  assert_compat_case(
    "commands-batch-a-followups",
    (
      #|#!/bin/bash
      #|find . -exec sh -c 'echo {}' \;
      #|find . -name '*.wav' -o -name '*.au' -exec rm {} +
      #|grep *.mp3 file
      #|printf foo bar
      #|
    ),
    [
      compat_warning(
        2156, 2, 20, 29, "Injecting filenames is fragile and insecure. Use parameters.",
      ),
      compat_warning(
        2146, 3, 38, 43, "This action ignores everything before the -o. Use \\( \\) to group.",
      ),
      compat_warning(
        2062, 4, 6, 11, "Quote the grep pattern so the shell won't interpret it.",
      ),
      compat_error(
        2182, 5, 8, 11, "This printf format string has no variables. Other arguments are ignored.",
      ),
    ],
  )
}

///|
test "compat regression covers commands batch b core diagnostics" {
  assert_compat_case(
    "commands-batch-b-core",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|alias a='cp $1 /a'
      #|alias foo="echo $PWD"
      #|while getopts 'a:b' x; do case $x in a) foo;; esac; done
      #|let a=1
      #|mv 'foo bar'
      #|chmod -r 0755 dir
      #|xargs -i{} echo {}
      #|eval "${args[@]@Q}"
      #|
    ),
    [
      compat_error(
        2142, 3, 7, 19, "Aliases can't use positional parameters. Use a function.",
      ),
      compat_warning(
        2139, 4, 7, 22, "This expands when defined, not when used. Consider escaping.",
      ),
      compat_warning(
        2213, 5, 27, 51, "getopts specified -b, but it's not handled by this 'case'.",
      ),
      compat_warning(
        2220, 5, 27, 51, "Invalid flags are not handled. Add a *) case.",
      ),
      compat_style(2219, 6, 1, 4, "Instead of 'let expr', prefer (( expr )) ."),
      compat_error(
        2224, 7, 1, 3, "This mv has no destination. Check the arguments.",
      ),
      compat_warning(
        2253, 8, 7, 9, "Use -R to recurse, or explicitly a-r to remove read permissions.",
      ),
      compat_info(2267, 9, 7, 11, "GNU xargs -i is deprecated in favor of -I{}"),
      compat_style(
        2293, 10, 6, 20, "When eval'ing @Q-quoted words, use * rather than @ as the index.",
      ),
    ],
  )
}

///|
test "compat regression covers commands batch b follow-up diagnostics" {
  assert_compat_case(
    "commands-batch-b-followups",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154
      #|while getopts 'a:' x; do case $x in a) foo;; b) bar;; esac; done
      #|cp 'foo bar'
      #|ln 'foo bar'
      #|alias x =0
      #|export a +=b
      #|eval "${args[@]}"
      #|
    ),
    [
      compat_warning(
        2220, 3, 26, 59, "Invalid flags are not handled. Add a *) case.",
      ),
      compat_warning(2214, 3, 46, 47, "This case is not specified by getopts."),
      compat_error(
        2225, 4, 1, 3, "This cp has no destination. Check the arguments.",
      ),
      compat_warning(
        2226, 5, 1, 3, "This ln has no destination. Check the arguments, or specify '.' explicitly.",
      ),
      compat_error(2290, 6, 9, 11, "Remove spaces around = to assign."),
      compat_error(2290, 7, 10, 13, "Remove spaces around += to append."),
      compat_warning(
        2294, 8, 6, 18, "eval negates the benefit of arrays. Drop eval to preserve whitespace/symbols (or eval as string).",
      ),
    ],
  )
}

///|
test "compat regression covers commands batch c phase 4 core diagnostics" {
  assert_compat_case(
    "commands-batch-c-core",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2086,SC2034,SC2329
      #|mkdir -p -m 0755 a/b
      #|su foo
      #|ssh host "echo $PS1"
      #|set foo 42
      #|export $foo
      #|unset foo[1]
      #|rm -rf /home
      #|rm -r $1/$2
      #|echo foo         bar
      #|q() { local readonly var=1; }
      #|q2() { local x=1 y=$x; }
      #|
    ),
    [
      compat_warning(
        2174, 3, 10, 12, "When used with -p, -m only applies to the deepest directory.",
      ),
      compat_info(
        2117, 4, 1, 7, "To run commands as another user, use su -c or sudo.",
      ),
      compat_info(
        2029, 5, 16, 20, "Note that, unescaped, this expands on the client side.",
      ),
      compat_warning(
        2121, 6, 5, 8, "To assign a variable, use just 'var=value', no 'set ..'.",
      ),
      compat_warning(
        2163, 7, 8, 12, "This does not export 'foo'. Remove $/${} for that, or use ${var?} to quiet.",
      ),
      compat_warning(
        2184, 8, 7, 13, "Quote arguments to unset so they're not glob expanded.",
      ),
      compat_warning(2114, 9, 8, 13, "Warning: deletes a system directory."),
      compat_warning(
        2115, 10, 7, 12, "Use \"${var:?}\" to ensure this never expands to / .",
      ),
      compat_info(
        2291, 11, 1, 21, "Quote repeated spaces to avoid them collapsing into one.",
      ),
      compat_error(
        2316, 12, 13, 21, "This applies local to the variable named readonly, which is probably not what you want. Use a separate command or the appropriate `declare` options instead.",
      ),
      compat_warning(
        2318, 13, 14, 15, "This assignment is used again in this 'local', but won't have taken effect. Use two 'local's.",
      ),
    ],
  )
}

///|
test "compat regression covers commands batch c shell-specific diagnostics" {
  assert_compat_case(
    "commands-batch-c-time-pipeline",
    (
      #|#!/bin/sh
      #|time -p foo | bar
      #|
    ),
    [
      compat_warning(
        2176, 2, 1, 5, "'time' is undefined for pipelines. time single stage or bash -c instead.",
      ),
    ],
  )

  assert_compat_case(
    "commands-batch-c-time-compound",
    (
      #|#!/bin/dash
      #|time ( foo; bar; )
      #|
    ),
    [
      compat_warning(
        2177, 2, 6, 19, "'time' is undefined for compound commands, time sh -c instead.",
      ),
    ],
  )

  assert_compat_case(
    "commands-batch-c-local-scope",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|local foo=3
      #|
    ),
    [compat_error(2168, 3, 1, 6, "'local' is only valid in functions.")],
  )
}

///|
test "compat regression keeps analytics negatives quiet" {
  assert_no_compat_case(
    "analytics-negatives",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|cow=moo
      #|bar=moo
      #|foo=cat
      #|dir=src
      #|cmd() { printf '%s\n' ok; }
      #|f() { true; }
      #|arr=( "$foo" "$(cmd)" * )
      #|for file in "$dir"/*.txt; do :; done
      #|printf '%s\n' "$foo" | wc -c
      #|ssh host <<'EOF'
      #|echo $HOME
      #|EOF
      #|f
      #|false
      #|status=$?
      #|[[ $cow == "$bar" ]]
      #|[[ $foo =~ ^c.* ]]
      #|test 1 -eq 2 2> file
      #|echo foo > '2'
      #|ls > myfile
      #|./file
      #|echo "$status"
      #|
    ),
  )
}

///|
test "compat regression keeps command negatives quiet" {
  assert_no_compat_case_with_optional_checks(
    "commands-negatives",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|command time -f '%E' sleep 1
      #|find . -type f
      #|find * -name '*.php'
      #|find . -exec wc -l {} \;
      #|find . -ok sh -c 'rm "$@"' _ {} \;
      #|find . -name '*.wav' -o \( -name '*.au' -exec rm {} + \)
      #|find . -exec echo {} \; > file
      #|read -r foo
      #|grep -E '.+'
      #|grep -F '*' files
      #|tr -d '[:lower:]'
      #|printf '%s %s\n' 1 2
      #|command -v bash
      #|mkdir -p a/b
      #|mkdir -m 0755 a/b
      #|mkdir -p -m 0755 singlelevel
      #|echo rm | su foo
      #|su root < script
      #|ssh host "ls foo"
      #|set -- if=/dev/null
      #|export foo
      #|unset foo
      #|rm -r /home/${USER:?}/*
      #|echo foo  bar
      #|f() { local foo=3; }
      #|q() { local var=1; }
      #|q2() { local x=1; local y=$x; }
      #|
    ),
    ["deprecate-which"],
  )
}

///|
test "compat regression keeps shell-support negatives quiet" {
  assert_no_compat_case(
    "shell-support-negatives",
    (
      #|#!/bin/sh
      #|name=foo
      #|printf '%s\n' "$name"
      #|test x = y
      #|test -n "$name"
      #|echo $((1 + 1))
      #|
    ),
  )
}

///|
test "compat regression keeps optional-check negatives quiet" {
  assert_no_compat_case_with_optional_checks(
    "optional-negatives",
    (
      #|#!/bin/bash
      #|safe=hello
      #|case $1 in
      #|  *) printf '%s\n' "${safe}" ;;
      #|esac
      #|[[ -n "${safe}" ]]
      #|[[ -x foo ]]
      #|command -v bash
      #|
    ),
    [
      "useless-use-of-cat", "add-default-case", "quote-safe-variables", "avoid-nullary-conditions",
      "avoid-negated-conditions", "require-variable-braces", "check-unassigned-uppercase",
      "require-double-brackets", "check-set-e-suppressed", "check-extra-masked-returns",
      "deprecate-which",
    ],
  )
}

///|
test "compat regression keeps multi-diagnostic sorting and filtering stable" {
  assert_compat_case(
    "sorting-and-filtering",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2005
      #|echo `foo`
      #|printf "%s\n" $* $@
      #|
    ),
    [
      compat_warning(2046, 3, 6, 11, "Quote this to prevent word splitting."),
      compat_style(
        2006, 3, 6, 11, "Use $(...) notation instead of legacy backticks `...`.",
      ),
      compat_warning(
        2048, 4, 15, 17, "Use \"$@\" (with quotes) to prevent whitespace problems.",
      ),
      compat_info(
        2086, 4, 15, 17, "Double quote to prevent globbing and word splitting.",
      ),
      compat_error(
        2068, 4, 18, 20, "Double quote array expansions to avoid re-splitting elements.",
      ),
    ],
  )
}

///|
test "compat regression covers shell-sensitive directives and rc settings" {
  assert_compat_case(
    "directive-shell-and-optional",
    (
      #|# shellcheck shell=bash enable=require-double-brackets
      #|[ -x foo ]
      #|
    ),
    [
      compat_style(
        2292, 2, 1, 11, "Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox.",
      ),
    ],
  )

  assert_compat_case_with_spec(
    "rc-shell-and-optional",
    (
      #|[ -x foo ]
      #|
    ),
    [
      compat_style(
        2292, 1, 1, 11, "Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox.",
      ),
    ],
    CheckSpec::default()
    .with_filename(Some("checker/testdata/rc/script.sh"))
    .with_config_files([
      (
        "checker/testdata/rc/.shellcheckrc",
        (
          #|enable=require-double-brackets
          #|shell=bash
          #|
        ),
      ),
    ]),
  )
}

///|
test "compat regression lets explicit shell overrides win over annotations" {
  assert_compat_case_with_spec(
    "shell-override-precedence",
    (
      #|# shellcheck shell=bash
      #|[[ x ]]
      #|
    ),
    [compat_warning(3010, 2, 1, 8, "In POSIX sh, [[ ]] is undefined.")],
    CheckSpec::default().with_shell_override(Some(@semantics.ShellDialect::Sh)),
  )

  assert_no_compat_case_with_spec(
    "shell-override-quiet",
    (
      #|# shellcheck shell=sh
      #|[[ x ]]
      #|
    ),
    CheckSpec::default().with_shell_override(
      Some(@semantics.ShellDialect::Bash),
    ),
  )
}
