///|
let internal_variable_table : Array[String] = [
  "", "_", "rest", "REST", "CDPATH", "ENV", "FCEDIT", "HISTFILE", "HISTSIZE", "HOME",
  "IFS", "LANG", "LC_ALL", "LC_COLLATE", "LC_CTYPE", "LC_MESSAGES", "LC_MONETARY",
  "LC_NUMERIC", "LC_TIME", "MAIL", "MAILCHECK", "MAILPATH", "OLDPWD", "OPTARG", "OPTIND",
  "PATH", "PWD", "BASH", "BASHOPTS", "BASHPID", "BASH_ALIASES", "BASH_ARGC", "BASH_ARGV",
  "BASH_ARGV0", "BASH_CMDS", "BASH_COMMAND", "BASH_EXECUTION_STRING", "BASH_LINENO",
  "BASH_LOADABLES_PATH", "BASH_REMATCH", "BASH_SOURCE", "BASH_SUBSHELL", "BASH_VERSINFO",
  "BASH_VERSION", "COMP_CWORD", "COMP_KEY", "COMP_LINE", "COMP_POINT", "COMP_TYPE",
  "COMP_WORDBREAKS", "COMP_WORDS", "COPROC", "DIRSTACK", "EPOCHREALTIME", "EPOCHSECONDS",
  "EUID", "FUNCNAME", "GROUPS", "HISTCMD", "HOSTNAME", "HOSTTYPE", "MACHTYPE", "MAPFILE",
  "OSTYPE", "PIPESTATUS", "RANDOM", "READLINE_ARGUMENT", "READLINE_LINE", "READLINE_MARK",
  "READLINE_POINT", "REPLY", "SECONDS", "SHELLOPTS", "SHLVL", "SRANDOM", "UID", "BASH_COMPAT",
  "BASH_ENV", "BASH_XTRACEFD", "CHILD_MAX", "COLUMNS", "COMPREPLY", "EMACS", "EXECIGNORE",
  "FIGNORE", "FUNCNEST", "GLOBIGNORE", "HISTCONTROL", "HISTFILESIZE", "HISTIGNORE",
  "HISTTIMEFORMAT", "HOSTFILE", "IGNOREEOF", "INPUTRC", "INSIDE_EMACS", "LINES",
  "OPTERR", "POSIXLY_CORRECT", "PROMPT_COMMAND", "PROMPT_DIRTRIM", "PS0", "PS1",
  "PS2", "PS3", "PS4", "SHELL", "TIMEFORMAT", "TMOUT", "BASH_MONOSECONDS", "BASH_TRAPSIG",
  "GLOBSORT", "auto_resume", "histchars", "USER", "TZ", "TERM", "LOGNAME", "LD_LIBRARY_PATH",
  "LANGUAGE", "DISPLAY", "HOSTNAME", "KRB5CCNAME", "LINENO", "PPID", "TMPDIR", "XAUTHORITY",
  ".sh.version", "FLAGS_ARGC", "FLAGS_ARGV", "FLAGS_ERROR", "FLAGS_FALSE", "FLAGS_HELP",
  "FLAGS_PARENT", "FLAGS_RESERVED", "FLAGS_TRUE", "FLAGS_VERSION", "flags_error",
  "flags_return", "stderr", "stderr_lines",
]

///|
let special_integer_variable_table : Array[String] = ["$", "?", "!", "#"]

///|
let special_variables_without_spaces_table : Array[String] = [
  "-", "$", "?", "!", "#",
]

///|
let variables_without_spaces_table : Array[String] = [
  "-", "$", "?", "!", "#", "BASHPID", "BASH_ARGC", "BASH_LINENO", "BASH_SUBSHELL",
  "EUID", "EPOCHREALTIME", "EPOCHSECONDS", "LINENO", "OPTIND", "PPID", "RANDOM",
  "READLINE_ARGUMENT", "READLINE_MARK", "READLINE_POINT", "SECONDS", "SHELLOPTS",
  "SHLVL", "SRANDOM", "UID", "COLUMNS", "HISTFILESIZE", "HISTSIZE", "LINES", "BASH_MONOSECONDS",
  "BASH_TRAPSIG", "FLAGS_ERROR", "FLAGS_FALSE", "FLAGS_TRUE",
]

///|
let special_variable_table : Array[String] = ["-", "$", "?", "!", "#", "@", "*"]

///|
let unbraced_variable_table : Array[String] = [
  "-", "$", "?", "!", "#", "@", "*", "0", "1", "2", "3", "4", "5", "6", "7", "8",
  "9",
]

///|
let array_variable_table : Array[String] = [
  "BASH_ALIASES", "BASH_ARGC", "BASH_ARGV", "BASH_CMDS", "BASH_LINENO", "BASH_REMATCH",
  "BASH_SOURCE", "BASH_VERSINFO", "COMP_WORDS", "COPROC", "DIRSTACK", "FUNCNAME",
  "GROUPS", "MAPFILE", "PIPESTATUS", "COMPREPLY",
]

