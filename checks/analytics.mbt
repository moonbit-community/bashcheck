///|
fn analytics_descriptions() -> Array[CheckDescription] {
  let descriptions : Array[CheckDescription] = [
    {
      code: 2036,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use $(...) if you meant to assign pipeline output.",
    },
    {
      code: 2037,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Use $(...) if you meant to assign command output.",
    },
    {
      code: 2006,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Use $(...) notation instead of legacy backticks `...`.",
    },
    {
      code: 2041,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Single-quoted loop values are literal strings, not commands.",
    },
    {
      code: 2042,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use spaces, not commas, to separate loop elements.",
    },
    {
      code: 2043,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "A for-loop value that never expands will only run once.",
    },
    {
      code: 2044,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "For loops over find output are fragile.",
    },
    {
      code: 2045,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Iterating over ls output is fragile.",
    },
    {
      code: 2046,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Quote command substitutions to prevent word splitting.",
    },
    {
      code: 2048,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Prefer quoted $@ or ${array[@]} over unquoted star expansions.",
    },
    {
      code: 2066,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Quoted loop expansions will not split and only run once.",
    },
    {
      code: 2068,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Double quote array expansions to avoid re-splitting elements.",
    },
    {
      code: 2076,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Unquote =~ regex operands so they behave as regexes.",
    },
    {
      code: 2097,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Prefix assignments are only visible to the invoked command.",
    },
    {
      code: 2098,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "This expansion will not see a prefix assignment from the same command.",
    },
    {
      code: 2166,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Prefer separate [ ] tests over -a / -o in single brackets.",
    },
    {
      code: 2204,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "(..) is a subshell, not a test expression.",
    },
    {
      code: 2205,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "(..) is a subshell, not a binary test expression.",
    },
    {
      code: 2206,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Quote array elements to avoid split/glob behavior.",
    },
    {
      code: 2207,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Prefer mapfile/read -a over splitting command output into arrays.",
    },
    {
      code: 2231,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Quote expansions in for-loop globs.",
    },
    {
      code: 2269,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Self-assignments do nothing.",
    },
    {
      code: 2074,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Use [[ .. ]] rather than [ .. ] with =~.",
    },
    {
      code: 2075,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Escaped < and > are invalid in [[ .. ]].",
    },
  ]
  append_analytics_batch_a_descriptions(descriptions)
  append_analytics_batch_b_descriptions(descriptions)
  append_analytics_batch_c_descriptions(descriptions)
  append_analytics_batch_d_descriptions(descriptions)
  append_analytics_batch_e_descriptions(descriptions)
  append_analytics_batch_f_descriptions(descriptions)
  append_analytics_batch_g_descriptions(descriptions)
  append_analytics_batch_h_descriptions(descriptions)
  append_analytics_batch_i_descriptions(descriptions)
  append_analytics_batch_j_descriptions(descriptions)
  append_analytics_batch_k_descriptions(descriptions)
  append_analytics_batch_l_descriptions(descriptions)
  append_analytics_batch_m_descriptions(descriptions)
  append_analytics_batch_n_descriptions(descriptions)
  append_analytics_batch_o_descriptions(descriptions)
  append_analytics_batch_p_descriptions(descriptions)
  append_analytics_batch_q_descriptions(descriptions)
  append_analytics_batch_r_descriptions(descriptions)
  append_analytics_batch_s_descriptions(descriptions)
  append_analytics_batch_t_descriptions(descriptions)
  append_analytics_batch_u_descriptions(descriptions)
  append_analytics_batch_v_descriptions(descriptions)
  append_analytics_batch_w_descriptions(descriptions)
  descriptions
}

///|
fn analytics_suite() -> CheckSuiteRegistration {
  { descriptions: analytics_descriptions(), run: run_analytics_checks }
}

