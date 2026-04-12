///|
priv struct ShellSupportRule {
  code : Int
  feature : String
  exempt_shells : Array[@semantics.ShellDialect]
}

///|
fn shell_support_description(code : Int, summary : String) -> CheckDescription {
  shell_support_description_with_severity(code, CheckSeverity::Warning, summary)
}

///|
fn shell_support_description_with_severity(
  code : Int,
  severity : CheckSeverity,
  summary : String,
) -> CheckDescription {
  { code, severity, category: "shell-support", summary }
}

///|
fn shell_support_descriptions() -> Array[CheckDescription] {
  [
    shell_support_description_with_severity(
      2001,
      CheckSeverity::Style,
      "Use ${var//search/replace} instead of echo | sed for simple substitutions.",
    ),
    shell_support_description_with_severity(
      2025,
      CheckSeverity::Info,
      "Wrap PS1 escape sequences in \\[..\\] to preserve line wrapping.",
    ),
    shell_support_description(
      2051, "Bash doesn't support variables in brace range expansions.",
    ),
    shell_support_description_with_severity(
      2079,
      CheckSeverity::Error,
      "(( )) doesn't support decimals. Use bc or awk.",
    ),
    shell_support_description_with_severity(
      2175,
      CheckSeverity::Style,
      "Quote invalid brace expansions passed literally to eval.",
    ),
    shell_support_description(
      2180, "Bash does not support multidimensional arrays.",
    ),
    shell_support_description_with_severity(
      2325,
      CheckSeverity::Error,
      "Multiple leading ! before pipelines are a bash/ksh extension.",
    ),
    shell_support_description_with_severity(
      2326,
      CheckSeverity::Error,
      "! is not allowed in the middle of pipelines.",
    ),
    shell_support_description_with_severity(
      2332,
      CheckSeverity::Error,
      "[ ! -a/-o ... ] is always true in single-bracket tests.",
    ),
    shell_support_description(
      3001, "Process substitution is not portable to sh/dash.",
    ),
    shell_support_description(3002, "Extglob is not portable to sh/dash."),
    shell_support_description(3004, "$\"..\" is not portable to sh/dash."),
    shell_support_description(
      3005, "Arithmetic for loops are not portable to sh/dash.",
    ),
    shell_support_description(
      3006, "Standalone ((..)) is not portable to sh/dash.",
    ),
    shell_support_description(3007, "$[..] is not portable to sh/dash."),
    shell_support_description(3008, "select loops are not portable to sh/dash."),
    shell_support_description(
      3009, "Brace expansion is not portable to sh/dash.",
    ),
    shell_support_description(3010, "[[ ]] is not portable to sh/dash."),
    shell_support_description(3011, "Here-strings are not portable to sh/dash."),
    shell_support_description(
      3012, "Lexicographical test operators are not portable to plain sh.",
    ),
    shell_support_description(
      3014, "'==' in test expressions is not portable to sh/dash.",
    ),
    shell_support_description(
      3015, "Regex matching with '=~' is not portable to sh/dash.",
    ),
    shell_support_description(3016, "test -v is not portable to sh/dash."),
    shell_support_description(3017, "Unary test -a is not portable to sh/dash."),
    shell_support_description(
      3018, "Arithmetic ++/-- is not portable to sh/dash.",
    ),
    shell_support_description(
      3019, "Arithmetic ** exponentiation is not portable to sh/dash.",
    ),
    shell_support_description(
      3020, "&> redirections are not portable to sh/dash.",
    ),
    shell_support_description(
      3021, "`>& file` redirections are not portable to sh/dash.",
    ),
    shell_support_description(
      3022, "Named file descriptors are not portable to sh/dash.",
    ),
    shell_support_description(3023, "FDs above 9 are not portable to sh/dash."),
    shell_support_description(
      3024, "+= assignments are not portable to sh/dash.",
    ),
    shell_support_description(
      3025, "/dev/tcp and /dev/udp are not portable to sh/dash.",
    ),
    shell_support_description(
      3026, "[^..] glob ranges are not portable to sh/dash.",
    ),
    shell_support_description(
      3028, "Bash-specific variables are not portable to sh/dash.",
    ),
    shell_support_description(3029, "|& is not portable to sh/dash."),
    shell_support_description(3030, "Arrays are not portable to sh/dash."),
    shell_support_description(
      3031, "Redirecting to or from globs is not portable to sh/dash.",
    ),
    shell_support_description(3032, "coproc is not portable to sh/dash."),
    shell_support_description(
      3033, "Non-POSIX function names are not portable to sh/dash.",
    ),
    shell_support_description(
      3034, "$(<file) shortcuts are not portable to sh/dash.",
    ),
    shell_support_description(
      3035, "`<file` shortcuts are not portable to sh/dash.",
    ),
    shell_support_description(
      3036, "Non-portable echo flags are not portable to sh/dash.",
    ),
    shell_support_description(3037, "echo flags are not portable to plain sh."),
    shell_support_description(3038, "exec flags are not portable to sh/dash."),
    shell_support_description(3039, "'let' is not portable to sh/dash."),
    shell_support_description(
      3040, "Non-POSIX set -o options are not portable to sh.",
    ),
    shell_support_description(
      3041, "Non-POSIX set flags are not portable to sh.",
    ),
    shell_support_description(
      3042, "Double-dash set flags are not portable to sh.",
    ),
    shell_support_description(3043, "'local' is not portable to plain sh."),
    shell_support_description(
      3044, "This builtin or command is not portable to sh/dash.",
    ),
    shell_support_description(
      3045, "This builtin flag is not portable to sh/dash.",
    ),
    shell_support_description(3046, "'source' should be replaced with '.'."),
    shell_support_description(
      3047, "ERR/DEBUG/RETURN traps are not portable to sh/dash.",
    ),
    shell_support_description(
      3048, "SIG-prefixed trap names are not portable to sh/dash.",
    ),
    shell_support_description(
      3049, "Lowercase trap names are not portable to plain sh.",
    ),
    shell_support_description(3050, "printf %q is not portable to sh/dash."),
    shell_support_description(3051, "'source' should be replaced with '.'."),
    shell_support_description(
      3052, "Arithmetic base conversion is not portable to sh/dash.",
    ),
    shell_support_description(
      3053, "Indirect expansion is not portable to sh/dash.",
    ),
    shell_support_description(
      3054, "Array references are not portable to sh/dash.",
    ),
    shell_support_description(
      3055, "Array key expansion is not portable to sh/dash.",
    ),
    shell_support_description(
      3056, "Name matching prefixes are not portable to sh/dash.",
    ),
    shell_support_description(
      3057, "String indexing is not portable to sh/dash.",
    ),
    shell_support_description(
      3058, "String operations on $@/$* are not portable to sh/dash.",
    ),
    shell_support_description(
      3059, "Case modification is not portable to sh/dash.",
    ),
    shell_support_description(
      3060, "String replacement is not portable to sh/dash.",
    ),
    shell_support_description(
      3061, "read without a variable is not portable to sh/dash.",
    ),
    shell_support_description(3062, "test -o is not portable to sh/dash."),
    shell_support_description(3063, "test -R is not portable to sh/dash."),
    shell_support_description(3064, "test -N is not portable to sh/dash."),
    shell_support_description(3065, "test -k is not portable to plain sh."),
    shell_support_description(3066, "test -G is not portable to plain sh."),
    shell_support_description(3067, "test -O is not portable to plain sh."),
  ]
}

///|
fn shell_support_suite() -> CheckSuiteRegistration {
  { descriptions: shell_support_descriptions(), run: run_shell_support_checks }
}

///|
fn run_shell_support_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let assigned_names = collect_assigned_shell_support_names(script)
  visit_script_pipelines(script, fn(pipeline) {
    check_shell_support_pipeline(pipeline, shell, diagnostics)
  })
  visit_script_commands(script, fn(command) {
    check_shell_support_command(command, shell, diagnostics)
    let effective_name = @semantics.effective_command_name(command)
    visit_direct_words_in_command(command, fn(word, _) {
      check_shell_support_word(
        word, shell, assigned_names, effective_name, diagnostics,
      )
    })
  })
}