///|
let common_command_table : Array[String] = [
  "admin", "alias", "ar", "asa", "at", "awk", "basename", "batch", "bc", "bg", "break",
  "c99", "cal", "cat", "cd", "cflow", "chgrp", "chmod", "chown", "cksum", "cmp",
  "colon", "comm", "command", "compress", "continue", "cp", "crontab", "csplit",
  "ctags", "cut", "cxref", "date", "dd", "delta", "df", "diff", "dirname", "dot",
  "du", "echo", "ed", "env", "eval", "ex", "exec", "exit", "expand", "export", "expr",
  "fc", "fg", "file", "find", "fold", "fuser", "gencat", "get", "getconf", "getopts",
  "gettext", "grep", "hash", "head", "iconv", "ipcrm", "ipcs", "jobs", "join", "kill",
  "lex", "link", "ln", "locale", "localedef", "logger", "logname", "lp", "ls", "m4",
  "mailx", "make", "man", "mesg", "mkdir", "mkfifo", "more", "msgfmt", "mv", "newgrp",
  "ngettext", "nice", "nl", "nm", "nohup", "od", "paste", "patch", "pathchk", "pax",
  "pr", "printf", "prs", "ps", "pwd", "read", "readlink", "readonly", "realpath",
  "renice", "return", "rm", "rmdel", "rmdir", "sact", "sccs", "sed", "set", "sh",
  "shift", "sleep", "sort", "split", "strings", "strip", "stty", "tabs", "tail",
  "talk", "tee", "test", "time", "timeout", "times", "touch", "tput", "tr", "trap",
  "tsort", "tty", "type", "ulimit", "umask", "unalias", "uname", "uncompress", "unexpand",
  "unget", "uniq", "unlink", "unset", "uucp", "uudecode", "uuencode", "uustat", "uux",
  "val", "vi", "wait", "wc", "what", "who", "write", "xargs", "xgettext", "yacc",
  "zcat",
]

///|
let non_reading_command_table : Array[String] = [
  "alias", "basename", "bg", "cal", "cd", "chgrp", "chmod", "chown", "cp", "du",
  "echo", "export", "fg", "fuser", "getconf", "getopt", "getopts", "ipcrm", "ipcs",
  "jobs", "kill", "ln", "ls", "locale", "mv", "printf", "ps", "pwd", "readlink",
  "realpath", "renice", "rm", "rmdir", "set", "sleep", "touch", "trap", "ulimit",
  "unalias", "uname",
]

///|
let sample_word_table : Array[String] = [
  "alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel", "india",
  "juliett", "kilo", "lima", "mike", "november", "oscar", "papa", "quebec", "romeo",
  "sierra", "tango", "uniform", "victor", "whiskey", "xray", "yankee", "zulu",
]

///|
let binary_test_operator_table : Array[String] = [
  "-nt", "-ot", "-ef", "==", "!=", "<=", ">=", "-eq", "-ne", "-lt", "-le", "-gt",
  "-ge", "=~", ">", "<", "=", "\\<", "\\>", "\\<=", "\\>=",
]

///|
let arithmetic_binary_test_operator_table : Array[String] = [
  "-eq", "-ne", "-lt", "-le", "-gt", "-ge",
]

///|
let unary_test_operator_table : Array[String] = [
  "!", "-a", "-b", "-c", "-d", "-e", "-f", "-g", "-h", "-L", "-k", "-p", "-r", "-s",
  "-S", "-t", "-u", "-w", "-x", "-O", "-G", "-N", "-z", "-n", "-o", "-v", "-R",
]

///|
let read_option_spec_table : String = "sred:u:n:N:i:p:a:t:"

///|
let mapfile_option_spec_table : String = "d:n:O:s:u:C:c:t"

///|
let declaring_command_table : Array[String] = [
  "local", "declare", "export", "readonly", "typeset", "let",
]

///|
/// Returns names treated as shell internal variables by semantics helpers.
pub fn internal_variable_names() -> Array[String] {
  copy_string_array(internal_variable_table)
}

///|
/// Returns special shell variables that are always interpreted as integers.
pub fn special_integer_variable_names() -> Array[String] {
  copy_string_array(special_integer_variable_table)
}

///|
/// Returns special variables whose expansions are treated as space-free.
pub fn special_variable_names_without_spaces() -> Array[String] {
  copy_string_array(special_variables_without_spaces_table)
}

///|
/// Returns all variable names whose expansions are treated as space-free.
pub fn variable_names_without_spaces() -> Array[String] {
  copy_string_array(variables_without_spaces_table)
}

///|
/// Returns special shell parameter names.
pub fn special_variable_names() -> Array[String] {
  copy_string_array(special_variable_table)
}

///|
/// Returns variable names that can be referenced without braces.
pub fn unbraced_variable_names() -> Array[String] {
  copy_string_array(unbraced_variable_table)
}