///|
// CHECK THIS: THUNK
fn analytics_optional_registrations() -> Array[OptionalCheckRegistration] {
  [
    {
      info: {
        name: "useless-use-of-cat",
        desc: "Check for Useless Use Of Cat (UUOC)",
        example: "cat foo | grep bar",
        fix: "grep bar foo",
      },
      description: {
        code: 2002,
        severity: CheckSeverity::Style,
        category: "analytics",
        summary: "Useless cat. Consider redirecting or passing the file directly.",
      },
      run: run_useless_use_of_cat_optional_check,
    },
    {
      info: {
        name: "add-default-case",
        desc: "Suggest adding a default case in `case` statements",
        example: "case $? in 0) echo 'Success';; esac",
        fix: "case $? in 0) echo 'Success';; *) echo 'Fail' ;; esac",
      },
      description: {
        code: 2249,
        severity: CheckSeverity::Info,
        category: "analytics",
        summary: "Consider adding a default *) case.",
      },
      run: run_add_default_case_optional_check,
    },
    {
      info: {
        name: "quote-safe-variables",
        desc: "Suggest quoting variables without metacharacters",
        example: "var=hello; echo $var",
        fix: "var=hello; echo \"$var\"",
      },
      description: {
        code: 2248,
        severity: CheckSeverity::Style,
        category: "analytics",
        summary: "Prefer double quoting even when variables look clean.",
      },
      run: run_quote_safe_variables_optional_check,
    },
    {
      info: {
        name: "avoid-nullary-conditions",
        desc: "Suggest explicitly using -n in `[ $var ]`",
        example: "[ \"$var\" ]",
        fix: "[ -n \"$var\" ]",
      },
      description: {
        code: 2244,
        severity: CheckSeverity::Style,
        category: "analytics",
        summary: "Prefer explicit -n checks for string-like conditions.",
      },
      run: run_avoid_nullary_conditions_optional_check,
    },
    {
      info: {
        name: "avoid-negated-conditions",
        desc: "Suggest removing unnecessary comparison negations",
        example: "[ ! \"$var\" -eq 1 ]",
        fix: "[ \"$var\" -ne 1 ]",
      },
      description: {
        code: 2335,
        severity: CheckSeverity::Style,
        category: "analytics",
        summary: "Prefer direct condition operators over extra negation.",
      },
      run: run_avoid_negated_conditions_optional_check,
    },
    {
      info: {
        name: "require-variable-braces",
        desc: "Suggest putting braces around all variable references",
        example: "var=hello; echo $var",
        fix: "var=hello; echo ${var}",
      },
      description: {
        code: 2250,
        severity: CheckSeverity::Style,
        category: "analytics",
        summary: "Prefer ${var} over bare $var references.",
      },
      run: run_require_variable_braces_optional_check,
    },
    {
      info: {
        name: "check-unassigned-uppercase",
        desc: "Warn when uppercase variables are unassigned",
        example: "echo $VAR",
        fix: "VAR=hello; echo $VAR",
      },
      description: {
        code: 2154,
        severity: CheckSeverity::Warning,
        category: "control-flow",
        summary: "Referenced uppercase variable may not be assigned.",
      },
      run: run_unassigned_uppercase_optional_check,
    },
    {
      info: {
        name: "require-double-brackets",
        desc: "Require [[ and warn about [ in Bash/Ksh",
        example: "[ -e /etc/issue ]",
        fix: "[[ -e /etc/issue ]]",
      },
      description: {
        code: 2292,
        severity: CheckSeverity::Style,
        category: "analytics",
        summary: "Prefer [[ .. ]] over [ .. ] in Bash/Ksh/Busybox.",
      },
      run: run_require_double_brackets_optional_check,
    },
    {
      info: {
        name: "check-set-e-suppressed",
        desc: "Notify when set -e is suppressed during function invocation",
        example: "set -e; func() { cp *.txt ~/backup; rm *.txt; }; func && echo ok",
        fix: "set -e; func() { cp *.txt ~/backup; rm *.txt; }; func; echo ok",
      },
      description: {
        code: 2310,
        severity: CheckSeverity::Info,
        category: "analytics",
        summary: "Warn when set -e is suppressed for function invocations.",
      },
      run: run_set_e_suppressed_optional_check,
    },
    {
      info: {
        name: "check-extra-masked-returns",
        desc: "Check for additional cases where exit codes are masked",
        example: "rm -r \"$(get_chroot_dir)/home\"",
        fix: "set -e; dir=\"$(get_chroot_dir)\"; rm -r \"$dir/home\"",
      },
      description: {
        code: 2312,
        severity: CheckSeverity::Info,
        category: "analytics",
        summary: "Warn when command failures get masked by shell contexts.",
      },
      run: run_extra_masked_returns_optional_check,
    },
  ]
}

///|
fn run_useless_use_of_cat_optional_check(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_useless_use_of_cat(script, diagnostics)
}

///|
fn run_add_default_case_optional_check(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_add_default_case(script, diagnostics)
}

///|
fn run_analytics_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_piped_assignment(script, diagnostics)
  check_backticks(script, diagnostics)
  check_assignment_ate_command(script, diagnostics)
  check_prefix_assignment_reference(script, diagnostics)
  check_for_in_quoted(script, diagnostics)
  check_for_in_ls(script, diagnostics)
  check_for_loop_glob_variables(script, diagnostics)
  check_unquoted_expansions(script, diagnostics)
  check_dollar_star(script, diagnostics)
  check_unquoted_dollar_at(script, diagnostics)
  check_splitting_in_arrays(script, shell, diagnostics)
  check_assign_to_self(script, diagnostics)
  check_single_bracket_operators(script, shell, diagnostics)
  check_double_bracket_operators(script, diagnostics)
  check_conditional_and_ors(script, diagnostics)
  check_quoted_condition_regex(script, diagnostics)
  check_subshell_as_test(script, diagnostics)
  run_analytics_batch_a_checks(script, shell, diagnostics)
  run_analytics_batch_b_checks(script, shell, diagnostics)
  run_analytics_batch_c_checks(script, shell, diagnostics)
  run_analytics_batch_d_checks(script, shell, diagnostics)
  run_analytics_batch_e_checks(script, shell, diagnostics)
  run_analytics_batch_f_checks(script, shell, diagnostics)
  run_analytics_batch_g_checks(script, shell, diagnostics)
  run_analytics_batch_h_checks(script, shell, diagnostics)
  run_analytics_batch_i_checks(script, shell, diagnostics)
  run_analytics_batch_j_checks(script, shell, diagnostics)
  run_analytics_batch_k_checks(script, shell, diagnostics)
  run_analytics_batch_l_checks(script, shell, diagnostics)
  run_analytics_batch_m_checks(script, shell, diagnostics)
  run_analytics_batch_n_checks(script, shell, diagnostics)
  run_analytics_batch_o_checks(script, shell, diagnostics)
  run_analytics_batch_p_checks(script, shell, diagnostics)
  run_analytics_batch_q_checks(script, shell, diagnostics)
  run_analytics_batch_r_checks(script, shell, diagnostics)
  run_analytics_batch_s_checks(script, shell, diagnostics)
  run_analytics_batch_t_checks(script, shell, diagnostics)
  run_analytics_batch_u_checks(script, shell, diagnostics)
  run_analytics_batch_v_checks(script, shell, diagnostics)
  run_analytics_batch_w_checks(script, shell, diagnostics)
}