///|
fn check_shell_support_pipeline(
  pipeline : @parser.Pipeline,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if shell_is_posix_sh(shell) &&
    pipeline.operators.any(fn(op) {
      match op {
        @parser.PipeOperator::PipeAndStderr => true
        _ => false
      }
    }) {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      pipeline.span,
      3029,
      "|& in place of 2>&1 | is",
    )
  }
  if shell_is_posix_sh(shell) {
    for segment in pipeline.segments {
      if segment.bangs > 1 {
        push_diagnostic(
          diagnostics,
          span_prefix(segment.span, 1),
          CheckSeverity::Error,
          2325,
          "Multiple ! in front of pipelines are a bash/ksh extension. Use only 0 or 1.",
        )
      }
    }
  }
  if shell != @semantics.ShellDialect::Ksh {
    let mut i = 1
    while i < pipeline.segments.length() {
      let segment = pipeline.segments[i]
      if segment.bangs > 0 {
        push_diagnostic(
          diagnostics,
          span_prefix(segment.span, 1),
          CheckSeverity::Error,
          2326,
          "! is not allowed in the middle of pipelines. Use command group as in cmd | { ! cmd; } if necessary.",
        )
      }
      i += 1
    }
  }
  check_shell_support_echo_sed_pipeline(pipeline, shell, diagnostics)
}

///|
fn collect_assigned_shell_support_names(
  script : @parser.Script,
) -> Array[String] {
  let names : Array[String] = []
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        for assignment in simple.assignments {
          shell_support_push_unique_string(names, assignment.name)
        }
      @parser.CommandKind::Source(source) =>
        for assignment in source.assignments {
          shell_support_push_unique_string(names, assignment.name)
        }
      _ => ()
    }
  })
  names
}

///|
fn check_shell_support_command(
  command : @parser.Command,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match command.kind {
    @parser.CommandKind::ForArithmetic(clause) => {
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        command_keyword_span(command, "for"),
        3005,
        "arithmetic for loops are",
      )
      check_shell_support_arithmetic_expr(
        clause.init,
        command_keyword_span(command, "for"),
        shell,
        diagnostics,
      )
      check_shell_support_arithmetic_expr(
        clause.condition,
        command_keyword_span(command, "for"),
        shell,
        diagnostics,
      )
      check_shell_support_arithmetic_expr(
        clause.step,
        command_keyword_span(command, "for"),
        shell,
        diagnostics,
      )
    }
    @parser.CommandKind::Arithmetic(arithmetic) => {
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        command.span,
        3006,
        "standalone ((..)) is",
      )
      check_shell_support_arithmetic_expr(
        arithmetic.expr,
        command.span,
        shell,
        diagnostics,
      )
      maybe_push_decimal_arithmetic_command_diagnostic(
        command,
        arithmetic.expr,
        shell,
        diagnostics,
      )
    }
    @parser.CommandKind::Select(_) =>
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        command_keyword_span(command, "select"),
        3008,
        "select loops are",
      )
    @parser.CommandKind::Condition(condition) => {
      match condition.kind {
        @parser.ConditionKind::DoubleBracket =>
          if shell != @semantics.ShellDialect::BusyboxSh {
            push_shell_support_diagnostic(
              diagnostics,
              shell,
              command.span,
              3010,
              "[[ ]] is",
            )
          }
        _ => ()
      }
      check_shell_support_condition_expr(
        condition.expr,
        command.span,
        shell,
        diagnostics,
      )
      check_shell_support_negated_unary_ops(
        command, condition, shell, diagnostics,
      )
    }
    @parser.CommandKind::CoProc(_) =>
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        command.span,
        3032,
        "coproc is",
      )
    @parser.CommandKind::Source(source) => {
      check_shell_support_assignment_extensions(
        source.assignments,
        shell,
        diagnostics,
      )
      if source.keyword == "source" &&
        shell != @semantics.ShellDialect::BusyboxSh {
        push_shell_support_diagnostic(
          diagnostics,
          shell,
          command.span,
          3046,
          "'source' in place of '.' is",
        )
      }
    }
    @parser.CommandKind::Function(function_) =>
      if !shell_support_is_function_name(function_.name) {
        push_shell_support_diagnostic(
          diagnostics,
          shell,
          effective_command_span(command),
          3033,
          "naming functions outside [a-zA-Z_][a-zA-Z0-9_]* is",
        )
      }
    @parser.CommandKind::Simple(simple) => {
      maybe_push_assignment_append_diagnostic(
        diagnostics,
        shell,
        simple.assignments,
      )
      maybe_push_array_assignment_diagnostic(
        diagnostics,
        shell,
        simple.assignments,
      )
      check_shell_support_assignment_extensions(
        simple.assignments,
        shell,
        diagnostics,
      )
      check_shell_support_simple_command(command, shell, diagnostics)
    }
    _ => ()
  }
  check_shell_support_echo_sed_here_string(command, shell, diagnostics)
  for redirect in command.redirects {
    check_shell_support_redirection(redirect, shell, diagnostics)
  }
}

///|
fn check_shell_support_echo_sed_pipeline(
  pipeline : @parser.Pipeline,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell_support_is_echo_sed_shell(shell) else { return }
  guard pipeline.segments.length() == 2 else { return }
  let echo_command = pipeline.segments[0].command
  guard @semantics.command_name(echo_command) == Some("echo") else { return }
  let echo_arguments = @semantics.command_arguments(echo_command)
  guard echo_arguments.length() == 1 &&
    word_is_plain_variable_reference(echo_arguments[0]) else {
    return
  }
  maybe_push_echo_sed_diagnostic(
    pipeline.span,
    pipeline.segments[1].command,
    diagnostics,
  )
}

///|
fn check_shell_support_echo_sed_here_string(
  command : @parser.Command,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell_support_is_echo_sed_shell(shell) else { return }
  guard command.redirects.any(fn(redirect) {
    match redirect.op {
      @parser.RedirectionOperator::HereString => true
      _ => false
    }
  }) else {
    return
  }
  maybe_push_echo_sed_diagnostic(command.span, command, diagnostics)
}

///|
fn maybe_push_echo_sed_diagnostic(
  span : @parser.Span,
  command : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard @semantics.effective_command_name(command) == Some("sed") else {
    return
  }
  let arguments = @semantics.effective_command_arguments(command)
  match sed_script_argument(arguments) {
    Some(word) =>
      match @semantics.literal_text(word) {
        Some(text) if shell_support_is_simple_sed_substitution(text) =>
          push_diagnostic(
            diagnostics,
            span,
            CheckSeverity::Style,
            2001,
            "See if you can use ${variable//search/replace} instead.",
          )
        _ => ()
      }
    None => ()
  }
}

///|
fn sed_script_argument(arguments : Array[@parser.Word]) -> @parser.Word? {
  match arguments {
    [word] => Some(word)
    [flag, word] =>
      match @semantics.literal_text(flag) {
        Some("-e") => Some(word)
        _ => None
      }
    _ => None
  }
}

///|
fn shell_support_is_echo_sed_shell(shell : @semantics.ShellDialect) -> Bool {
  shell == @semantics.ShellDialect::Bash ||
  shell == @semantics.ShellDialect::Ksh
}

///|
fn shell_support_is_simple_sed_substitution(text : String) -> Bool {
  let view = text[:]
  if view.length() < 4 || view[0] != 's' || text.contains("\n") {
    return false
  }
  let delimiter = view[1]
  let body = if view[view.length() - 1] == 'g' {
    text.view(end_offset=view.length() - 1).to_string()
  } else {
    text
  }
  let body_view = body[:]
  let mut count = 0
  let mut i = 2
  while i < body_view.length() {
    if body_view[i] == delimiter {
      count += 1
    }
    i += 1
  }
  count == 2
}

