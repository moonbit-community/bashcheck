///|
fn append_analytics_batch_w_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_w_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_w_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2082,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Invalid parameter indirection inside ${..} needs ${!name} or eval.",
    },
    {
      code: 2124,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Assigning $@ or ${array[@]} to scalars concatenates array values.",
    },
    {
      code: 2125,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Brace expansions and globs stay literal in scalar assignments.",
    },
    {
      code: 2223,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Default assignments in : ${var=...} should be quoted to avoid globbing.",
    },
    {
      code: 2233,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Subshells around if/while conditions add avoidable overhead.",
    },
    {
      code: 2234,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Single test commands do not need their own subshell wrappers.",
    },
    {
      code: 2235,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Use brace groups instead of test-only subshell wrappers.",
    },
  ]
}

///|
fn run_analytics_batch_w_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_invalid_parameter_indirection_w(script, diagnostics)
  check_array_to_string_assignments_w(script, diagnostics)
  check_default_assignment_globbing_w(script, diagnostics)
  w_visit_script_for_subshelled_tests(script, false, diagnostics)
}

///|
fn check_invalid_parameter_indirection_w(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      walk_word_deep(word, fn(part) {
        match part {
          @parser.WordPart::BracedParameter(expansion) =>
            if w_is_invalid_parameter_indirection(expansion) {
              let fragment = "${\{expansion.raw}}"
              push_diagnostic(
                diagnostics,
                analytics_span_for_nested_word_text(word, fragment, fragment),
                CheckSeverity::Error,
                2082,
                "To expand via indirection, use arrays, ${!name} or (for sh only) eval.",
              )
            }
          _ => ()
        }
      })
    })
  })
}

///|
fn w_is_invalid_parameter_indirection(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  if expansion.indirect {
    return false
  }
  let raw_word = @parser.parse_text_as_word(expansion.raw)
  raw_word.parts.length() > 0 &&
  analytics_parameter_parts_are_indirection(raw_word.parts)
}

///|
fn check_array_to_string_assignments_w(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        for assignment in simple.assignments {
          w_check_scalar_assignment(assignment, diagnostics)
        }
      @parser.CommandKind::Source(source) =>
        for assignment in source.assignments {
          w_check_scalar_assignment(assignment, diagnostics)
        }
      _ => ()
    }
  })
}

///|
fn w_check_scalar_assignment(
  assignment : @parser.Assignment,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if assignment.indexes.length() > 0 {
    return
  }
  match assignment.value {
    @parser.AssignmentValue::Word(word) =>
      if w_word_has_array_concat_expansion(word) {
        push_diagnostic(
          diagnostics,
          array_assignment_value_span(assignment),
          CheckSeverity::Warning,
          2124,
          "Assigning an array to a string! Assign as array, or use * instead of @ to concatenate.",
        )
      } else if w_word_has_literal_assignment_glob(word) {
        push_diagnostic(
          diagnostics,
          array_assignment_value_span(assignment),
          CheckSeverity::Warning,
          2125,
          "Brace expansions and globs are literal in assignments. Quote it or use an array.",
        )
      }
    _ => ()
  }
}

///|
fn w_word_has_array_concat_expansion(word : @parser.Word) -> Bool {
  let mut found = false
  walk_word_deep(word, fn(part) {
    if !found {
      match part {
        @parser.WordPart::SpecialParameter("@") => found = true
        @parser.WordPart::BracedParameter(expansion) =>
          if w_braced_parameter_is_array_at(expansion) {
            found = true
          }
        _ => ()
      }
    }
  })
  found
}

///|
fn w_braced_parameter_is_array_at(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  if expansion.indirect || expansion.length_prefix {
    return false
  }
  match expansion.operator {
    Some(@parser.ParameterOperator::AlternateValue(_)) => false
    _ => parameter_index_is(expansion, "@") || expansion.name == Some("@")
  }
}

///|
fn w_word_has_literal_assignment_glob(word : @parser.Word) -> Bool {
  for part in word.parts {
    match part {
      @parser.WordPart::Glob(_) | @parser.WordPart::BraceExpansion(_) =>
        return true
      _ => ()
    }
  }
  false
}