///|
fn check_backticks(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      if word_has_backquoted_part(word) {
        push_diagnostic_with_fix(
          diagnostics,
          word.span,
          CheckSeverity::Style,
          2006,
          "Use $(...) notation instead of legacy backticks `...`.",
          backtick_fix(word),
        )
      }
    })
  })
}

///|
fn check_useless_use_of_cat(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_pipelines(script, fn(pipeline) {
    guard pipeline.segments.length() >= 2 else { return }
    let first = pipeline.segments[0].command
    guard first.redirects.length() == 0 else { return }
    guard command_matches_exact_name(first, "cat") else { return }
    match @semantics.effective_command_arguments(first) {
      [word] if cat_file_operand_is_safe(word) =>
        push_diagnostic(
          diagnostics,
          word.span,
          CheckSeverity::Style,
          2002,
          "Useless cat. Consider 'cmd < file | ..' or 'cmd file | ..' instead.",
        )
      _ => ()
    }
  })
}

///|
fn cat_file_operand_is_safe(word : @parser.Word) -> Bool {
  !@semantics.is_unquoted_flag(word) && !word_may_expand_to_multiple(word)
}

///|
fn check_add_default_case(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Case(clause) =>
        if !case_clause_has_default_pattern(clause) {
          push_diagnostic(
            diagnostics,
            command.span,
            CheckSeverity::Info,
            2249,
            "Consider adding a default *) case, even if it just exits with error.",
          )
        }
      _ => ()
    }
  })
}

///|
fn case_clause_has_default_pattern(clause : @parser.CaseClause) -> Bool {
  clause.items.any(fn(item) {
    item.patterns.any(fn(pattern) {
      pattern.source == "*" || pattern.source == "**"
    })
  })
}

///|
fn backtick_fix(word : @parser.Word) -> @fixer.Fix {
  replace_span_fix(word.span, rewrite_legacy_backticks(word.source))
}

///|
fn rewrite_legacy_backticks(text : String) -> String {
  let view = text[:]
  let builder = StringBuilder::new()
  let mut in_backticks = false
  let mut escaped = false
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch == '`' && !escaped {
      if in_backticks {
        builder.write_string(")")
      } else {
        builder.write_string("$(")
      }
      in_backticks = !in_backticks
    } else {
      builder.write_char(ch.unsafe_to_char())
    }
    escaped = ch == '\\' && !escaped
    if ch != '\\' {
      escaped = false
    }
    i += 1
  }
  builder.to_string()
}

///|
fn check_for_in_quoted(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::ForIn(clause) if clause.values.length() == 1 => {
        let value = clause.values[0]
        match word_is_plain_double_quoted(value) {
          Some(parts) =>
            if (
                quoted_parts_would_split(parts) &&
                !word_may_expand_to_multiple(value)
              ) ||
              word_would_have_been_glob(value) {
              push_diagnostic(
                diagnostics,
                value.span,
                CheckSeverity::Error,
                2066,
                "Since you double quoted this, it will not word split, and the loop will only run once.",
              )
            }
          None =>
            if word_is_plain_single_quoted(value) {
              push_diagnostic(
                diagnostics,
                value.span,
                CheckSeverity::Warning,
                2041,
                "This is a literal string. To run as a command, use $(..) instead of '..' . ",
              )
            } else if single_for_value_uses_commas(value) {
              push_diagnostic(
                diagnostics,
                value.span,
                CheckSeverity::Warning,
                2042,
                "Use spaces, not commas, to separate loop elements.",
              )
            } else if !word_may_expand_to_multiple(value) {
              push_diagnostic(
                diagnostics,
                value.span,
                CheckSeverity::Warning,
                2043,
                "This loop will only ever run once. Bad quoting or missing glob/expansion?",
              )
            }
        }
      }
      _ => ()
    }
  })
}