///|
fn check_shell_support_simple_command(
  command : @parser.Command,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let actual_name = @semantics.command_name(command)
  let actual_arguments = @semantics.command_arguments(command)
  let effective_name = @semantics.effective_command_name(command)
  let arguments = @semantics.effective_command_arguments(command)
  match actual_name {
    Some("builtin") =>
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        command_name_span(command),
        3044,
        "'builtin' is",
      )
    Some("exec") => {
      check_shell_support_exec_command(
        command, actual_arguments, shell, diagnostics,
      )
      maybe_push_command_flag_diagnostic(
        diagnostics, shell, "exec", actual_arguments,
      )
    }
    _ => ()
  }
  match effective_name {
    Some("test") =>
      check_shell_support_test_command(arguments, shell, diagnostics)
    Some("echo") =>
      check_shell_support_echo_command(arguments, shell, diagnostics)
    Some("let") =>
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        effective_command_span(command),
        3039,
        "'let' is",
      )
    Some("set") =>
      check_shell_support_set_command(arguments, shell, diagnostics)
    Some(name) => {
      if name == "local" && !shell_is_dash_family(shell) {
        push_shell_support_diagnostic(
          diagnostics,
          shell,
          effective_command_span(command),
          3043,
          "'local' is",
        )
      }
      if name == "source" && shell != @semantics.ShellDialect::BusyboxSh {
        push_shell_support_diagnostic(
          diagnostics,
          shell,
          effective_command_span(command),
          3051,
          "'source' in place of '.' is",
        )
      }
      if name != "let" && unsupported_shell_support_commands().contains(name) {
        push_shell_support_diagnostic(
          diagnostics,
          shell,
          effective_command_span(command),
          3044,
          "'\{name}' is",
        )
      }
      maybe_push_command_flag_diagnostic(diagnostics, shell, name, arguments)
      if name == "trap" {
        check_shell_support_trap_command(arguments, shell, diagnostics)
      }
      if name == "printf" {
        check_shell_support_printf_command(
          command, arguments, shell, diagnostics,
        )
      }
      if name == "read" {
        check_shell_support_read_command(command, arguments, shell, diagnostics)
      }
    }
    None => ()
  }
}

///|
fn check_shell_support_test_command(
  arguments : Array[@parser.Word],
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match arguments {
    [_, op, _] =>
      match @semantics.literal_text(op) {
        Some(text) =>
          match shell_support_binary_test_rule(text) {
            Some(rule) =>
              maybe_push_shell_support_rule_diagnostic(
                diagnostics,
                shell,
                op.span,
                rule,
              )
            None => ()
          }
        None => ()
      }
    [op, _] =>
      match @semantics.literal_text(op) {
        Some(text) =>
          match shell_support_unary_test_rule(text) {
            Some(rule) =>
              maybe_push_shell_support_rule_diagnostic(
                diagnostics,
                shell,
                op.span,
                rule,
              )
            None => ()
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn check_shell_support_echo_command(
  arguments : Array[@parser.Word],
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match arguments.get(0) {
    Some(argument) =>
      match @semantics.literal_text(argument) {
        Some(text) if shell_support_echo_flag_word(text) =>
          match shell {
            @semantics.ShellDialect::BusyboxSh =>
              if !shell_support_busybox_echo_flag_word(text) {
                push_shell_support_diagnostic(
                  diagnostics,
                  shell,
                  argument.span,
                  3036,
                  "echo flags besides -n and -e",
                )
              }
            @semantics.ShellDialect::Dash =>
              if text != "-n" {
                push_shell_support_diagnostic(
                  diagnostics,
                  shell,
                  argument.span,
                  3036,
                  "echo flags besides -n",
                )
              }
            @semantics.ShellDialect::Sh =>
              push_shell_support_diagnostic(
                diagnostics,
                shell,
                argument.span,
                3037,
                "echo flags are",
              )
            _ => ()
          }
        _ => ()
      }
    None => ()
  }
}

///|
fn check_shell_support_exec_command(
  command : @parser.Command,
  arguments : Array[@parser.Word],
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match arguments.get(0) {
    Some(argument) =>
      match @semantics.literal_text(argument) {
        Some(text) if text.has_prefix("-") && text != "--" =>
          push_shell_support_diagnostic(
            diagnostics,
            shell,
            argument.span,
            3038,
            "exec flags are",
          )
        _ => ()
      }
    None => ()
  }
  ignore(command)
}

///|
fn check_shell_support_set_command(
  arguments : Array[@parser.Word],
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if shell_is_dash_family(shell) {
    return
  }
  let literal_args = shell_support_literal_prefix(arguments)
  let mut i = 0
  while i < literal_args.length() {
    let (flag_word, flag_text) = literal_args[i]
    if shell_support_set_starts_option(flag_text) {
      if flag_text != "--" && flag_text.has_prefix("--") {
        push_shell_support_diagnostic(
          diagnostics,
          shell,
          flag_word.span,
          3042,
          "set flag \{flag_text} is",
        )
        i += 1
        continue
      }
      if shell_support_set_is_o_flag(flag_text) && i + 1 < literal_args.length() {
        let (option_word, option_text) = literal_args[i + 1]
        if !shell_support_set_long_options().contains(option_text) {
          push_shell_support_diagnostic(
            diagnostics,
            shell,
            option_word.span,
            3040,
            "set option \{option_text} is",
          )
        }
      }
      if !shell_support_set_valid_flag_text(flag_text) {
        let view = flag_text[:]
        let mut j = 1
        while j < view.length() {
          let flag = view[j]
          if flag != 'o' &&
            flag != '+' &&
            flag != '-' &&
            !shell_support_set_short_options().contains(uint16_to_string(flag)) {
            push_shell_support_diagnostic(
              diagnostics,
              shell,
              short_flag_span(flag_word, j),
              3041,
              "set flag -\{uint16_to_string(flag)} is",
            )
          }
          j += 1
        }
      }
      i += 1
      continue
    }
    break
  }
}

///|
fn check_shell_support_trap_command(
  arguments : Array[@parser.Word],
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut i = 1
  while i < arguments.length() {
    let token = arguments[i]
    match @semantics.literal_text(token) {
      Some(text) => {
        let upper = upper_ascii_string(text)
        if ["ERR", "DEBUG", "RETURN"].contains(upper) {
          push_shell_support_diagnostic(
            diagnostics,
            shell,
            token.span,
            3047,
            "trapping \{text} is",
          )
        }
        if !shell_is_busybox(shell) && upper.has_prefix("SIG") {
          push_shell_support_diagnostic(
            diagnostics,
            shell,
            token.span,
            3048,
            "prefixing signal names with 'SIG' is",
          )
        }
        if shell == @semantics.ShellDialect::Sh && upper != text {
          push_shell_support_diagnostic(
            diagnostics,
            shell,
            token.span,
            3049,
            "using lower/mixed case for signal names is",
          )
        }
      }
      None => ()
    }
    i += 1
  }
}

///|
fn check_shell_support_printf_command(
  command : @parser.Command,
  arguments : Array[@parser.Word],
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match arguments.get(0) {
    Some(format) =>
      match @semantics.literal_text(format) {
        Some(text) if text.contains("%q") =>
          push_shell_support_diagnostic(
            diagnostics,
            shell,
            format.span,
            3050,
            "printf %q is",
          )
        _ => ()
      }
    None => ()
  }
  ignore(command)
}

///|
fn check_shell_support_read_command(
  command : @parser.Command,
  arguments : Array[@parser.Word],
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if shell_support_read_arguments_are_all_flags(arguments) {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      effective_command_span(command),
      3061,
      "read without a variable is",
    )
  }
}

///|
fn maybe_push_command_flag_diagnostic(
  diagnostics : Array[CheckDiagnostic],
  shell : @semantics.ShellDialect,
  command_name : String,
  arguments : Array[@parser.Word],
) -> Unit {
  match first_unsupported_shell_flag(command_name, arguments, shell) {
    Some((word, offset, flag)) =>
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        short_flag_span(word, offset),
        3045,
        "\{command_name} -\{flag} is",
      )
    None => ()
  }
}

///|
fn check_shell_support_redirection(
  redirect : @parser.Redirection,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match redirect.op {
    @parser.RedirectionOperator::HereString =>
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        redirect_operator_span(redirect),
        3011,
        "here-strings are",
      )
    @parser.RedirectionOperator::DupOutput =>
      if redirect.source is None &&
        redirection_dup_output_targets_filename(redirect) {
        push_shell_support_diagnostic(
          diagnostics,
          shell,
          redirect_operator_span(redirect),
          3021,
          ">& filename (as opposed to >& fd) is",
        )
      }
    _ => ()
  }
  match redirect.source {
    Some(@parser.RedirectionSource::Named(_)) =>
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        redirection_named_source_span(redirect),
        3022,
        "named file descriptors are",
      )
    Some(@parser.RedirectionSource::Fd(fd)) =>
      if fd > 9 {
        push_shell_support_diagnostic(
          diagnostics,
          shell,
          redirection_fd_source_span(redirect, fd),
          3023,
          "FDs outside 0-9 are",
        )
      }
    Some(@parser.RedirectionSource::All) =>
      if redirection_is_write(redirect) &&
        shell != @semantics.ShellDialect::BusyboxSh {
        push_shell_support_diagnostic(
          diagnostics,
          shell,
          redirect_operator_span(redirect),
          3020,
          "&> is",
        )
      }
    None => ()
  }
  match redirect.target {
    @parser.RedirectionTarget::Word(word) => {
      if @semantics.is_glob_word(word) {
        push_shell_support_diagnostic(
          diagnostics,
          shell,
          redirect.span,
          3031,
          "redirecting to/from globs is",
        )
      }
      if shell_support_is_network_redirection(word) {
        push_shell_support_diagnostic(
          diagnostics,
          shell,
          word.span,
          3025,
          "/dev/{tcp,udp} is",
        )
      }
    }
    _ => ()
  }
}