///|
/// Returns known array-valued shell variables.
pub fn array_variable_names() -> Array[String] {
  copy_string_array(array_variable_table)
}

///|
/// Returns a curated list of common command names used by heuristics.
pub fn common_command_names() -> Array[String] {
  copy_string_array(common_command_table)
}

///|
/// Returns command names treated as not reading standard input.
pub fn non_reading_command_names() -> Array[String] {
  copy_string_array(non_reading_command_table)
}

///|
/// Returns example words used by shell-query helpers and tests.
pub fn sample_words() -> Array[String] {
  copy_string_array(sample_word_table)
}

///|
/// Returns binary operators accepted by `test` and `[` expressions.
pub fn binary_test_operators() -> Array[String] {
  copy_string_array(binary_test_operator_table)
}

///|
/// Returns binary operators accepted in arithmetic-style tests.
pub fn arithmetic_binary_test_operators() -> Array[String] {
  copy_string_array(arithmetic_binary_test_operator_table)
}

///|
/// Returns unary operators accepted by `test` and `[` expressions.
pub fn unary_test_operators() -> Array[String] {
  copy_string_array(unary_test_operator_table)
}

///|
/// Returns the short-option specification for the `read` builtin.
pub fn read_option_spec() -> String {
  read_option_spec_table
}

///|
/// Returns the short-option specification for the `mapfile` builtin.
pub fn mapfile_option_spec() -> String {
  mapfile_option_spec_table
}

///|
/// Returns command names that declare variables or shell attributes.
pub fn declaring_command_names() -> Array[String] {
  copy_string_array(declaring_command_table)
}

///|
/// Reports whether a variable name is treated as shell-internal.
pub fn is_internal_variable(name : String) -> Bool {
  contains_string(internal_variable_table, name)
}

///|
/// Reports whether a variable name is one of the special integer variables.
pub fn is_special_integer_variable(name : String) -> Bool {
  contains_string(special_integer_variable_table, name)
}

///|
/// Reports whether a variable expands without spaces because it is special.
pub fn is_special_variable_without_spaces(name : String) -> Bool {
  contains_string(special_variables_without_spaces_table, name)
}

///|
/// Reports whether a variable expands without spaces.
pub fn is_variable_without_spaces(name : String) -> Bool {
  contains_string(variables_without_spaces_table, name)
}

///|
/// Reports whether a name is a special shell parameter.
pub fn is_special_variable(name : String) -> Bool {
  contains_string(special_variable_table, name)
}

///|
/// Reports whether a name can appear in an unbraced parameter expansion.
pub fn is_unbraced_variable(name : String) -> Bool {
  contains_string(unbraced_variable_table, name)
}

///|
/// Reports whether a name is treated as array-valued.
pub fn is_array_variable(name : String) -> Bool {
  contains_string(array_variable_table, name)
}

///|
/// Reports whether a command name is in the common-command table.
pub fn is_common_command(name : String) -> Bool {
  contains_string(common_command_table, name)
}

///|
/// Reports whether a command name is treated as not reading stdin.
pub fn is_non_reading_command(name : String) -> Bool {
  contains_string(non_reading_command_table, name)
}

///|
/// Reports whether an operator is a recognized binary test operator.
pub fn is_binary_test_operator(op : String) -> Bool {
  contains_string(binary_test_operator_table, op)
}

///|
/// Reports whether an operator is a recognized arithmetic binary operator.
pub fn is_arithmetic_binary_test_operator(op : String) -> Bool {
  contains_string(arithmetic_binary_test_operator_table, op)
}

///|
/// Reports whether an operator is a recognized unary test operator.
pub fn is_unary_test_operator(op : String) -> Bool {
  contains_string(unary_test_operator_table, op)
}

///|
/// Reports whether a command declares variables or attributes.
pub fn is_declaring_command(name : String) -> Bool {
  contains_string(declaring_command_table, name)
}

///|
/// Reports whether a short `read` flag consumes an argument.
pub fn read_flag_takes_argument(flag : UInt16) -> Bool {
  short_flag_requires_value(read_option_spec_table, flag)
}

///|
/// Reports whether a short `mapfile` flag consumes an argument.
pub fn mapfile_flag_takes_argument(flag : UInt16) -> Bool {
  short_flag_requires_value(mapfile_option_spec_table, flag)
}

///|
fn copy_string_array(values : Array[String]) -> Array[String] {
  let copied : Array[String] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn contains_string(values : Array[String], target : String) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn short_flag_requires_value(spec : String, flag : UInt16) -> Bool {
  let view = spec[:]
  let mut i = 0
  while i < view.length() {
    if view[i] == flag {
      return i + 1 < view.length() && view[i + 1] == ':'
    }
    if i + 1 < view.length() && view[i + 1] == ':' {
      i += 2
    } else {
      i += 1
    }
  }
  false
}