///|
fn check_for_in_ls(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::ForIn(clause) if clause.values.length() == 1 =>
        match word_single_top_level_substitution_script(clause.values[0]) {
          Some(inner) =>
            match first_command_in_script(inner) {
              Some(inner_command) => {
                let words = @semantics.oversimplify_command(inner_command)
                match words.get(0) {
                  Some("ls") => {
                    let mut has_flag = false
                    let mut i = 1
                    while i < words.length() {
                      if words[i].has_prefix("-") {
                        has_flag = true
                        break
                      }
                      i += 1
                    }
                    let severity = if has_flag {
                      CheckSeverity::Warning
                    } else {
                      CheckSeverity::Error
                    }
                    push_diagnostic(
                      diagnostics,
                      clause.values[0].span,
                      severity,
                      2045,
                      "Iterating over ls output is fragile. Use globs.",
                    )
                  }
                  Some("find") =>
                    push_diagnostic(
                      diagnostics,
                      clause.values[0].span,
                      CheckSeverity::Warning,
                      2044,
                      "For loops over find output are fragile. Use find -exec or a while read loop.",
                    )
                  _ => ()
                }
              }
              None => ()
            }
          None => ()
        }
      _ => ()
    }
  })
}

///|
fn check_unquoted_expansions(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    let allow_split = command_allows_intentional_splitting(command)
    visit_direct_words_in_command(command, fn(word, place) {
      if !word_place_checks_unquoted_expansions(place) {
        return
      }
      if !word_has_top_level_command_substitution(word) {
        return
      }
      if allow_split && place == WordPlace::CommandArgument {
        return
      }
      if word_is_split_command_output(word) {
        return
      }
      push_diagnostic(
        diagnostics,
        word.span,
        CheckSeverity::Warning,
        2046,
        "Quote this to prevent word splitting.",
      )
    })
  })
}

///|
fn check_dollar_star(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, place) {
      if !word_place_checks_star_or_at(place) {
        return
      }
      match dollar_star_message(word) {
        Some(message) =>
          push_diagnostic(
            diagnostics,
            word.span,
            CheckSeverity::Warning,
            2048,
            message,
          )
        None => ()
      }
    })
  })
}

///|
fn check_unquoted_dollar_at(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, place) {
      if !word_place_checks_star_or_at(place) {
        return
      }
      if !word_has_unquoted_array_expansion(word) {
        return
      }
      push_diagnostic(
        diagnostics,
        word.span,
        CheckSeverity::Error,
        2068,
        "Double quote array expansions to avoid re-splitting elements.",
      )
    })
  })
}

///|
fn check_single_bracket_operators(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if shell != @semantics.ShellDialect::Bash &&
    shell != @semantics.ShellDialect::Ksh {
    return
  }
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        match condition.kind {
          @parser.ConditionKind::SingleBracket =>
            match condition_binary_op_span(condition.expr, "=~") {
              Some(op_span) =>
                push_diagnostic(
                  diagnostics,
                  op_span,
                  CheckSeverity::Error,
                  2074,
                  "Can't use =~ in [ ]. Use [[..]] instead.",
                )
              None => ()
            }
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn check_double_bracket_operators(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        match condition.kind {
          @parser.ConditionKind::DoubleBracket =>
            match condition_raw_escaped_angle_operator(condition.raw) {
              Some(escaped_op) =>
                match
                  condition_binary_op_span(
                    condition.expr,
                    if escaped_op == "\\<" {
                      "<"
                    } else {
                      ">"
                    },
                  ) {
                  Some(op_span) =>
                    push_diagnostic(
                      diagnostics,
                      op_span,
                      CheckSeverity::Error,
                      2075,
                      "Escaping \{escaped_op} is required in [..], but invalid in [[..]]",
                    )
                  None => ()
                }
              None => ()
            }
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn check_piped_assignment(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_pipelines(script, fn(pipeline) {
    guard pipeline.segments.length() >= 2 else { return }
    let first = pipeline.segments[0].command
    match first.kind {
      @parser.CommandKind::Simple(simple) =>
        if simple.assignments.length() > 0 && simple.words.length() == 0 {
          push_diagnostic(
            diagnostics,
            simple.assignments[0].span,
            CheckSeverity::Warning,
            2036,
            "If you wanted to assign the output of the pipeline, use a=$(b | c) .",
          )
        }
      _ => ()
    }
  })
}

///|
fn check_assignment_ate_command(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        if simple.assignments.length() == 1 && simple.words.length() > 0 {
          let first_word = simple.words[0]
          if @semantics.is_unquoted_flag(first_word) ||
            @semantics.is_glob_word(first_word) {
            push_diagnostic(
              diagnostics,
              simple.assignments[0].span,
              CheckSeverity::Error,
              2037,
              "To assign the output of a command, use var=$(cmd) .",
            )
          }
        }
      _ => ()
    }
  })
}

///|
fn check_prefix_assignment_reference(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        if simple.assignments.length() > 0 && simple.words.length() > 0 {
          let references : Array[(String, @parser.Span)] = []
          for word in simple.words {
            collect_word_reference_spans(word, references)
          }
          for assignment in simple.assignments {
            if assignment.indexes.length() == 0 {
              let mut warned = false
              for reference in references {
                let (name, span) = reference
                if name == assignment.name {
                  if !warned {
                    push_diagnostic(
                      diagnostics,
                      assignment.span,
                      CheckSeverity::Warning,
                      2097,
                      "This assignment is only seen by the forked process.",
                    )
                    warned = true
                  }
                  push_diagnostic(
                    diagnostics,
                    span,
                    CheckSeverity::Warning,
                    2098,
                    "This expansion will not see the mentioned assignment.",
                  )
                }
              }
            }
          }
        }
      _ => ()
    }
  })
}

