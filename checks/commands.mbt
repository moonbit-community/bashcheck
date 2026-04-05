///|
fn commands_descriptions() -> Array[CheckDescription] {
  let descriptions = [
    {
      code: 2005,
      severity: CheckSeverity::Style,
      category: "commands",
      summary: "Use the command directly instead of echoing its substitution.",
    },
    {
      code: 2023,
      severity: CheckSeverity::Info,
      category: "commands",
      summary: "Use command time if you need the external utility's flags.",
    },
    {
      code: 2024,
      severity: CheckSeverity::Warning,
      category: "commands",
      summary: "sudo doesn't affect redirects; use tee/cat patterns instead.",
    },
    {
      code: 2185,
      severity: CheckSeverity::Info,
      category: "commands",
      summary: "Some finds don't have a default path. Specify '.' explicitly.",
    },
    {
      code: 2162,
      severity: CheckSeverity::Info,
      category: "commands",
      summary: "read without -r will mangle backslashes.",
    },
    {
      code: 2186,
      severity: CheckSeverity::Warning,
      category: "commands",
      summary: "tempfile is deprecated. Use mktemp instead.",
    },
    {
      code: 2196,
      severity: CheckSeverity::Info,
      category: "commands",
      summary: "egrep is non-standard and deprecated. Use grep -E instead.",
    },
    {
      code: 2197,
      severity: CheckSeverity::Info,
      category: "commands",
      summary: "fgrep is non-standard and deprecated. Use grep -F instead.",
    },
  ]
  append_commands_batch_a_descriptions(descriptions)
  append_commands_batch_b_descriptions(descriptions)
  append_commands_batch_c_descriptions(descriptions)
  descriptions
}

///|
fn commands_suite() -> CheckSuiteRegistration {
  { descriptions: commands_descriptions(), run: run_command_checks }
}

///|
fn commands_optional_registrations() -> Array[OptionalCheckRegistration] {
  [
    {
      info: {
        name: "deprecate-which",
        desc: "Suggest 'command -v' instead of 'which'",
        example: "which javac",
        fix: "command -v javac",
      },
      description: {
        code: 2230,
        severity: CheckSeverity::Info,
        category: "commands",
        summary: "'which' is non-standard. Use builtin 'command -v' instead.",
      },
      run: run_deprecate_which_optional_check,
    },
  ]
}

///|
fn run_deprecate_which_optional_check(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_deprecate_which(script, diagnostics)
}

///|
fn run_command_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_time_parameters(script, shell, diagnostics)
  check_useless_echo_command_substitution(script, diagnostics)
  check_tr_arguments(script, diagnostics)
  check_find_without_path(script, diagnostics)
  check_find_name_globs(script, diagnostics)
  check_find_exec_single_argument(script, diagnostics)
  check_injectable_find_sh(script, diagnostics)
  check_find_action_precedence(script, diagnostics)
  check_find_redirections(script, diagnostics)
  check_expr_usage(script, diagnostics)
  check_grep_patterns(script, diagnostics)
  check_trap_quotes(script, diagnostics)
  check_return_status_values(script, diagnostics)
  check_exit_status_values(script, diagnostics)
  check_printf_arguments(script, diagnostics)
  check_source_arguments(script, shell, diagnostics)
  check_read_without_r(script, diagnostics)
  check_read_expansions(script, diagnostics)
  check_aliases_use_args(script, diagnostics)
  check_aliases_expand_early(script, diagnostics)
  check_while_getopts_case(script, diagnostics)
  check_let_usage(script, shell, diagnostics)
  check_mv_arguments(script, diagnostics)
  check_cp_arguments(script, diagnostics)
  check_ln_arguments(script, diagnostics)
  check_chmod_dash_r(script, diagnostics)
  check_xargs_dash_i(script, diagnostics)
  check_argument_comparison_spacing(script, diagnostics)
  check_eval_array(script, diagnostics)
  run_commands_batch_c_checks(script, shell, diagnostics)
  check_deprecated_tempfile(script, diagnostics)
  check_deprecated_grep_variants(script, diagnostics)
  check_sudo_redirects(script, diagnostics)
  check_sudo_arguments(script, diagnostics)
}