///|
fn assignment_uses_arrays(assignment : @parser.Assignment) -> Bool {
  if assignment.indexes.length() > 0 {
    return true
  }
  assignment_value_uses_arrays(assignment.value)
}

///|
fn assignment_value_uses_arrays(value : @parser.AssignmentValue) -> Bool {
  match value {
    @parser.AssignmentValue::ArrayLiteral(_) => true
    @parser.AssignmentValue::Word(_) | @parser.AssignmentValue::Empty => false
  }
}

///|
fn maybe_push_assignment_append_diagnostic(
  diagnostics : Array[CheckDiagnostic],
  shell : @semantics.ShellDialect,
  assignments : Array[@parser.Assignment],
) -> Unit {
  for assignment in assignments {
    if assignment.append {
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        assignment_name_span(assignment),
        3024,
        "+= is",
      )
      return
    }
  }
}

///|
fn maybe_push_array_assignment_diagnostic(
  diagnostics : Array[CheckDiagnostic],
  shell : @semantics.ShellDialect,
  assignments : Array[@parser.Assignment],
) -> Unit {
  for assignment in assignments {
    if assignment_uses_arrays(assignment) {
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        array_assignment_value_span(assignment),
        3030,
        "arrays are",
      )
      return
    }
  }
}

///|
fn check_shell_support_assignment_extensions(
  assignments : Array[@parser.Assignment],
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell == @semantics.ShellDialect::Bash else { return }
  for assignment in assignments {
    if assignment.name == "PS1" {
      maybe_push_ps1_assignment_diagnostic(assignment, diagnostics)
    }
    if assignment.indexes.length() > 1 {
      push_diagnostic(
        diagnostics,
        assignment_multidimensional_index_span(assignment),
        CheckSeverity::Warning,
        2180,
        "Bash does not support multidimensional arrays. Use 1D or associative arrays.",
      )
    }
    if assignment_value_has_multidimensional_array(assignment.value) {
      push_diagnostic(
        diagnostics,
        array_assignment_value_span(assignment),
        CheckSeverity::Warning,
        2180,
        "Bash does not support multidimensional arrays. Use 1D or associative arrays.",
      )
    }
  }
}

///|
fn maybe_push_ps1_assignment_diagnostic(
  assignment : @parser.Assignment,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match assignment.value {
    @parser.AssignmentValue::Word(word) =>
      if shell_support_contains_unescaped_ps1_escape(word.source) {
        push_diagnostic(
          diagnostics,
          word.span,
          CheckSeverity::Info,
          2025,
          "Make sure all escape sequences are enclosed in \\[..\\] to prevent line wrapping issues",
        )
      }
    _ => ()
  }
}

///|
fn assignment_value_has_multidimensional_array(
  value : @parser.AssignmentValue,
) -> Bool {
  match value {
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      elements.any(fn(element) {
        array_element_has_multidimensional_array(element)
      })
    _ => false
  }
}

///|
fn array_element_has_multidimensional_array(
  element : @parser.ArrayElement,
) -> Bool {
  if element.indexes.length() > 1 {
    return true
  }
  match element.value {
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      elements.any(fn(nested) {
        array_element_has_multidimensional_array(nested)
      })
    _ => false
  }
}

///|
fn check_shell_support_word(
  word : @parser.Word,
  shell : @semantics.ShellDialect,
  assigned_names : Array[String],
  effective_command_name : String?,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut saw_process_substitution = false
  let mut saw_extglob = false
  let mut saw_dollar_double_quoted = false
  let mut saw_dollar_bracket = false
  let mut saw_brace_expansion = false
  let mut saw_glob_caret = false
  let mut saw_dollar_redirection = false
  let mut saw_backquoted_redirection = false
  let mut bash_variable_name : String? = None
  let parameter_codes : Array[Int] = []
  let arithmetic_codes : Array[Int] = []
  walk_word_deep(word, fn(part) {
    match part {
      @parser.WordPart::ProcessSubstitution(_, _) =>
        saw_process_substitution = true
      @parser.WordPart::ExtGlob(_) => saw_extglob = true
      @parser.WordPart::DollarDoubleQuoted(_) => saw_dollar_double_quoted = true
      @parser.WordPart::DollarBracket(expr) => {
        saw_dollar_bracket = true
        collect_shell_support_arithmetic_codes(expr, arithmetic_codes)
        maybe_push_decimal_arithmetic_word_diagnostic(
          word, expr, shell, diagnostics,
        )
      }
      @parser.WordPart::ArithmeticExpansion(expr) => {
        collect_shell_support_arithmetic_codes(expr, arithmetic_codes)
        maybe_push_decimal_arithmetic_word_diagnostic(
          word, expr, shell, diagnostics,
        )
      }
      @parser.WordPart::BraceExpansion(expansion) => {
        saw_brace_expansion = true
        maybe_push_brace_range_variable_diagnostic(
          word, expansion, effective_command_name, shell, diagnostics,
        )
      }
      @parser.WordPart::Glob(raw) =>
        if raw.contains("[^") {
          saw_glob_caret = true
        }
      @parser.WordPart::CommandSubstitution(script)
      | @parser.WordPart::BraceCommandSubstitution(_, script) => {
        check_shell_support_substitution_script(script, shell, diagnostics)
        if script_is_only_redirection(script) {
          saw_dollar_redirection = true
        }
      }
      @parser.WordPart::BackQuoted(script) => {
        check_shell_support_substitution_script(script, shell, diagnostics)
        if script_is_only_redirection(script) {
          saw_backquoted_redirection = true
        }
      }
      @parser.WordPart::Parameter(name)
      | @parser.WordPart::SpecialParameter(name) =>
        if bash_variable_name is None &&
          shell_support_is_bash_variable(name, shell, assigned_names) {
          bash_variable_name = Some(name)
        }
      @parser.WordPart::BracedParameter(expansion) => {
        collect_parameter_expansion_codes(expansion, shell, parameter_codes)
        maybe_push_multidimensional_parameter_diagnostic(
          word, expansion, shell, diagnostics,
        )
        match expansion.name {
          Some(name) =>
            if bash_variable_name is None &&
              shell_support_is_bash_variable(name, shell, assigned_names) {
              bash_variable_name = Some(name)
            }
          None => ()
        }
      }
      _ => ()
    }
  })
  if saw_process_substitution {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      word.span,
      3001,
      "process substitution is",
    )
  }
  if saw_extglob {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      word.span,
      3002,
      "extglob is",
    )
  }
  if saw_dollar_double_quoted {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      word.span,
      3004,
      "$\"..\" is",
    )
  }
  if saw_dollar_bracket {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      word.span,
      3007,
      "$[..] in place of $((..)) is",
    )
  }
  if saw_brace_expansion {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      word.span,
      3009,
      "brace expansion is",
    )
  }
  if saw_glob_caret {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      word.span,
      3026,
      "^ in place of ! in glob bracket expressions is",
    )
  }
  match bash_variable_name {
    Some(name) =>
      push_shell_support_diagnostic(
        diagnostics,
        shell,
        word.span,
        3028,
        "\{name} is",
      )
    None => ()
  }
  if saw_dollar_redirection {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      word.span,
      3034,
      "$(<file) to read files is",
    )
  }
  if saw_backquoted_redirection {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      word.span,
      3035,
      "`<file` to read files is",
    )
  }
  for code in parameter_codes {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      word.span,
      code,
      shell_support_feature_name(code),
    )
  }
  for code in arithmetic_codes {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      word.span,
      code,
      shell_support_feature_name(code),
    )
  }
}