///|
fn check_for_loop_glob_variables(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::ForIn(clause) =>
        for value in clause.values {
          if @semantics.is_glob_word(value) &&
            word_has_quoteable_top_level_expansion(value) {
            push_diagnostic(
              diagnostics,
              value.span,
              CheckSeverity::Info,
              2231,
              "Quote expansions in this for loop glob to prevent wordsplitting, e.g. \"$dir\"/*.txt .",
            )
          }
        }
      _ => ()
    }
  })
}

///|
fn check_splitting_in_arrays(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_array_literal_words_in_command(command, fn(word) {
      if word_has_top_level_command_substitution(word) {
        push_diagnostic(
          diagnostics,
          word.span,
          CheckSeverity::Warning,
          2207,
          array_command_split_message(shell),
        )
      } else if word_has_split_prone_parameter_in_array(word) {
        push_diagnostic(
          diagnostics,
          word.span,
          CheckSeverity::Warning,
          2206,
          array_parameter_split_message(shell),
        )
      }
    })
  })
}

///|
fn check_assign_to_self(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) if simple.words.length() == 0 =>
        for assignment in simple.assignments {
          if !assignment.append && assignment.indexes.length() == 0 {
            match assignment.value {
              @parser.AssignmentValue::Word(word) =>
                if word_is_plain_self_reference(word, assignment.name) {
                  push_diagnostic(
                    diagnostics,
                    assignment.span,
                    CheckSeverity::Info,
                    2269,
                    "This variable is assigned to itself, so the assignment does nothing.",
                  )
                }
              _ => ()
            }
          }
        }
      _ => ()
    }
  })
}

///|
fn check_conditional_and_ors(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) => {
        if condition_expr_has_and(condition.expr) {
          match condition.kind {
            @parser.ConditionKind::SingleBracket =>
              if condition_raw_contains_token(condition.raw, "-a") {
                push_diagnostic(
                  diagnostics,
                  command.span,
                  CheckSeverity::Warning,
                  2166,
                  "Prefer [ p ] && [ q ] as [ p -a q ] is not well defined.",
                )
              }
            @parser.ConditionKind::DoubleBracket => ()
          }
        }
        if condition_expr_has_or(condition.expr) {
          match condition.kind {
            @parser.ConditionKind::SingleBracket =>
              if condition_raw_contains_token(condition.raw, "-o") {
                push_diagnostic(
                  diagnostics,
                  command.span,
                  CheckSeverity::Warning,
                  2166,
                  "Prefer [ p ] || [ q ] as [ p -o q ] is not well defined.",
                )
              }
            @parser.ConditionKind::DoubleBracket => ()
          }
        }
      }
      _ => ()
    }
  })
}

///|
fn check_quoted_condition_regex(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        match condition.kind {
          @parser.ConditionKind::DoubleBracket =>
            visit_condition_binary_rhs(condition.expr, "=~", fn(rhs) {
              if word_is_plain_single_quoted(rhs) ||
                word_is_plain_double_quoted(rhs) is Some(_) {
                if !word_is_constant_non_regex(rhs) {
                  push_diagnostic(
                    diagnostics,
                    rhs.span,
                    CheckSeverity::Warning,
                    2076,
                    "Remove quotes from right-hand side of =~ to match as a regex rather than literally.",
                  )
                }
              }
            })
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn check_subshell_as_test(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let unary_ops = @semantics.unary_test_operators()
  let binary_ops = @semantics.binary_test_operators()
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Subshell(inner) =>
        match first_command_in_script(inner) {
          Some(inner_command) =>
            match inner_command.kind {
              @parser.CommandKind::Simple(simple) =>
                match simple.words.get(0) {
                  Some(first_word) =>
                    match @semantics.literal_text(first_word) {
                      Some(op) if unary_ops.any(fn(current) { current == op }) =>
                        push_diagnostic(
                          diagnostics,
                          command.span,
                          CheckSeverity::Error,
                          2204,
                          "(..) is a subshell. Did you mean [ .. ], a test expression?",
                        )
                      _ =>
                        match simple.words.get(1) {
                          Some(second_word) =>
                            match @semantics.literal_text(second_word) {
                              Some(op) if binary_ops.any(fn(current) {
                                  current == op
                                }) =>
                                push_diagnostic(
                                  diagnostics,
                                  command.span,
                                  CheckSeverity::Warning,
                                  2205,
                                  "(..) is a subshell. Did you mean [ .. ], a test expression?",
                                )
                              _ => ()
                            }
                          None => ()
                        }
                    }
                  None => ()
                }
              _ => ()
            }
          None => ()
        }
      _ => ()
    }
  })
}