///|
fn check_time_parameters(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell_is_one_of(shell, [
    @semantics.ShellDialect::Bash,
    @semantics.ShellDialect::Sh,
  ]) else {
    return
  }
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Time(clause) =>
        match clause.flags.get(0) {
          Some(flag) =>
            match @semantics.literal_text(flag) {
              Some(text) if text.has_prefix("-") && text != "-p" =>
                push_diagnostic(
                  diagnostics,
                  command_keyword_span(command, "time"),
                  CheckSeverity::Info,
                  2023,
                  "The shell may override 'time' as seen in man time(1). Use 'command time ..' for that one.",
                )
              _ => ()
            }
          None => ()
        }
      _ => ()
    }
  })
}

///|
fn check_useless_echo_command_substitution(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_exact_name(command, "echo") {
      return
    }
    match @semantics.effective_command_arguments(command) {
      [argument] if word_is_just_command_output(argument) =>
        push_diagnostic(
          diagnostics,
          argument.span,
          CheckSeverity::Style,
          2005,
          "Useless echo? Instead of 'echo $(cmd)', just use 'cmd'.",
        )
      _ => ()
    }
  })
}

///|
fn check_find_without_path(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "find") {
      return
    }
    let arguments = @semantics.effective_command_arguments(command)
    if find_has_help_flag(arguments) || find_has_path_argument(arguments) {
      return
    }
    push_diagnostic(
      diagnostics,
      effective_command_span(command),
      CheckSeverity::Info,
      2185,
      "Some finds don't have a default path. Specify '.' explicitly.",
    )
  })
}

///|
fn find_has_help_flag(arguments : Array[@parser.Word]) -> Bool {
  arguments.any(fn(argument) {
    @semantics.literal_text(argument) == Some("--help")
  })
}

///|
fn find_has_path_argument(arguments : Array[@parser.Word]) -> Bool {
  let mut i = 0
  while i < arguments.length() {
    match @semantics.literal_text(arguments[i]) {
      Some(text) =>
        if !text.has_prefix("-") {
          return true
        } else if !find_is_leading_flag(text) {
          return false
        }
      None => return true
    }
    i += 1
  }
  false
}

///|
fn find_is_leading_flag(text : String) -> Bool {
  let view = text[:]
  if view.length() <= 2 {
    return true
  }
  let allowed = "-EHLPXdfsxO0123456789"
  let mut i = 0
  while i < view.length() {
    if !allowed.contains(uint16_to_string(view[i])) {
      return false
    }
    i += 1
  }
  true
}

///|
fn check_deprecated_tempfile(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if command_matches_basename(command, "tempfile") {
      push_diagnostic(
        diagnostics,
        effective_command_span(command),
        CheckSeverity::Warning,
        2186,
        "tempfile is deprecated. Use mktemp instead.",
      )
    }
  })
}

///|
fn check_read_without_r(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_exact_name(command, "read") {
      return
    }
    let (has_r, has_t0) = parse_read_options(
      @semantics.effective_command_arguments(command),
    )
    if !has_r && !has_t0 {
      match read_without_r_fix(command) {
        Some(fix) =>
          push_diagnostic_with_fix(
            diagnostics,
            effective_command_span(command),
            CheckSeverity::Info,
            2162,
            "read without -r will mangle backslashes.",
            fix,
          )
        None =>
          push_diagnostic(
            diagnostics,
            effective_command_span(command),
            CheckSeverity::Info,
            2162,
            "read without -r will mangle backslashes.",
          )
      }
    }
  })
}

///|
fn check_sudo_redirects(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if !command_matches_basename(command, "sudo") {
      return
    }
    for redirect in command.redirects {
      maybe_push_sudo_redirect_diagnostic(diagnostics, redirect)
    }
  })
}