///|
fn check_default_assignment_globbing_w(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        match simple.words.get(0) {
          Some(first) if @semantics.literal_text(first) == Some(":") => {
            let mut i = 1
            while i < simple.words.length() {
              for span in w_default_assignment_target_spans(simple.words[i]) {
                push_diagnostic(
                  diagnostics,
                  span,
                  CheckSeverity::Info,
                  2223,
                  "This default assignment may cause DoS due to globbing. Quote it.",
                )
              }
              i += 1
            }
          }
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn w_default_assignment_target_spans(
  word : @parser.Word,
) -> Array[@parser.Span] {
  let spans : Array[@parser.Span] = []
  let mut offset = 0
  for part in word.parts {
    let remaining = analytics_word_remaining_text(word, offset)
    let fragment = analytics_bad_parameter_part_fragment(part, remaining)
    let fragment_offset = match analytics_string_offset(remaining, fragment) {
      Some(inner) => offset + inner
      None => offset
    }
    let remaining_width = analytics_remaining_word_width(word, fragment_offset)
    let fragment_width = if fragment.length() <= remaining_width {
      fragment.length()
    } else {
      remaining_width
    }
    match part {
      @parser.WordPart::BracedParameter(expansion) =>
        if w_parameter_operator_is_default_assignment(expansion.operator) {
          spans.push(
            analytics_span_offset(word.span, fragment_offset, fragment_width),
          )
        }
      _ => ()
    }
    offset = fragment_offset + fragment_width
  }
  spans
}

///|
fn w_visit_script_for_subshelled_tests(
  script : @parser.Script,
  in_condition_context : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for item in script.items {
    w_visit_and_or_list_for_subshelled_tests(
      item.and_or,
      in_condition_context,
      diagnostics,
    )
  }
}

///|
fn w_visit_and_or_list_for_subshelled_tests(
  list : @parser.AndOrList,
  in_condition_context : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  w_visit_pipeline_for_subshelled_tests(
    list.head,
    in_condition_context,
    diagnostics,
  )
  for pair in list.tail {
    let (_, pipeline) = pair
    w_visit_pipeline_for_subshelled_tests(
      pipeline, in_condition_context, diagnostics,
    )
  }
}

///|
fn w_visit_pipeline_for_subshelled_tests(
  pipeline : @parser.Pipeline,
  in_condition_context : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for segment in pipeline.segments {
    w_visit_command_for_subshelled_tests(
      segment.command,
      in_condition_context,
      false,
      diagnostics,
    )
  }
}

///|
fn w_visit_command_for_subshelled_tests(
  command : @parser.Command,
  in_condition_context : Bool,
  is_function_body : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match command.kind {
    @parser.CommandKind::Subshell(script) => {
      w_maybe_push_subshelled_test_diagnostic(
        command, script, in_condition_context, is_function_body, diagnostics,
      )
      w_visit_script_for_subshelled_tests(script, false, diagnostics)
    }
    @parser.CommandKind::Time(clause) =>
      w_visit_pipeline_for_subshelled_tests(clause.body, false, diagnostics)
    @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      w_visit_script_for_subshelled_tests(script, false, diagnostics)
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        w_visit_script_for_subshelled_tests(arm.condition, true, diagnostics)
        w_visit_script_for_subshelled_tests(arm.body, false, diagnostics)
      }
      match clause.else_body {
        Some(body) =>
          w_visit_script_for_subshelled_tests(body, false, diagnostics)
        None => ()
      }
    }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) => {
      w_visit_script_for_subshelled_tests(clause.condition, true, diagnostics)
      w_visit_script_for_subshelled_tests(clause.body, false, diagnostics)
    }
    @parser.CommandKind::ForIn(clause) =>
      w_visit_script_for_subshelled_tests(clause.body, false, diagnostics)
    @parser.CommandKind::ForArithmetic(clause) =>
      w_visit_script_for_subshelled_tests(clause.body, false, diagnostics)
    @parser.CommandKind::Select(clause) =>
      w_visit_script_for_subshelled_tests(clause.body, false, diagnostics)
    @parser.CommandKind::Case(clause) =>
      for item in clause.items {
        w_visit_script_for_subshelled_tests(item.body, false, diagnostics)
      }
    @parser.CommandKind::Function(function_) =>
      w_visit_command_for_subshelled_tests(
        function_.body,
        false,
        true,
        diagnostics,
      )
    @parser.CommandKind::CoProc(clause) =>
      w_visit_command_for_subshelled_tests(
        clause.body,
        false,
        false,
        diagnostics,
      )
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_) => ()
  }
}