///|
fn condition_raw_escaped_angle_operator(raw : String) -> String? {
  let view = raw[:]
  let mut token = ""
  let mut i = 0
  let mut in_single = false
  let mut in_double = false
  while i < view.length() {
    let ch = view[i]
    if in_single {
      token += uint16_to_string(ch)
      if ch == '\'' {
        in_single = false
      }
      i += 1
      continue
    }
    if in_double {
      token += uint16_to_string(ch)
      if ch == '\\' && i + 1 < view.length() {
        token += uint16_to_string(view[i + 1])
        i += 2
        continue
      }
      if ch == '"' {
        in_double = false
      }
      i += 1
      continue
    }
    if ch == '\'' {
      token += uint16_to_string(ch)
      in_single = true
      i += 1
      continue
    }
    if ch == '"' {
      token += uint16_to_string(ch)
      in_double = true
      i += 1
      continue
    }
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if token == "\\<" || token == "\\>" {
        return Some(token)
      }
      token = ""
      i += 1
      continue
    }
    if ch == '\\' && i + 1 < view.length() {
      token += uint16_to_string(ch)
      token += uint16_to_string(view[i + 1])
      i += 2
      continue
    }
    token += uint16_to_string(ch)
    i += 1
  }
  if token == "\\<" || token == "\\>" {
    Some(token)
  } else {
    None
  }
}

///|
fn uint16_to_string(ch : UInt16) -> String {
  let buf = StringBuilder::new()
  buf.write_char(ch.unsafe_to_char())
  buf.to_string()
}

///|
fn word_place_checks_unquoted_expansions(place : WordPlace) -> Bool {
  match place {
    WordPlace::CommandName
    | WordPlace::AssignmentValue
    | WordPlace::ForValue
    | WordPlace::ConditionDoubleBracket => false
    _ => true
  }
}

///|
fn word_place_checks_star_or_at(place : WordPlace) -> Bool {
  match place {
    WordPlace::AssignmentValue
    | WordPlace::ConditionSingleBracket
    | WordPlace::ConditionDoubleBracket => false
    _ => true
  }
}

///|
fn single_for_value_uses_commas(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some(text) => text.contains(",")
    None => false
  }
}