///|
fn maybe_push_decimal_arithmetic_command_diagnostic(
  command : @parser.Command,
  expr : @parser.ArithmeticExpr,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell != @semantics.ShellDialect::Ksh else { return }
  match first_decimal_arithmetic_literal(expr) {
    Some(literal) =>
      match string_offset(expr.raw, literal) {
        Some(offset) =>
          push_diagnostic(
            diagnostics,
            span_offset(command.span, offset + 2, literal.length()),
            CheckSeverity::Error,
            2079,
            "(( )) doesn't support decimals. Use bc or awk.",
          )
        None => ()
      }
    None => ()
  }
}

///|
fn maybe_push_decimal_arithmetic_word_diagnostic(
  word : @parser.Word,
  expr : @parser.ArithmeticExpr,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell != @semantics.ShellDialect::Ksh else { return }
  match first_decimal_arithmetic_literal(expr) {
    Some(literal) =>
      push_diagnostic(
        diagnostics,
        span_for_nested_word_text(word, expr.raw, literal),
        CheckSeverity::Error,
        2079,
        "(( )) doesn't support decimals. Use bc or awk.",
      )
    None => ()
  }
}

///|
fn maybe_push_brace_range_variable_diagnostic(
  word : @parser.Word,
  expansion : @parser.BraceExpansion,
  effective_command_name : String?,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell == @semantics.ShellDialect::Bash else { return }
  guard brace_expansion_uses_variable_range(expansion) else { return }
  let span = span_for_word_text(word, expansion.raw)
  match effective_command_name {
    Some("eval") =>
      push_diagnostic(
        diagnostics,
        span,
        CheckSeverity::Style,
        2175,
        "Quote this invalid brace expansion since it should be passed literally to eval.",
      )
    _ =>
      push_diagnostic(
        diagnostics,
        span,
        CheckSeverity::Warning,
        2051,
        "Bash doesn't support variables in brace range expansions.",
      )
  }
}

///|
fn maybe_push_multidimensional_parameter_diagnostic(
  word : @parser.Word,
  expansion : @parser.ParameterExpansion,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell == @semantics.ShellDialect::Bash else { return }
  if expansion.raw.contains("][") {
    push_diagnostic(
      diagnostics,
      span_for_word_text(word, "${" + expansion.raw + "}"),
      CheckSeverity::Warning,
      2180,
      "Bash does not support multidimensional arrays. Use 1D or associative arrays.",
    )
  }
}