///|
fn maybe_push_sudo_redirect_diagnostic(
  diagnostics : Array[CheckDiagnostic],
  redirect : @parser.Redirection,
) -> Unit {
  guard sudo_redirect_applies_to_stdout_or_all(redirect.source) else { return }
  let target = match redirect.target {
    @parser.RedirectionTarget::Word(word) => Some(word)
    _ => None
  }
  guard target is Some(_) else { return }
  let target_word = match target {
    Some(word) => word
    None => panic()
  }
  guard @semantics.literal_text(target_word) != Some("/dev/null") else {
    return
  }
  match redirect.op {
    @parser.RedirectionOperator::Read =>
      push_diagnostic(
        diagnostics,
        redirect_operator_span(redirect),
        CheckSeverity::Info,
        2024,
        "sudo doesn't affect redirects. Use sudo cat file | ..",
      )
    @parser.RedirectionOperator::Write | @parser.RedirectionOperator::Clobber =>
      push_diagnostic(
        diagnostics,
        redirect_operator_span(redirect),
        CheckSeverity::Warning,
        2024,
        "sudo doesn't affect redirects. Use ..| sudo tee file",
      )
    @parser.RedirectionOperator::Append =>
      push_diagnostic(
        diagnostics,
        redirect_operator_span(redirect),
        CheckSeverity::Warning,
        2024,
        "sudo doesn't affect redirects. Use .. | sudo tee -a file",
      )
    _ => ()
  }
}

///|
fn sudo_redirect_applies_to_stdout_or_all(
  source : @parser.RedirectionSource?,
) -> Bool {
  match source {
    None | Some(@parser.RedirectionSource::All) => true
    Some(@parser.RedirectionSource::Fd(1)) => true
    _ => false
  }
}

///|
fn check_deprecated_grep_variants(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match @semantics.command_basename(command) {
      Some("egrep") =>
        push_diagnostic(
          diagnostics,
          effective_command_span(command),
          CheckSeverity::Info,
          2196,
          "egrep is non-standard and deprecated. Use grep -E instead.",
        )
      Some("fgrep") =>
        push_diagnostic(
          diagnostics,
          effective_command_span(command),
          CheckSeverity::Info,
          2197,
          "fgrep is non-standard and deprecated. Use grep -F instead.",
        )
      _ => ()
    }
  })
}

///|
fn check_deprecate_which(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    if command_matches_basename(command, "which") {
      push_diagnostic(
        diagnostics,
        effective_command_span(command),
        CheckSeverity::Info,
        2230,
        "'which' is non-standard. Use builtin 'command -v' instead.",
      )
    }
  })
}

///|
fn read_without_r_fix(command : @parser.Command) -> @fixer.Fix? {
  match command.kind {
    @parser.CommandKind::Simple(_) => {
      let effective_words = @semantics.effective_command_words(command)
      if effective_words.length() == 0 {
        return None
      }
      let command_word = effective_words[0]
      Some(insert_before_position_fix(command_word.span.end, " -r"))
    }
    _ => None
  }
}

///|
fn parse_read_options(arguments : Array[@parser.Word]) -> (Bool, Bool) {
  let mut has_r = false
  let mut has_t0 = false
  let mut i = 0
  while i < arguments.length() {
    let text = match @semantics.leading_unquoted_text(arguments[i]) {
      Some(text) => text
      None => break
    }
    if text == "--" {
      break
    }
    if !text.has_prefix("-") || text == "-" {
      break
    }
    let option_text = text.view(start_offset=1).to_string()
    if option_text == "" {
      break
    }
    let view = option_text[:]
    let mut consumed_next = false
    let mut j = 0
    while j < view.length() {
      let flag = view[j]
      match flag {
        'r' => {
          has_r = true
          j += 1
        }
        's' | 'e' => j += 1
        _ if read_flag_takes_argument(flag) => {
          let attached = option_text.view(start_offset=j + 1).to_string()
          let value = if attached != "" {
            Some(attached)
          } else if i + 1 < arguments.length() {
            @semantics.literal_text(arguments[i + 1])
          } else {
            None
          }
          if flag == 't' && value == Some("0") {
            has_t0 = true
          }
          if attached == "" && i + 1 < arguments.length() {
            consumed_next = true
          }
          break
        }
        _ => break
      }
    }
    if consumed_next {
      i += 1
    }
    i += 1
  }
  (has_r, has_t0)
}

///|
fn read_flag_takes_argument(flag : UInt16) -> Bool {
  @semantics.read_flag_takes_argument(flag)
}