///|
fn quoted_parts_would_split(parts : Array[@parser.WordPart]) -> Bool {
  for part in parts {
    match part {
      @parser.WordPart::Parameter(_)
      | @parser.WordPart::SpecialParameter(_)
      | @parser.WordPart::CommandSubstitution(_)
      | @parser.WordPart::BraceCommandSubstitution(_, _)
      | @parser.WordPart::BackQuoted(_) => return true
      @parser.WordPart::BracedParameter(expansion) =>
        if braced_parameter_would_split_when_unquoted(expansion) {
          return true
        }
      @parser.WordPart::DoubleQuoted(nested)
      | @parser.WordPart::DollarDoubleQuoted(nested) =>
        if quoted_parts_would_split(nested) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn quoted_parts_may_expand_to_multiple(parts : Array[@parser.WordPart]) -> Bool {
  for part in parts {
    if word_part_may_expand_to_multiple(part, true) {
      return true
    }
  }
  false
}

///|
fn word_may_expand_to_multiple(word : @parser.Word) -> Bool {
  for part in word.parts {
    if word_part_may_expand_to_multiple(part, false) {
      return true
    }
  }
  false
}

///|
fn word_part_may_expand_to_multiple(
  part : @parser.WordPart,
  quoted : Bool,
) -> Bool {
  match part {
    @parser.WordPart::Parameter(_) => !quoted
    @parser.WordPart::SpecialParameter(name) =>
      if quoted {
        name == "@"
      } else {
        name == "@" || name == "*"
      }
    @parser.WordPart::BracedParameter(expansion) =>
      braced_parameter_may_expand_to_multiple(expansion, quoted)
    @parser.WordPart::CommandSubstitution(script)
    | @parser.WordPart::BraceCommandSubstitution(_, script)
    | @parser.WordPart::BackQuoted(script) =>
      !quoted && script.items.length() > 0
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      quoted_parts_may_expand_to_multiple(parts)
    @parser.WordPart::ExtGlob(_) | @parser.WordPart::BraceExpansion(_) =>
      !quoted
    @parser.WordPart::Glob(_) => !quoted
    _ => false
  }
}

///|
fn braced_parameter_may_expand_to_multiple(
  expansion : @parser.ParameterExpansion,
  quoted : Bool,
) -> Bool {
  if expansion.length_prefix {
    return false
  }
  if expansion.indirect {
    return true
  }
  if parameter_has_names_operator(expansion) {
    return true
  }
  match expansion.index {
    Some(index) if index.raw == "@" => true
    Some(index) if index.raw == "*" => !quoted
    _ =>
      match expansion.name {
        Some("@") => true
        Some("*") => !quoted
        Some(_) => !quoted
        None => false
      }
  }
}

///|
fn braced_parameter_would_split_when_unquoted(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  if expansion.length_prefix {
    return false
  }
  if expansion.indirect {
    return true
  }
  if parameter_has_names_operator(expansion) {
    return true
  }
  if parameter_has_index(expansion) {
    return true
  }
  expansion.name is Some(_)
}

///|
fn command_allows_intentional_splitting(command : @parser.Command) -> Bool {
  if @semantics.effective_command_name(command) != Some("set") {
    return false
  }
  match @semantics.effective_command_arguments(command).get(0) {
    Some(word) => @semantics.literal_text(word) == Some("--")
    None => false
  }
}

///|
fn word_is_split_command_output(word : @parser.Word) -> Bool {
  match word_single_top_level_substitution_script(word) {
    Some(script) =>
      match first_command_name_in_script(script) {
        Some("seq") | Some("pgrep") => true
        _ => false
      }
    None => false
  }
}

///|
fn dollar_star_message(word : @parser.Word) -> String? {
  for part in word.parts {
    match part {
      @parser.WordPart::SpecialParameter("*") =>
        return Some("Use \"$@\" (with quotes) to prevent whitespace problems.")
      @parser.WordPart::BracedParameter(expansion) => {
        if expansion.length_prefix {
          continue
        }
        match expansion.index {
          Some(index) if index.raw == "*" =>
            return Some(
              "Use \"${array[@]}\" (with quotes) to prevent whitespace problems.",
            )
          _ =>
            match expansion.name {
              Some("*") =>
                return Some(
                  "Use \"$@\" (with quotes) to prevent whitespace problems.",
                )
              _ => ()
            }
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn word_has_unquoted_array_expansion(word : @parser.Word) -> Bool {
  for part in word.parts {
    match part {
      @parser.WordPart::SpecialParameter("@") => return true
      @parser.WordPart::BracedParameter(expansion) =>
        if braced_parameter_is_unquoted_array_expansion(expansion) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn braced_parameter_is_unquoted_array_expansion(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  if expansion.length_prefix {
    return false
  }
  match expansion.operator {
    Some(@parser.ParameterOperator::AlternateValue(_)) => return false
    _ => ()
  }
  parameter_index_is(expansion, "@") || expansion.name == Some("@")
}

///|
fn condition_binary_op_span(
  expr : @parser.ConditionExpr,
  op : String,
) -> @parser.Span? {
  match expr {
    @parser.ConditionExpr::Binary(current, op_span, _, _) =>
      if current == op {
        Some(op_span)
      } else {
        None
      }
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      condition_binary_op_span(inner, op)
    @parser.ConditionExpr::And(lhs, rhs)
    | @parser.ConditionExpr::Or(lhs, rhs) =>
      match condition_binary_op_span(lhs, op) {
        Some(span) => Some(span)
        None => condition_binary_op_span(rhs, op)
      }
    _ => None
  }
}

///|
fn collect_word_reference_spans(
  word : @parser.Word,
  references : Array[(String, @parser.Span)],
) -> Unit {
  walk_word_deep(word, fn(part) {
    match part {
      @parser.WordPart::Parameter(name) => references.push((name, word.span))
      @parser.WordPart::BracedParameter(expansion) =>
        match expansion.name {
          Some(name) => references.push((name, word.span))
          None => ()
        }
      _ => ()
    }
  })
}

///|
fn visit_array_literal_words_in_command(
  command : @parser.Command,
  visit : (@parser.Word) -> Unit,
) -> Unit {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      for assignment in simple.assignments {
        visit_array_literal_words_in_value(assignment.value, visit)
      }
    @parser.CommandKind::Source(source) =>
      for assignment in source.assignments {
        visit_array_literal_words_in_value(assignment.value, visit)
      }
    _ => ()
  }
}

///|
fn visit_array_literal_words_in_value(
  value : @parser.AssignmentValue,
  visit : (@parser.Word) -> Unit,
) -> Unit {
  match value {
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      for element in elements {
        visit_array_literal_words_in_element(element, visit)
      }
    _ => ()
  }
}

///|
fn visit_array_literal_words_in_element(
  element : @parser.ArrayElement,
  visit : (@parser.Word) -> Unit,
) -> Unit {
  match element.value {
    @parser.AssignmentValue::Word(word) => visit(word)
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      for nested in elements {
        visit_array_literal_words_in_element(nested, visit)
      }
    @parser.AssignmentValue::Empty => ()
  }
}

///|
fn array_parameter_split_message(shell : @semantics.ShellDialect) -> String {
  if shell == @semantics.ShellDialect::Ksh {
    "Quote to prevent word splitting/globbing, or split robustly with read -A or while read."
  } else {
    "Quote to prevent word splitting/globbing, or split robustly with mapfile or read -a."
  }
}

///|
fn array_command_split_message(shell : @semantics.ShellDialect) -> String {
  if shell == @semantics.ShellDialect::Ksh {
    "Prefer read -A or while read to split command output (or quote to avoid splitting)."
  } else {
    "Prefer mapfile or read -a to split command output (or quote to avoid splitting)."
  }
}

///|
fn word_has_split_prone_parameter_in_array(word : @parser.Word) -> Bool {
  for part in word.parts {
    match part {
      @parser.WordPart::Parameter(name) =>
        if !@semantics.is_variable_without_spaces(name) {
          return true
        }
      @parser.WordPart::SpecialParameter(name) =>
        if !@semantics.is_special_variable_without_spaces(name) {
          return true
        }
      @parser.WordPart::BracedParameter(expansion) =>
        if braced_parameter_should_warn_in_array(expansion) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn braced_parameter_should_warn_in_array(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  if expansion.length_prefix {
    return false
  }
  match expansion.operator {
    Some(@parser.ParameterOperator::AlternateValue(_)) => return false
    _ => ()
  }
  if expansion.indirect ||
    parameter_has_names_operator(expansion) ||
    parameter_has_index(expansion) {
    return true
  }
  match expansion.name {
    Some(name) =>
      if @semantics.is_special_variable(name) {
        !@semantics.is_special_variable_without_spaces(name)
      } else {
        !@semantics.is_variable_without_spaces(name)
      }
    None => false
  }
}

///|
fn word_has_quoteable_top_level_expansion(word : @parser.Word) -> Bool {
  for part in word.parts {
    match part {
      @parser.WordPart::Parameter(_)
      | @parser.WordPart::SpecialParameter(_)
      | @parser.WordPart::BracedParameter(_)
      | @parser.WordPart::BraceCommandSubstitution(_, _)
      | @parser.WordPart::CommandSubstitution(_)
      | @parser.WordPart::BackQuoted(_)
      | @parser.WordPart::ArithmeticExpansion(_)
      | @parser.WordPart::DollarBracket(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn word_is_plain_self_reference(word : @parser.Word, name : String) -> Bool {
  match word.parts {
    [@parser.WordPart::Parameter(reference)] => reference == name
    [@parser.WordPart::BracedParameter(expansion)] =>
      braced_parameter_is_plain_name_reference(expansion, name)
    [@parser.WordPart::DoubleQuoted(parts)] =>
      quoted_parts_are_plain_self_reference(parts, name)
    _ => false
  }
}

///|
fn quoted_parts_are_plain_self_reference(
  parts : Array[@parser.WordPart],
  name : String,
) -> Bool {
  match parts {
    [@parser.WordPart::Parameter(reference)] => reference == name
    [@parser.WordPart::BracedParameter(expansion)] =>
      braced_parameter_is_plain_name_reference(expansion, name)
    _ => false
  }
}

///|
fn braced_parameter_is_plain_name_reference(
  expansion : @parser.ParameterExpansion,
  name : String,
) -> Bool {
  !expansion.length_prefix &&
  !expansion.indirect &&
  !parameter_has_index(expansion) &&
  expansion.operator is None &&
  expansion.name == Some(name)
}

///|
fn condition_expr_has_and(expr : @parser.ConditionExpr) -> Bool {
  match expr {
    @parser.ConditionExpr::And(_, _) => true
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      condition_expr_has_and(inner)
    @parser.ConditionExpr::Or(lhs, rhs) =>
      condition_expr_has_and(lhs) || condition_expr_has_and(rhs)
    _ => false
  }
}

///|
fn condition_expr_has_or(expr : @parser.ConditionExpr) -> Bool {
  match expr {
    @parser.ConditionExpr::Or(_, _) => true
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      condition_expr_has_or(inner)
    @parser.ConditionExpr::And(lhs, rhs) =>
      condition_expr_has_or(lhs) || condition_expr_has_or(rhs)
    _ => false
  }
}

///|
fn visit_condition_binary_rhs(
  expr : @parser.ConditionExpr,
  op : String,
  visit : (@parser.Word) -> Unit,
) -> Unit {
  match expr {
    @parser.ConditionExpr::Binary(current, _, _, rhs) =>
      if current == op {
        visit(rhs)
      }
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      visit_condition_binary_rhs(inner, op, visit)
    @parser.ConditionExpr::And(lhs, rhs)
    | @parser.ConditionExpr::Or(lhs, rhs) => {
      visit_condition_binary_rhs(lhs, op, visit)
      visit_condition_binary_rhs(rhs, op, visit)
    }
    _ => ()
  }
}

///|
fn word_is_constant_non_regex(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some(text) => !string_has_regex_metacharacters(text)
    None => false
  }
}

///|
fn string_has_regex_metacharacters(text : String) -> Bool {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch == '[' ||
      ch == ']' ||
      ch == '*' ||
      ch == '.' ||
      ch == '+' ||
      ch == '(' ||
      ch == ')' ||
      ch == '|' {
      return true
    }
    i += 1
  }
  false
}

///|
fn condition_raw_contains_token(raw : String, target : String) -> Bool {
  condition_raw_tokens(raw).any(fn(token) { token == target })
}

///|
fn condition_raw_tokens(raw : String) -> Array[String] {
  let view = raw[:]
  let tokens : Array[String] = []
  let mut token = ""
  let mut i = 0
  let mut in_single = false
  let mut in_double = false
  while i < view.length() {
    let ch = view[i]
    if in_single {
      token += uint16_to_string(ch)
      if ch == '\'' {
        in_single = false
      }
      i += 1
      continue
    }
    if in_double {
      token += uint16_to_string(ch)
      if ch == '\\' && i + 1 < view.length() {
        token += uint16_to_string(view[i + 1])
        i += 2
        continue
      }
      if ch == '"' {
        in_double = false
      }
      i += 1
      continue
    }
    if ch == '\'' {
      token += uint16_to_string(ch)
      in_single = true
      i += 1
      continue
    }
    if ch == '"' {
      token += uint16_to_string(ch)
      in_double = true
      i += 1
      continue
    }
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if token != "" {
        tokens.push(token)
        token = ""
      }
      i += 1
      continue
    }
    if ch == '\\' && i + 1 < view.length() {
      token += uint16_to_string(ch)
      token += uint16_to_string(view[i + 1])
      i += 2
      continue
    }
    token += uint16_to_string(ch)
    i += 1
  }
  if token != "" {
    tokens.push(token)
  }
  tokens
}