///|
fn check_shell_support_negated_unary_ops(
  command : @parser.Command,
  condition : @parser.ConditionCommand,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell == @semantics.ShellDialect::Bash else { return }
  match condition.kind {
    @parser.ConditionKind::SingleBracket => ()
    _ => return
  }
  match condition.expr {
    @parser.ConditionExpr::Not(inner) =>
      match inner {
        @parser.ConditionExpr::Unary(op, _, _) =>
          if op == "-a" || op == "-o" {
            push_diagnostic(
              diagnostics,
              single_bracket_negation_span(command, condition.raw),
              CheckSeverity::Error,
              2332,
              negated_unary_ops_message(op),
            )
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn negated_unary_ops_message(op : String) -> String {
  match op {
    "-o" =>
      "[ ! -o opt ] is always true because -o becomes logical OR. Use [[ ]] or ! [ -o opt ]."
    "-a" =>
      "[ ! -a file ] is always true because -a becomes logical AND. Use -e instead."
    _ => "[ ! -a/-o ... ] is always true."
  }
}

///|
fn check_shell_support_substitution_script(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_pipelines(script, fn(pipeline) {
    check_shell_support_echo_sed_pipeline(pipeline, shell, diagnostics)
  })
}

///|
fn collect_parameter_expansion_codes(
  expansion : @parser.ParameterExpansion,
  shell : @semantics.ShellDialect,
  codes : Array[Int],
) -> Unit {
  if expansion.indirect {
    if parameter_index_is(expansion, "@") || parameter_index_is(expansion, "*") {
      push_unique_code(codes, 3053)
      push_unique_code(codes, 3055)
      return
    }
    if parameter_has_names_operator(expansion) {
      push_unique_code(codes, 3053)
      push_unique_code(codes, 3056)
      return
    }
    push_unique_code(codes, 3053)
    return
  }
  if shell_support_uses_star_at_string_operation(expansion) {
    push_unique_code(codes, 3058)
  }
  if !expansion.length_prefix && parameter_has_index(expansion) {
    push_unique_code(codes, 3054)
  }
  match expansion.operator {
    Some(@parser.ParameterOperator::Slice(_, _)) =>
      if shell != @semantics.ShellDialect::BusyboxSh {
        push_unique_code(codes, 3057)
      }
    Some(@parser.ParameterOperator::Replace(_, _, _)) =>
      if shell != @semantics.ShellDialect::BusyboxSh {
        push_unique_code(codes, 3060)
      }
    Some(@parser.ParameterOperator::CaseModify(_, _)) =>
      push_unique_code(codes, 3059)
    _ => ()
  }
}

///|
fn collect_shell_support_arithmetic_codes(
  expr : @parser.ArithmeticExpr,
  codes : Array[Int],
) -> Unit {
  if expr.raw.contains("++") || expr.raw.contains("--") {
    push_unique_code(codes, 3018)
  }
  if expr.raw.contains("**") {
    push_unique_code(codes, 3019)
  }
  for token in expr.tokens {
    match token {
      @parser.ArithmeticToken::Literal(text) =>
        if shell_support_is_arithmetic_base_prefix(text) {
          push_unique_code(codes, 3052)
        }
      @parser.ArithmeticToken::Group(inner) =>
        collect_shell_support_arithmetic_codes(inner, codes)
      _ => ()
    }
  }
}

///|
fn check_shell_support_arithmetic_expr(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let codes : Array[Int] = []
  collect_shell_support_arithmetic_codes(expr, codes)
  for code in codes {
    push_shell_support_diagnostic(
      diagnostics,
      shell,
      span,
      code,
      shell_support_feature_name(code),
    )
  }
}

///|
fn check_shell_support_condition_expr(
  expr : @parser.ConditionExpr,
  span : @parser.Span,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match expr {
    @parser.ConditionExpr::Unary(op, _, _) =>
      match shell_support_unary_test_rule(op) {
        Some(rule) =>
          maybe_push_shell_support_rule_diagnostic(
            diagnostics, shell, span, rule,
          )
        None => ()
      }
    @parser.ConditionExpr::Binary(op, _, _, _) =>
      match shell_support_binary_test_rule(op) {
        Some(rule) =>
          maybe_push_shell_support_rule_diagnostic(
            diagnostics, shell, span, rule,
          )
        None => ()
      }
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      check_shell_support_condition_expr(inner, span, shell, diagnostics)
    @parser.ConditionExpr::And(lhs, rhs)
    | @parser.ConditionExpr::Or(lhs, rhs) => {
      check_shell_support_condition_expr(lhs, span, shell, diagnostics)
      check_shell_support_condition_expr(rhs, span, shell, diagnostics)
    }
    _ => ()
  }
}

///|
fn shell_support_binary_test_rule(op : String) -> ShellSupportRule? {
  match op {
    "<" | ">" | "\\<" | "\\>" | "<=" | ">=" | "\\<=" | "\\>=" =>
      Some({
        code: 3012,
        feature: "lexicographical \{op} is",
        exempt_shells: [
          @semantics.ShellDialect::Dash,
          @semantics.ShellDialect::BusyboxSh,
        ],
      })
    "==" =>
      Some({
        code: 3014,
        feature: "\{op} in place of = is",
        exempt_shells: [@semantics.ShellDialect::BusyboxSh],
      })
    "=~" =>
      Some({ code: 3015, feature: "\{op} regex matching is", exempt_shells: [] })
    _ => None
  }
}

///|
fn shell_support_unary_test_rule(op : String) -> ShellSupportRule? {
  match op {
    "-v" =>
      Some({
        code: 3016,
        feature: "test \{op} (in place of [ -n \"${var+x}\" ]) is",
        exempt_shells: [],
      })
    "-a" =>
      Some({
        code: 3017,
        feature: "unary \{op} in place of -e is",
        exempt_shells: [],
      })
    "-o" =>
      Some({
        code: 3062,
        feature: "test \{op} to check options is",
        exempt_shells: [],
      })
    "-R" =>
      Some({
        code: 3063,
        feature: "test \{op} and namerefs in general are",
        exempt_shells: [],
      })
    "-N" => Some({ code: 3064, feature: "test \{op} is", exempt_shells: [] })
    "-k" =>
      Some({
        code: 3065,
        feature: "test \{op} is",
        exempt_shells: [
          @semantics.ShellDialect::Dash,
          @semantics.ShellDialect::BusyboxSh,
        ],
      })
    "-G" =>
      Some({
        code: 3066,
        feature: "test \{op} is",
        exempt_shells: [
          @semantics.ShellDialect::Dash,
          @semantics.ShellDialect::BusyboxSh,
        ],
      })
    "-O" =>
      Some({
        code: 3067,
        feature: "test \{op} is",
        exempt_shells: [
          @semantics.ShellDialect::Dash,
          @semantics.ShellDialect::BusyboxSh,
        ],
      })
    _ => None
  }
}

///|
fn first_unsupported_shell_flag(
  command_name : String,
  arguments : Array[@parser.Word],
  shell : @semantics.ShellDialect,
) -> (@parser.Word, Int, String)? {
  let allowed = match shell_support_allowed_flags(command_name, shell) {
    Some(allowed) => allowed
    None => return None
  }
  let mut i = 0
  while i < arguments.length() {
    let word = arguments[i]
    let text = match @semantics.literal_text(word) {
      Some(text) => text
      None => return None
    }
    if text == "--" {
      return None
    }
    if !text.has_prefix("-") || text == "-" || text.has_prefix("--") {
      return None
    }
    let view = text[:]
    let mut j = 1
    while j < view.length() {
      let flag = uint16_to_string(view[j])
      if !allowed.contains(flag) {
        return Some((word, j, flag))
      }
      if shell_support_command_flag_takes_argument(command_name, view[j]) {
        if j + 1 == view.length() {
          i += 1
        }
        break
      }
      j += 1
    }
    i += 1
  }
  None
}

///|
fn shell_support_allowed_flags(
  command_name : String,
  shell : @semantics.ShellDialect,
) -> Array[String]? {
  match command_name {
    "cd" => Some(["L", "P"])
    "exec" => Some([])
    "export" => Some(["p"])
    "hash" => Some(if shell_is_dash_family(shell) { ["r", "v"] } else { ["r"] })
    "jobs" => Some(["l", "p"])
    "printf" => Some([])
    "read" => Some(if shell_is_dash_family(shell) { ["r", "p"] } else { ["r"] })
    "readonly" => Some(["p"])
    "trap" => Some([])
    "type" =>
      Some(if shell == @semantics.ShellDialect::BusyboxSh { ["p"] } else { [] })
    "ulimit" =>
      Some(
        if shell_is_dash_family(shell) {
          [
            "H", "S", "a", "c", "d", "f", "l", "m", "n", "p", "r", "s", "t", "v",
            "w",
          ]
        } else {
          ["H", "S", "a", "c", "d", "f", "n", "s", "t", "v"]
        },
      )
    "umask" => Some(["S"])
    "unset" => Some(["f", "v"])
    "wait" => Some([])
    _ => None
  }
}

///|
fn shell_support_command_flag_takes_argument(
  command_name : String,
  flag : UInt16,
) -> Bool {
  command_name == "read" && @semantics.read_flag_takes_argument(flag)
}

///|
fn shell_support_read_arguments_are_all_flags(
  arguments : Array[@parser.Word],
) -> Bool {
  for argument in arguments {
    if !@semantics.is_unquoted_flag(argument) {
      return false
    }
  }
  true
}

///|
fn shell_support_literal_prefix(
  arguments : Array[@parser.Word],
) -> Array[(@parser.Word, String)] {
  let literal_args : Array[(@parser.Word, String)] = []
  for argument in arguments {
    match @semantics.literal_text(argument) {
      Some(text) => literal_args.push((argument, text))
      None => break
    }
  }
  literal_args
}

///|
// CHECK THIS: THUNK
fn shell_support_set_short_options() -> Array[String] {
  ["a", "b", "C", "e", "f", "h", "m", "n", "u", "v", "x", "o"]
}

///|
// CHECK THIS: THUNK
fn shell_support_set_long_options() -> Array[String] {
  [
    "allexport", "errexit", "ignoreeof", "monitor", "noclobber", "noexec", "noglob",
    "nolog", "notify", "nounset", "pipefail", "verbose", "vi", "xtrace",
  ]
}

///|
fn shell_support_set_starts_option(text : String) -> Bool {
  (text.has_prefix("-") || text.has_prefix("+")) && text != "-" && text != "+"
}

///|
fn shell_support_set_is_o_flag(text : String) -> Bool {
  let view = text[:]
  if view.length() < 2 {
    return false
  }
  view[view.length() - 1] == 'o' &&
  (text.has_prefix("-") || text.has_prefix("+")) &&
  !text.has_prefix("--")
}

///|
fn shell_support_set_valid_flag_text(text : String) -> Bool {
  if text == "-o" || text == "+o" {
    return true
  }
  if !shell_support_set_starts_option(text) || text.has_prefix("--") {
    return false
  }
  let view = text[:]
  let mut i = 1
  while i < view.length() {
    let flag = view[i]
    if flag == 'o' {
      i += 1
      continue
    }
    if !shell_support_set_short_options().contains(uint16_to_string(flag)) {
      return false
    }
    i += 1
  }
  true
}

///|
fn script_is_only_redirection(script : @parser.Script) -> Bool {
  match first_command_in_script(script) {
    Some(command) =>
      script.items.length() == 1 &&
      script.items[0].and_or.tail.length() == 0 &&
      script.items[0].and_or.head.operators.length() == 0 &&
      script.items[0].and_or.head.segments.length() == 1 &&
      command_is_only_redirection(command)
    None => false
  }
}

///|
fn command_is_only_redirection(command : @parser.Command) -> Bool {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      simple.assignments.length() == 0 &&
      simple.words.length() == 0 &&
      command.redirects.length() > 0
    _ => false
  }
}

///|
fn shell_support_is_network_redirection(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some(text) => text.has_prefix("/dev/tcp") || text.has_prefix("/dev/udp")
    None => false
  }
}

///|
fn redirection_dup_output_targets_filename(
  redirect : @parser.Redirection,
) -> Bool {
  match redirect.target {
    @parser.RedirectionTarget::Word(word) =>
      match @semantics.literal_text(word) {
        Some(text) => !shell_support_string_is_digits(text)
        None => !word_is_bare_fd_reference(word)
      }
    _ => false
  }
}

///|
fn word_is_bare_fd_reference(word : @parser.Word) -> Bool {
  match word.parts {
    [@parser.WordPart::Parameter(_)]
    | [@parser.WordPart::SpecialParameter(_)] => true
    [@parser.WordPart::BracedParameter(expansion)] =>
      expansion.name is Some(_) &&
      expansion.operator is None &&
      !expansion.indirect &&
      !expansion.length_prefix &&
      expansion.index is None
    _ => false
  }
}

///|
fn shell_support_uses_star_at_string_operation(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  let is_star_at = match expansion.name {
    Some("@") | Some("*") => true
    _ => false
  }
  if !is_star_at {
    return false
  }
  if expansion.length_prefix {
    return true
  }
  match expansion.operator {
    Some(@parser.ParameterOperator::RemoveShortestPrefix(_))
    | Some(@parser.ParameterOperator::RemoveLongestPrefix(_))
    | Some(@parser.ParameterOperator::RemoveShortestSuffix(_))
    | Some(@parser.ParameterOperator::RemoveLongestSuffix(_)) => true
    _ => false
  }
}

///|
fn shell_support_is_bash_variable(
  name : String,
  shell : @semantics.ShellDialect,
  assigned_names : Array[String],
) -> Bool {
  if shell_is_dash_family(shell) && name == "_" {
    return false
  }
  if shell_support_bash_dynamic_variables().contains(name) {
    return true
  }
  shell_support_bash_variables().contains(name) &&
  !assigned_names.contains(name)
}

///|
// CHECK THIS: THUNK
fn shell_support_bash_variables() -> Array[String] {
  [
    "OSTYPE", "MACHTYPE", "HOSTTYPE", "HOSTNAME", "DIRSTACK", "EUID", "UID", "SHLVL",
    "PIPESTATUS", "SHELLOPTS", "_", "BASH", "BASHOPTS", "BASHPID", "BASH_ALIASES",
    "BASH_ARGC", "BASH_ARGV", "BASH_ARGV0", "BASH_CMDS", "BASH_COMMAND", "BASH_EXECUTION_STRING",
    "BASH_LINENO", "BASH_LOADABLES_PATH", "BASH_REMATCH", "BASH_SOURCE", "BASH_SUBSHELL",
    "BASH_VERSINFO", "COMP_CWORD", "COMP_KEY", "COMP_LINE", "COMP_POINT", "COMP_TYPE",
    "COMP_WORDBREAKS", "COMP_WORDS", "COPROC", "FUNCNAME", "GROUPS", "HISTCMD", "MAPFILE",
  ]
}

///|
// CHECK THIS: THUNK
fn shell_support_bash_dynamic_variables() -> Array[String] {
  [
    "BASH_MONOSECONDS", "EPOCHREALTIME", "EPOCHSECONDS", "RANDOM", "SECONDS", "SRANDOM",
  ]
}

///|
// CHECK THIS: THUNK
fn unsupported_shell_support_commands() -> Array[String] {
  [
    "caller", "builtin", "complete", "compgen", "declare", "dirs", "disown", "enable",
    "mapfile", "readarray", "pushd", "popd", "shopt", "suspend", "typeset",
  ]
}

///|
fn shell_support_is_function_name(name : String) -> Bool {
  let view = name[:]
  if view.length() == 0 || !shell_support_is_ascii_name_start(view[0]) {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if !shell_support_is_ascii_name_part(view[i]) {
      return false
    }
    i += 1
  }
  true
}

///|
fn shell_support_echo_flag_word(text : String) -> Bool {
  let view = text[:]
  if view.length() < 2 || view[0] != '-' {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if !["e", "E", "s", "n"].contains(uint16_to_string(view[i])) {
      return false
    }
    i += 1
  }
  true
}

///|
fn shell_support_busybox_echo_flag_word(text : String) -> Bool {
  let view = text[:]
  if view.length() < 2 || view[0] != '-' {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if !["e", "n"].contains(uint16_to_string(view[i])) {
      return false
    }
    i += 1
  }
  true
}

///|
fn word_is_plain_variable_reference(word : @parser.Word) -> Bool {
  match word.parts {
    [@parser.WordPart::Parameter(_)] => true
    [@parser.WordPart::BracedParameter(expansion)] =>
      braced_parameter_is_plain_reference(expansion)
    [@parser.WordPart::DoubleQuoted(parts)] =>
      quoted_parts_are_plain_variable_reference(parts)
    _ => false
  }
}

///|
fn quoted_parts_are_plain_variable_reference(
  parts : Array[@parser.WordPart],
) -> Bool {
  match parts {
    [@parser.WordPart::Parameter(_)] => true
    [@parser.WordPart::BracedParameter(expansion)] =>
      braced_parameter_is_plain_reference(expansion)
    _ => false
  }
}

///|
fn braced_parameter_is_plain_reference(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  expansion.name is Some(_) &&
  !expansion.length_prefix &&
  !expansion.indirect &&
  expansion.index is None &&
  expansion.operator is None
}

///|
fn brace_expansion_uses_variable_range(
  expansion : @parser.BraceExpansion,
) -> Bool {
  expansion.elements.any(fn(element) {
    element.source.contains("$..") || element.source.contains("..$")
  })
}

///|
fn first_decimal_arithmetic_literal(expr : @parser.ArithmeticExpr) -> String? {
  let mut i = 0
  while i < expr.tokens.length() {
    match expr.tokens[i] {
      @parser.ArithmeticToken::Literal(text) =>
        if shell_support_is_decimal_arithmetic_literal(text) {
          return Some(text)
        } else if i + 2 < expr.tokens.length() {
          match (expr.tokens[i + 1], expr.tokens[i + 2]) {
            (
              @parser.ArithmeticToken::Literal(dot),
              @parser.ArithmeticToken::Literal(fraction),
            ) =>
              if dot == "." && shell_support_is_decimal_pair(text, fraction) {
                return Some(text + "." + fraction)
              }
            _ => ()
          }
        }
      @parser.ArithmeticToken::Group(inner) =>
        match first_decimal_arithmetic_literal(inner) {
          Some(literal) => return Some(literal)
          None => ()
        }
      _ => ()
    }
    i += 1
  }
  None
}

///|
fn shell_support_is_decimal_arithmetic_literal(text : String) -> Bool {
  let view = text[:]
  if view.length() < 2 || !shell_support_is_ascii_digit(view[0]) {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if view[i] == '.' {
      return true
    }
    i += 1
  }
  false
}

///|
fn shell_support_is_decimal_pair(integer : String, fraction : String) -> Bool {
  let view = integer[:]
  if view.length() == 0 || !shell_support_is_ascii_digit(view[0]) {
    return false
  }
  shell_support_string_is_digits(fraction)
}

///|
fn shell_support_contains_unescaped_ps1_escape(text : String) -> Bool {
  let stripped = strip_ps1_prompt_enclosures(text)
  stripped.contains("\\x1B") ||
  stripped.contains("\\x1b") ||
  stripped.contains("\\e") ||
  stripped.contains("\\033") ||
  stripped.contains("\u001B")
}

///|
fn strip_ps1_prompt_enclosures(text : String) -> String {
  let view = text[:]
  let buf = StringBuilder::new()
  let mut i = 0
  while i < view.length() {
    if i + 1 < view.length() && view[i] == '\\' && view[i + 1] == '[' {
      i += 2
      while i < view.length() {
        if i + 1 < view.length() && view[i] == '\\' && view[i + 1] == ']' {
          i += 2
          break
        }
        i += 1
      }
      continue
    }
    buf.write_char(view[i].unsafe_to_char())
    i += 1
  }
  buf.to_string()
}

///|
fn string_offset(text : String, needle : String) -> Int? {
  let view = text[:]
  let needle_view = needle[:]
  if needle_view.length() == 0 {
    return Some(0)
  }
  let mut i = 0
  while i + needle_view.length() <= view.length() {
    let mut j = 0
    while j < needle_view.length() && view[i + j] == needle_view[j] {
      j += 1
    }
    if j == needle_view.length() {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn span_for_word_text(word : @parser.Word, text : String) -> @parser.Span {
  match string_offset(word.source, text) {
    Some(offset) => span_offset(word.span, offset, text.length())
    None => word.span
  }
}

///|
fn span_for_nested_word_text(
  word : @parser.Word,
  outer : String,
  inner : String,
) -> @parser.Span {
  match string_offset(word.source, outer) {
    Some(outer_offset) =>
      match string_offset(outer, inner) {
        Some(inner_offset) =>
          span_offset(word.span, outer_offset + inner_offset, inner.length())
        None => word.span
      }
    None => word.span
  }
}

///|
fn single_bracket_negation_span(
  command : @parser.Command,
  raw : String,
) -> @parser.Span {
  let offset = match string_offset(raw, "!") {
    Some(offset) => offset + 2
    None => 2
  }
  span_offset(command.span, offset, 1)
}

///|
fn assignment_multidimensional_index_span(
  assignment : @parser.Assignment,
) -> @parser.Span {
  if assignment.indexes.length() < 2 {
    return assignment.span
  }
  let mut offset = assignment.name[:].length()
  let mut i = 0
  while i < 1 {
    offset += assignment.indexes[i].raw[:].length() + 2
    i += 1
  }
  let second = assignment.indexes[1]
  let width = if second.raw[:].length() == 0 {
    1
  } else {
    second.raw[:].length()
  }
  span_offset(assignment.span, offset + 1, width)
}

///|
fn span_offset(span : @parser.Span, offset : Int, width : Int) -> @parser.Span {
  @parser.Span::new(
    @parser.Position::new(
      span.start.offset + offset,
      span.start.line,
      span.start.column + offset,
    ),
    @parser.Position::new(
      span.start.offset + offset + width,
      span.start.line,
      span.start.column + offset + width,
    ),
  )
}

///|
fn shell_support_is_arithmetic_base_prefix(text : String) -> Bool {
  let view = text[:]
  let mut i = 0
  while i < view.length() && shell_support_is_ascii_digit(view[i]) {
    i += 1
  }
  i > 0 && i < view.length() && view[i] == '#'
}

///|
fn command_name_span(command : @parser.Command) -> @parser.Span {
  match @semantics.command_words(command).get(0) {
    Some(word) => word.span
    None => command.span
  }
}

///|
fn redirection_named_source_span(
  redirect : @parser.Redirection,
) -> @parser.Span {
  match redirect.source {
    Some(@parser.RedirectionSource::Named(name)) =>
      span_prefix(redirect.span, name[:].length() + 2)
    _ => redirect_operator_span(redirect)
  }
}

///|
fn redirection_fd_source_span(
  redirect : @parser.Redirection,
  fd : Int,
) -> @parser.Span {
  span_prefix(redirect.span, int_digit_width(fd))
}

///|
fn redirection_is_write(redirect : @parser.Redirection) -> Bool {
  match redirect.op {
    @parser.RedirectionOperator::Write => true
    _ => false
  }
}

///|
fn short_flag_span(word : @parser.Word, offset : Int) -> @parser.Span {
  @parser.Span::new(
    @parser.Position::new(
      word.span.start.offset + offset,
      word.span.start.line,
      word.span.start.column + offset,
    ),
    @parser.Position::new(
      word.span.start.offset + offset + 1,
      word.span.start.line,
      word.span.start.column + offset + 1,
    ),
  )
}

///|
fn maybe_push_shell_support_rule_diagnostic(
  diagnostics : Array[CheckDiagnostic],
  shell : @semantics.ShellDialect,
  span : @parser.Span,
  rule : ShellSupportRule,
) -> Unit {
  if shell_is_one_of(shell, rule.exempt_shells) {
    return
  }
  push_shell_support_diagnostic(
    diagnostics,
    shell,
    span,
    rule.code,
    rule.feature,
  )
}

///|
fn push_unique_code(codes : Array[Int], code : Int) -> Unit {
  if !codes.contains(code) {
    codes.push(code)
  }
}

///|
fn shell_support_push_unique_string(
  values : Array[String],
  value : String,
) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
fn shell_support_feature_name(code : Int) -> String {
  match code {
    3018 => "++/-- is"
    3019 => "exponentials are"
    3052 => "arithmetic base conversion is"
    3053 => "indirect expansion is"
    3054 => "array references are"
    3055 => "array key expansion is"
    3056 => "name matching prefixes are"
    3057 => "string indexing is"
    3058 => "string operations on $@/$* are"
    3059 => "case modification is"
    3060 => "string replacement is"
    _ => "this feature is"
  }
}

///|
fn shell_is_dash_family(shell : @semantics.ShellDialect) -> Bool {
  shell == @semantics.ShellDialect::Dash ||
  shell == @semantics.ShellDialect::BusyboxSh
}

///|
fn shell_is_busybox(shell : @semantics.ShellDialect) -> Bool {
  shell == @semantics.ShellDialect::BusyboxSh
}

///|
fn int_digit_width(value : Int) -> Int {
  if value < 10 {
    return 1
  }
  let mut width = 0
  let mut current = value
  while current > 0 {
    current = current / 10
    width += 1
  }
  width
}

///|
fn shell_support_string_is_digits(text : String) -> Bool {
  let view = text[:]
  if view.length() == 0 {
    return false
  }
  let mut i = 0
  while i < view.length() {
    if !shell_support_is_ascii_digit(view[i]) {
      return false
    }
    i += 1
  }
  true
}

///|
fn upper_ascii_string(text : String) -> String {
  let buf = StringBuilder::new()
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    let char_ = ch.unsafe_to_char()
    if 'a' <= char_ && char_ <= 'z' {
      buf.write_char((ch - 32).unsafe_to_char())
    } else {
      buf.write_char(char_)
    }
    i += 1
  }
  buf.to_string()
}

///|
fn shell_support_is_ascii_name_start(ch : UInt16) -> Bool {
  ('a' <= ch.unsafe_to_char() && ch.unsafe_to_char() <= 'z') ||
  ('A' <= ch.unsafe_to_char() && ch.unsafe_to_char() <= 'Z') ||
  ch.unsafe_to_char() == '_'
}

///|
fn shell_support_is_ascii_name_part(ch : UInt16) -> Bool {
  shell_support_is_ascii_name_start(ch) || shell_support_is_ascii_digit(ch)
}

///|
fn shell_support_is_ascii_digit(ch : UInt16) -> Bool {
  '0' <= ch.unsafe_to_char() && ch.unsafe_to_char() <= '9'
}

///|
fn push_shell_support_diagnostic(
  diagnostics : Array[CheckDiagnostic],
  shell : @semantics.ShellDialect,
  span : @parser.Span,
  code : Int,
  feature : String,
) -> Unit {
  match shell {
    @semantics.ShellDialect::Dash | @semantics.ShellDialect::BusyboxSh =>
      push_diagnostic(
        diagnostics,
        span,
        CheckSeverity::Error,
        code,
        "In dash, \{feature} not supported.",
      )
    @semantics.ShellDialect::Sh =>
      push_diagnostic(
        diagnostics,
        span,
        CheckSeverity::Warning,
        code,
        "In POSIX sh, \{feature} undefined.",
      )
    _ => ()
  }
}