///|
fn w_maybe_push_subshelled_test_diagnostic(
  command : @parser.Command,
  script : @parser.Script,
  in_condition_context : Bool,
  is_function_body : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if !w_script_is_test_structure(script) ||
    w_script_has_assignment_effect(script) {
    return
  }
  let (code, message) = if in_condition_context {
    (
      2233, "Remove superfluous (..) around condition to avoid subshell overhead.",
    )
  } else if !is_function_body && w_script_is_single_test(script) {
    (
      2234, "Remove superfluous (..) around test command to avoid subshell overhead.",
    )
  } else {
    (2235, "Use { ..; } instead of (..) to avoid subshell overhead.")
  }
  push_diagnostic(
    diagnostics,
    command.span,
    CheckSeverity::Style,
    code,
    message,
  )
}

///|
fn w_script_is_test_structure(script : @parser.Script) -> Bool {
  if script.items.length() == 0 {
    return false
  }
  for item in script.items {
    match item.terminator {
      Some(@parser.Terminator::Background) => return false
      _ => ()
    }
    if !w_and_or_list_is_test_structure(item.and_or) {
      return false
    }
  }
  true
}

///|
fn w_and_or_list_is_test_structure(list : @parser.AndOrList) -> Bool {
  if !w_pipeline_is_test_structure(list.head) {
    return false
  }
  for pair in list.tail {
    let (_, pipeline) = pair
    if !w_pipeline_is_test_structure(pipeline) {
      return false
    }
  }
  true
}

///|
fn w_pipeline_is_test_structure(pipeline : @parser.Pipeline) -> Bool {
  pipeline.operators.length() == 0 &&
  pipeline.segments.length() == 1 &&
  w_command_is_test_structure(pipeline.segments[0].command)
}

///|
fn w_command_is_test_structure(command : @parser.Command) -> Bool {
  if w_command_is_test_command(command) {
    return true
  }
  match command.kind {
    @parser.CommandKind::BraceGroup(script) =>
      w_script_is_test_structure(script)
    _ => false
  }
}

///|
fn w_command_is_test_command(command : @parser.Command) -> Bool {
  match command.kind {
    @parser.CommandKind::Condition(_) => true
    @parser.CommandKind::Simple(simple) =>
      simple.assignments.length() == 0 &&
      simple.words.length() > 0 &&
      command_matches_exact_name(command, "test")
    _ => false
  }
}

///|
fn w_script_is_single_test(script : @parser.Script) -> Bool {
  match script.items {
    [item] => w_and_or_list_is_single_test(item.and_or)
    _ => false
  }
}

///|
fn w_and_or_list_is_single_test(list : @parser.AndOrList) -> Bool {
  list.tail.length() == 0 && w_pipeline_is_single_test(list.head)
}

///|
fn w_pipeline_is_single_test(pipeline : @parser.Pipeline) -> Bool {
  pipeline.operators.length() == 0 &&
  pipeline.segments.length() == 1 &&
  pipeline.segments[0].bangs == 0 &&
  w_command_is_test_command(pipeline.segments[0].command)
}

///|
fn w_script_has_assignment_effect(script : @parser.Script) -> Bool {
  for item in script.items {
    if w_and_or_list_has_assignment_effect(item.and_or) {
      return true
    }
  }
  false
}

///|
fn w_and_or_list_has_assignment_effect(list : @parser.AndOrList) -> Bool {
  if w_pipeline_has_assignment_effect(list.head) {
    return true
  }
  for pair in list.tail {
    let (_, pipeline) = pair
    if w_pipeline_has_assignment_effect(pipeline) {
      return true
    }
  }
  false
}

///|
fn w_pipeline_has_assignment_effect(pipeline : @parser.Pipeline) -> Bool {
  for segment in pipeline.segments {
    if w_command_has_assignment_effect(segment.command) {
      return true
    }
  }
  false
}

///|
fn w_command_has_assignment_effect(command : @parser.Command) -> Bool {
  if w_command_has_direct_assignment_effect(command) {
    return true
  }
  match command.kind {
    @parser.CommandKind::Time(clause) =>
      w_pipeline_has_assignment_effect(clause.body)
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      w_script_has_assignment_effect(script)
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        if w_script_has_assignment_effect(arm.condition) ||
          w_script_has_assignment_effect(arm.body) {
          return true
        }
      }
      match clause.else_body {
        Some(body) => w_script_has_assignment_effect(body)
        None => false
      }
    }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) =>
      w_script_has_assignment_effect(clause.condition) ||
      w_script_has_assignment_effect(clause.body)
    @parser.CommandKind::ForIn(clause) =>
      w_script_has_assignment_effect(clause.body)
    @parser.CommandKind::ForArithmetic(clause) =>
      w_script_has_assignment_effect(clause.body)
    @parser.CommandKind::Select(clause) =>
      w_script_has_assignment_effect(clause.body)
    @parser.CommandKind::Case(clause) =>
      clause.items.any(fn(item) { w_script_has_assignment_effect(item.body) })
    @parser.CommandKind::Function(function_) =>
      w_command_has_assignment_effect(function_.body)
    @parser.CommandKind::CoProc(clause) =>
      w_command_has_assignment_effect(clause.body)
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_) => false
    @parser.CommandKind::Arithmetic(command) =>
      w_arithmetic_expr_has_assignment_effect(command.expr)
  }
}

///|
fn w_command_has_direct_assignment_effect(command : @parser.Command) -> Bool {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      if simple.assignments.length() > 0 {
        return true
      }
    @parser.CommandKind::Source(source) =>
      if source.assignments.length() > 0 {
        return true
      }
    _ => ()
  }

  let mut found = false
  visit_direct_words_in_command(command, fn(word, _) {
    if !found && w_word_has_assignment_effect(word) {
      found = true
    }
  })
  found
}

///|
fn w_word_has_assignment_effect(word : @parser.Word) -> Bool {
  let mut found = false
  walk_word_deep(word, fn(part) {
    if !found {
      match part {
        @parser.WordPart::BracedParameter(expansion) =>
          if w_parameter_operator_is_default_assignment(expansion.operator) {
            found = true
          }
        @parser.WordPart::ArithmeticExpansion(expr)
        | @parser.WordPart::DollarBracket(expr) =>
          if w_arithmetic_expr_has_assignment_effect(expr) {
            found = true
          }
        _ => ()
      }
    }
  })
  found
}

///|
fn w_parameter_operator_is_default_assignment(
  operator : @parser.ParameterOperator?,
) -> Bool {
  match operator {
    Some(@parser.ParameterOperator::AssignDefault(_)) => true
    Some(@parser.ParameterOperator::Raw(text)) =>
      text.has_prefix("=") || text.has_prefix(":=")
    _ => false
  }
}

///|
fn w_arithmetic_expr_has_assignment_effect(
  expr : @parser.ArithmeticExpr,
) -> Bool {
  for token in expr.tokens {
    match token {
      @parser.ArithmeticToken::Operator(op) =>
        if w_is_assignment_arithmetic_operator(op) {
          return true
        }
      @parser.ArithmeticToken::Group(inner) =>
        if w_arithmetic_expr_has_assignment_effect(inner) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn w_is_assignment_arithmetic_operator(op : String) -> Bool {
  op == "=" ||
  op == "+=" ||
  op == "-=" ||
  op == "*=" ||
  op == "/=" ||
  op == "%=" ||
  op == "<<=" ||
  op == ">>=" ||
  op == "&=" ||
  op == "^=" ||
  op == "|=" ||
  op == "++" ||
  op == "--"
}
