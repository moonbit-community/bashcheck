///|
fn append_analytics_batch_q_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_q_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_q_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2069,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Place 2>&1 after stdout redirections when you mean to merge both streams.",
    },
    {
      code: 2129,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Prefer grouping repeated >> redirects into one block redirect.",
    },
    {
      code: 2143,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Prefer grep -q over comparing grep output in test expressions.",
    },
    {
      code: 2188,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "This redirection doesn't have a command.",
    },
    {
      code: 2189,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "A pipe separates this redirection from the command it should apply to.",
    },
    {
      code: 2216,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Piping to a command that doesn't read stdin is usually a mistake.",
    },
    {
      code: 2217,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Redirecting to a command that doesn't read stdin is usually a mistake.",
    },
    {
      code: 2251,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Bare ! under set -e skips errexit outside condition contexts.",
    },
    {
      code: 2257,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Arithmetic side effects in redirection targets may be discarded.",
    },
    {
      code: 2259,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "This redirection overrides piped input.",
    },
    {
      code: 2260,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "This redirection overrides the output pipe.",
    },
    {
      code: 2261,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Multiple redirections compete for the same file descriptor.",
    },
    {
      code: 2265,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Single & after test commands backgrounds instead of doing logical AND.",
    },
    {
      code: 2266,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Single | between test commands pipes instead of doing logical OR.",
    },
  ]
}

///|
fn run_analytics_batch_q_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let indexed = @semantics.build_index(script)
  check_stderr_redirect_order_q(indexed, diagnostics)
  check_multiple_appends_q(script, diagnostics)
  check_should_use_grep_q_q(script, diagnostics)
  check_useless_bang_q(script, diagnostics)
  check_modified_arithmetic_in_redirection_q(script, shell, diagnostics)
  check_bad_test_and_or_q(script, diagnostics)
  for id in indexed_all_node_ids(indexed) {
    match @semantics.node_ref_of(indexed, id) {
      Some(@semantics.NodeRef::Pipeline(pipeline)) => {
        if !indexed_node_is_in_expansion(indexed, id) {
          check_redirected_nowhere(pipeline, diagnostics)
        }
        check_pipe_to_nowhere(pipeline, diagnostics)
      }
      _ => ()
    }
  }
}

///|
fn check_redirected_nowhere(
  pipeline : @parser.Pipeline,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard pipeline.segments.length() > 0 else { return }
  for segment in pipeline.segments {
    if command_is_redirect_only(segment.command) &&
      segment.command.redirects.length() > 0 {
      let code = if pipeline.segments.length() == 1 { 2188 } else { 2189 }
      let severity = if code == 2188 {
        CheckSeverity::Warning
      } else {
        CheckSeverity::Error
      }
      let message = if code == 2188 {
        "This redirection doesn't have a command. Move to its command (or use 'true' as no-op)."
      } else {
        "You can't have | between this redirection and the command it should apply to."
      }
      push_diagnostic(
        diagnostics,
        segment.command.redirects[0].span,
        severity,
        code,
        message,
      )
    }
  }
}

///|
fn check_pipe_to_nowhere(
  pipeline : @parser.Pipeline,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard pipeline.segments.length() > 0 else { return }
  let mut i = 0
  while i < pipeline.segments.length() {
    let segment = pipeline.segments[i]
    let command = segment.command
    let command_name = match @semantics.effective_command_name(command) {
      Some(name) => name
      None => ""
    }
    let has_input_pipe = i > 0
    let has_output_pipe = i + 1 < pipeline.segments.length()
    let output_pipe = if has_output_pipe {
      Some(pipeline.operators[i])
    } else {
      None
    }

    if has_input_pipe &&
      command_name != "" &&
      command_is_non_reading(command_name) &&
      !command_has_additional_consumers(command) &&
      !command_specific_exception(command_name, command) {
      push_diagnostic(
        diagnostics,
        command.span,
        CheckSeverity::Warning,
        2216,
        command_does_not_read_stdin_message(command_name),
      )
    }

    if command_name != "" &&
      command_is_non_reading(command_name) &&
      command_has_stdin_redirect(command) &&
      !command_has_additional_consumers(command) &&
      !command_has_interactive_flag_exception(command_name, command) {
      push_diagnostic(
        diagnostics,
        command.span,
        CheckSeverity::Warning,
        2217,
        command_does_not_read_stdin_redirect_message(command_name),
      )
    }

    if has_input_pipe &&
      command_has_stdin_redirect(command) &&
      !command_has_additional_consumers(command) {
      match first_redirect_with_fd(command.redirects, 0) {
        Some(redirect) =>
          push_diagnostic(
            diagnostics,
            redirect_operator_span(redirect),
            CheckSeverity::Error,
            2259,
            "This redirection overrides piped input. To use both, merge or pass filenames.",
          )
        None => ()
      }
    }

    match output_pipe {
      Some(@parser.PipeOperator::Pipe) =>
        if !command_has_additional_producers(command) {
          match first_redirect_with_fd(command.redirects, 1) {
            Some(redirect) =>
              push_diagnostic(
                diagnostics,
                redirect_operator_span(redirect),
                CheckSeverity::Error,
                2260,
                "This redirection overrides the output pipe. Use 'tee' to output to both.",
              )
            None => ()
          }
        }
      _ => ()
    }

    emit_competing_redirections(command, diagnostics)
    i += 1
  }
}

///|
fn emit_competing_redirections(
  command : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let redirects = command.redirects
  let mut i = 0
  while i < redirects.length() {
    let redirect = redirects[i]
    let fds = redirect_default_fds(redirect)
    for fd in fds {
      if redirect_has_competition(redirects, i, fd) {
        push_diagnostic(
          diagnostics,
          redirect_operator_span(redirect),
          CheckSeverity::Error,
          2261,
          competing_redirections_message(fds),
        )
        break
      }
    }
    i += 1
  }
}

///|
fn redirect_has_competition(
  redirects : Array[@parser.Redirection],
  index : Int,
  fd : Int,
) -> Bool {
  let mut i = 0
  while i < redirects.length() {
    if i != index && redirect_default_fds(redirects[i]).contains(fd) {
      return true
    }
    i += 1
  }
  false
}

///|
fn command_is_redirect_only(command : @parser.Command) -> Bool {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      simple.words.length() == 0 && simple.assignments.length() == 0
    _ => false
  }
}

///|
fn check_stderr_redirect_order_q(
  indexed : @semantics.IndexedScript,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for id in indexed_all_node_ids(indexed) {
    match @semantics.node_ref_of(indexed, id) {
      Some(@semantics.NodeRef::Command(command)) =>
        q_check_stderr_redirect_order_command(indexed, id, command, diagnostics)
      _ => ()
    }
  }
}

///|
fn q_check_stderr_redirect_order_command(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
  command : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let redirects = command.redirects
  let mut i = 0
  while i + 1 < redirects.length() {
    let current = redirects[i]
    let next = redirects[i + 1]
    if q_redirect_is_stderr_to_stdout(current) &&
      q_redirect_is_stdout_file_redirect(next) &&
      !q_command_output_is_captured(indexed, id) {
      push_diagnostic(
        diagnostics,
        current.span,
        CheckSeverity::Warning,
        2069,
        "To redirect stdout+stderr, 2>&1 must be last (or use '{ cmd > file; } 2>&1' to clarify).",
      )
      return
    }
    i += 1
  }
}

///|
fn q_redirect_is_stderr_to_stdout(redirect : @parser.Redirection) -> Bool {
  match (redirect.source, redirect.op, redirect.target) {
    (
      Some(@parser.RedirectionSource::Fd(2)),
      @parser.RedirectionOperator::DupOutput,
      @parser.RedirectionTarget::Word(word),
    ) => @semantics.literal_text(word) == Some("1")
    _ => false
  }
}

///|
fn q_redirect_is_stdout_file_redirect(redirect : @parser.Redirection) -> Bool {
  let stdout_source = match redirect.source {
    None | Some(@parser.RedirectionSource::Fd(1)) => true
    _ => false
  }
  stdout_source &&
  (
    redirect.op is @parser.RedirectionOperator::Write ||
    redirect.op is @parser.RedirectionOperator::Append
  )
}

///|
fn q_command_output_is_captured(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
) -> Bool {
  if indexed_node_is_in_expansion(indexed, id) {
    return true
  }
  let mut current = Some(id)
  while current is Some(_) {
    let node_id = match current {
      Some(node_id) => node_id
      None => break
    }
    match @semantics.node_ref_of(indexed, node_id) {
      Some(@semantics.NodeRef::Command(_)) =>
        if q_command_is_pipeline_producer(indexed, node_id) {
          return true
        }
      _ => ()
    }
    current = @semantics.parent_of(indexed, node_id)
  }
  false
}

///|
fn q_command_is_pipeline_producer(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
) -> Bool {
  let segment_id = match @semantics.parent_of(indexed, id) {
    Some(parent) =>
      match @semantics.node_ref_of(indexed, parent) {
        Some(@semantics.NodeRef::PipelineSegment(_)) => parent
        _ => return false
      }
    None => return false
  }
  let pipeline_id = match @semantics.parent_of(indexed, segment_id) {
    Some(parent) =>
      match @semantics.node_ref_of(indexed, parent) {
        Some(@semantics.NodeRef::Pipeline(pipeline)) =>
          if pipeline.segments.length() > 1 {
            parent
          } else {
            return false
          }
        _ => return false
      }
    None => return false
  }
  let segment_ids = q_pipeline_segment_ids(indexed, pipeline_id)
  match segment_ids.get(segment_ids.length() - 1) {
    Some(last_segment) => last_segment != segment_id
    None => false
  }
}

///|
fn q_pipeline_segment_ids(
  indexed : @semantics.IndexedScript,
  pipeline_id : @semantics.NodeId,
) -> Array[@semantics.NodeId] {
  let ids : Array[@semantics.NodeId] = []
  for child in @semantics.children_of(indexed, pipeline_id) {
    match @semantics.node_ref_of(indexed, child) {
      Some(@semantics.NodeRef::PipelineSegment(_)) => ids.push(child)
      _ => ()
    }
  }
  ids
}

///|
priv struct QMultipleAppendState {
  target : String
  first_span : @parser.Span?
  run_length : Int
  warned : Bool
}

///|
fn check_multiple_appends_q(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut state = { target: "", first_span: None, run_length: 0, warned: false }
  for item in script.items {
    state = q_advance_multiple_appends(state, item.and_or.head, diagnostics)
    for pair in item.and_or.tail {
      let (_, pipeline) = pair
      state = q_advance_multiple_appends(state, pipeline, diagnostics)
    }
    q_check_multiple_appends_nested_in_and_or(item.and_or, diagnostics)
  }
}

///|
fn q_advance_multiple_appends(
  state : QMultipleAppendState,
  pipeline : @parser.Pipeline,
  diagnostics : Array[CheckDiagnostic],
) -> QMultipleAppendState {
  match q_multiple_append_target(pipeline) {
    Some((target, span)) =>
      if state.target == target {
        let next_run_length = state.run_length + 1
        if next_run_length >= 3 && !state.warned {
          match state.first_span {
            Some(first_span) =>
              push_diagnostic(
                diagnostics,
                first_span,
                CheckSeverity::Style,
                2129,
                "Consider using { cmd1; cmd2; } >> file instead of individual redirects.",
              )
            None => ()
          }
          { ..state, run_length: next_run_length, warned: true }
        } else {
          { ..state, run_length: next_run_length }
        }
      } else {
        { target, first_span: Some(span), run_length: 1, warned: false }
      }
    None => { target: "", first_span: None, run_length: 0, warned: false }
  }
}

///|
fn q_multiple_append_target(
  pipeline : @parser.Pipeline,
) -> (String, @parser.Span)? {
  match pipeline.segments.get(pipeline.segments.length() - 1) {
    Some(last_segment) =>
      match q_first_append_redirect_target(last_segment.command) {
        Some(target) => Some((target, last_segment.command.span))
        None => None
      }
    None => None
  }
}

///|
fn q_first_append_redirect_target(command : @parser.Command) -> String? {
  for redirect in command.redirects {
    match (redirect.op, redirect.target) {
      (
        @parser.RedirectionOperator::Append,
        @parser.RedirectionTarget::Word(word),
      ) => return Some(word.source)
      _ => ()
    }
  }
  None
}

///|
fn q_check_multiple_appends_nested_in_and_or(
  list : @parser.AndOrList,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  q_check_multiple_appends_nested_in_pipeline(list.head, diagnostics)
  for pair in list.tail {
    let (_, pipeline) = pair
    q_check_multiple_appends_nested_in_pipeline(pipeline, diagnostics)
  }
}

///|
fn q_check_multiple_appends_nested_in_pipeline(
  pipeline : @parser.Pipeline,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for segment in pipeline.segments {
    q_check_multiple_appends_nested_in_command(segment.command, diagnostics)
  }
}

///|
fn q_check_multiple_appends_nested_in_command(
  command : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match command.kind {
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      check_multiple_appends_q(script, diagnostics)
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        check_multiple_appends_q(arm.condition, diagnostics)
        check_multiple_appends_q(arm.body, diagnostics)
      }
      match clause.else_body {
        Some(body) => check_multiple_appends_q(body, diagnostics)
        None => ()
      }
    }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) => {
      check_multiple_appends_q(clause.condition, diagnostics)
      check_multiple_appends_q(clause.body, diagnostics)
    }
    @parser.CommandKind::ForIn(clause) =>
      check_multiple_appends_q(clause.body, diagnostics)
    @parser.CommandKind::ForArithmetic(clause) =>
      check_multiple_appends_q(clause.body, diagnostics)
    @parser.CommandKind::Select(clause) =>
      check_multiple_appends_q(clause.body, diagnostics)
    @parser.CommandKind::Case(clause) =>
      for item in clause.items {
        check_multiple_appends_q(item.body, diagnostics)
      }
    @parser.CommandKind::Function(function_) =>
      q_check_multiple_appends_nested_in_command(function_.body, diagnostics)
    @parser.CommandKind::CoProc(clause) =>
      q_check_multiple_appends_nested_in_command(clause.body, diagnostics)
    @parser.CommandKind::Time(clause) =>
      q_check_multiple_appends_nested_in_pipeline(clause.body, diagnostics)
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_) => ()
  }
}

///|
fn check_should_use_grep_q_q(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        q_check_condition_for_grep_q(condition.expr, diagnostics)
      _ => ()
    }
  })
}

///|
fn q_check_condition_for_grep_q(
  expr : @parser.ConditionExpr,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match expr {
    @parser.ConditionExpr::Word(word) =>
      match q_final_grep_name_from_condition_word(word) {
        Some(name) =>
          push_diagnostic(
            diagnostics,
            q_nullary_condition_word_span(word),
            CheckSeverity::Style,
            2143,
            "Use \{name} -q instead of comparing output with [ -n .. ].",
          )
        None => ()
      }
    @parser.ConditionExpr::Unary(op, op_span, word) =>
      if op == "-n" || op == "-z" {
        match q_final_grep_name_from_condition_word(word) {
          Some(name) => {
            let prefix = if op == "-z" { "! " } else { "" }
            push_diagnostic(
              diagnostics,
              op_span,
              CheckSeverity::Style,
              2143,
              "Use \{prefix}\{name} -q instead of comparing output with [ \{op} .. ].",
            )
          }
          None => ()
        }
      }
    @parser.ConditionExpr::Group(inner) =>
      q_check_condition_for_grep_q(inner, diagnostics)
    @parser.ConditionExpr::And(lhs, rhs)
    | @parser.ConditionExpr::Or(lhs, rhs) => {
      q_check_condition_for_grep_q(lhs, diagnostics)
      q_check_condition_for_grep_q(rhs, diagnostics)
    }
    @parser.ConditionExpr::Empty
    | @parser.ConditionExpr::Binary(_, _, _, _)
    | @parser.ConditionExpr::Not(_) => ()
  }
}

///|
fn q_final_grep_name_from_condition_word(word : @parser.Word) -> String? {
  match q_condition_word_substitution_script(word) {
    Some(script) => q_final_grep_name_from_substitution_script(script)
    None => None
  }
}

///|
fn q_condition_word_substitution_script(word : @parser.Word) -> @parser.Script? {
  match word.parts {
    [@parser.WordPart::CommandSubstitution(script)]
    | [@parser.WordPart::BackQuoted(script)] => Some(script)
    [
      @parser.WordPart::DoubleQuoted(
        [@parser.WordPart::CommandSubstitution(script)]
      ),
    ]
    | [@parser.WordPart::DoubleQuoted([@parser.WordPart::BackQuoted(script)])]
    | [
      @parser.WordPart::DollarDoubleQuoted(
        [@parser.WordPart::CommandSubstitution(script)]
      ),
    ]
    | [
      @parser.WordPart::DollarDoubleQuoted(
        [@parser.WordPart::BackQuoted(script)]
      ),
    ] => Some(script)
    _ => None
  }
}

///|
fn q_final_grep_name_from_substitution_script(
  script : @parser.Script,
) -> String? {
  guard script.items.length() == 1 else { return None }
  let list = script.items[0].and_or
  guard list.tail.length() == 0 else { return None }
  guard list.head.segments.length() > 0 else { return None }
  let command = list.head.segments[list.head.segments.length() - 1].command
  let name = match @semantics.effective_command_name(command) {
    Some(name) => analytics_path_basename(name)
    None => return None
  }
  if q_grep_like_commands().contains(name) {
    Some(name)
  } else {
    None
  }
}

///|
fn q_grep_like_commands() -> Array[String] {
  [
    "grep", "egrep", "fgrep", "bz3grep", "bzgrep", "xzgrep", "zgrep", "zipgrep",
    "zstdgrep",
  ]
}

///|
fn q_nullary_condition_word_span(word : @parser.Word) -> @parser.Span {
  @parser.Span::new(
    word.span.start,
    @parser.Position::new(
      word.span.end.offset + 1,
      word.span.end.line,
      word.span.end.column + 1,
    ),
  )
}

///|
fn command_is_non_reading(name : String) -> Bool {
  non_reading_commands().contains(name)
}

///|
fn command_specific_exception(name : String, command : @parser.Command) -> Bool {
  if name == "du" {
    return command_arguments_contain_any(command, [
      "--exclude-from", "--files0-from",
    ])
  }
  command_has_interactive_flag_exception(name, command)
}

///|
fn command_has_interactive_flag_exception(
  name : String,
  command : @parser.Command,
) -> Bool {
  if !["cp", "mv", "rm"].contains(name) {
    return false
  }
  for argument in @semantics.effective_command_arguments(command) {
    match @semantics.literal_text(argument) {
      Some(text) if text == "--" => return false
      Some(text) if text == "-i" || text == "--interactive" => return true
      Some(text) if short_option_cluster_contains(text, 'i') => return true
      _ => ()
    }
  }
  false
}

///|
fn command_has_stdin_redirect(command : @parser.Command) -> Bool {
  first_redirect_with_fd(command.redirects, 0) is Some(_)
}

///|
fn command_arguments_contain_any(
  command : @parser.Command,
  prefixes : Array[String],
) -> Bool {
  for argument in @semantics.effective_command_arguments(command) {
    match @semantics.literal_text(argument) {
      Some(text) =>
        for prefix in prefixes {
          if text == prefix || text.has_prefix(prefix + "=") {
            return true
          }
        }
      None => ()
    }
  }
  false
}

///|
fn command_has_additional_consumers(command : @parser.Command) -> Bool {
  let mut found = false
  @semantics.walk_command(command, fn(current) {
    if found {
      return
    }
    visit_direct_words_in_command(current, fn(word, _) {
      if word_has_additional_consumers(word) {
        found = true
      }
    })
    if found {
      return
    }
    for redirect in current.redirects {
      match redirect.target {
        @parser.RedirectionTarget::HereDoc(doc) =>
          match doc.parts {
            Some(parts) =>
              if here_doc_parts_have_additional_consumers(parts) {
                found = true
                return
              }
            None => ()
          }
        _ => ()
      }
    }
  })
  found
}

///|
fn command_has_additional_producers(command : @parser.Command) -> Bool {
  let mut found = false
  @semantics.walk_command(command, fn(current) {
    if found {
      return
    }
    visit_direct_words_in_command(current, fn(word, _) {
      if word_has_additional_producers(word) {
        found = true
      }
    })
    if found {
      return
    }
    for redirect in current.redirects {
      match redirect.target {
        @parser.RedirectionTarget::HereDoc(doc) =>
          match doc.parts {
            Some(parts) =>
              if here_doc_parts_have_additional_producers(parts) {
                found = true
                return
              }
            None => ()
          }
        _ => ()
      }
    }
  })
  found
}

///|
fn word_has_additional_consumers(word : @parser.Word) -> Bool {
  let mut found = false
  walk_word_deep(word, fn(part) {
    match part {
      @parser.WordPart::CommandSubstitution(script)
      | @parser.WordPart::BraceCommandSubstitution(_, script)
      | @parser.WordPart::BackQuoted(script) =>
        if script.items.length() > 0 {
          found = true
        }
      @parser.WordPart::ProcessSubstitution(direction, script) =>
        if direction == "<" && script.items.length() > 0 {
          found = true
        }
      _ => ()
    }
  })
  found
}

///|
fn word_has_additional_producers(word : @parser.Word) -> Bool {
  let mut found = false
  walk_word_deep(word, fn(part) {
    match part {
      @parser.WordPart::ProcessSubstitution(direction, script) =>
        if direction == ">" && script.items.length() > 0 {
          found = true
        }
      _ => ()
    }
  })
  found
}

///|
fn here_doc_parts_have_additional_consumers(
  parts : Array[@parser.WordPart],
) -> Bool {
  for part in parts {
    if word_part_has_additional_consumers(part) {
      return true
    }
  }
  false
}

///|
fn here_doc_parts_have_additional_producers(
  parts : Array[@parser.WordPart],
) -> Bool {
  for part in parts {
    if word_part_has_additional_producers(part) {
      return true
    }
  }
  false
}

///|
fn word_part_has_additional_consumers(part : @parser.WordPart) -> Bool {
  let mut found = false
  walk_word_part_deep(part, fn(nested) {
    match nested {
      @parser.WordPart::CommandSubstitution(script)
      | @parser.WordPart::BraceCommandSubstitution(_, script)
      | @parser.WordPart::BackQuoted(script) =>
        if script.items.length() > 0 {
          found = true
        }
      @parser.WordPart::ProcessSubstitution(direction, script) =>
        if direction == "<" && script.items.length() > 0 {
          found = true
        }
      _ => ()
    }
  })
  found
}

///|
fn word_part_has_additional_producers(part : @parser.WordPart) -> Bool {
  let mut found = false
  walk_word_part_deep(part, fn(nested) {
    match nested {
      @parser.WordPart::ProcessSubstitution(direction, script) =>
        if direction == ">" && script.items.length() > 0 {
          found = true
        }
      _ => ()
    }
  })
  found
}

///|
fn first_redirect_with_fd(
  redirects : Array[@parser.Redirection],
  fd : Int,
) -> @parser.Redirection? {
  for redirect in redirects {
    if redirect_default_fds(redirect).contains(fd) {
      return Some(redirect)
    }
  }
  None
}

///|
fn redirect_default_fds(redirect : @parser.Redirection) -> Array[Int] {
  match redirect.source {
    Some(@parser.RedirectionSource::All) =>
      match redirect.op {
        @parser.RedirectionOperator::Write
        | @parser.RedirectionOperator::Append
        | @parser.RedirectionOperator::Clobber => [1, 2]
        _ => []
      }
    Some(@parser.RedirectionSource::Fd(fd)) =>
      if redirect_uses_default_fd(redirect) {
        [fd]
      } else {
        []
      }
    Some(@parser.RedirectionSource::Named(_)) => []
    None =>
      match redirect.op {
        @parser.RedirectionOperator::Read
        | @parser.RedirectionOperator::HereDoc
        | @parser.RedirectionOperator::HereDocStrip
        | @parser.RedirectionOperator::HereString => [0]
        @parser.RedirectionOperator::ReadWrite => [0, 1]
        @parser.RedirectionOperator::Write
        | @parser.RedirectionOperator::Append
        | @parser.RedirectionOperator::Clobber => [1]
        @parser.RedirectionOperator::DupInput =>
          if redirect_target_is_dash(redirect) {
            [0]
          } else {
            []
          }
        @parser.RedirectionOperator::DupOutput =>
          if redirect_target_is_dash(redirect) {
            [1]
          } else {
            []
          }
      }
  }
}

///|
fn redirect_uses_default_fd(redirect : @parser.Redirection) -> Bool {
  match redirect.op {
    @parser.RedirectionOperator::Read
    | @parser.RedirectionOperator::Write
    | @parser.RedirectionOperator::Append
    | @parser.RedirectionOperator::ReadWrite
    | @parser.RedirectionOperator::Clobber
    | @parser.RedirectionOperator::HereDoc
    | @parser.RedirectionOperator::HereDocStrip
    | @parser.RedirectionOperator::HereString => true
    @parser.RedirectionOperator::DupInput
    | @parser.RedirectionOperator::DupOutput =>
      redirect_target_is_dash(redirect)
  }
}

///|
fn redirect_target_is_dash(redirect : @parser.Redirection) -> Bool {
  match redirect.target {
    @parser.RedirectionTarget::Word(word) =>
      @semantics.literal_text(word) == Some("-")
    @parser.RedirectionTarget::HereDoc(_) => false
  }
}

///|
fn competing_redirections_message(fds : Array[Int]) -> String {
  if fds.contains(0) {
    return "Multiple redirections compete for stdin. Use cat, tee, or pass filenames instead."
  }
  if fds.contains(1) {
    return "Multiple redirections compete for stdout. Use cat, tee, or pass filenames instead."
  }
  if fds.contains(2) {
    return "Multiple redirections compete for stderr. Use cat, tee, or pass filenames instead."
  }
  "Multiple redirections compete for this file descriptor. Use cat, tee, or pass filenames instead."
}

///|
fn command_does_not_read_stdin_message(name : String) -> String {
  if name == "echo" {
    "Piping to 'echo', a command that doesn't read stdin. Did you want 'cat' instead?"
  } else {
    "Piping to '\{name}', a command that doesn't read stdin. Wrong command or missing xargs?"
  }
}

///|
fn command_does_not_read_stdin_redirect_message(name : String) -> String {
  if name == "echo" {
    "Redirecting to 'echo', a command that doesn't read stdin. Did you want 'cat' instead?"
  } else {
    "Redirecting to '\{name}', a command that doesn't read stdin. Bad quoting, wrong command or missing xargs?"
  }
}

///|
fn indexed_node_is_in_expansion(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
) -> Bool {
  for ancestor in @semantics.find_ancestors(indexed, id) {
    match @semantics.node_ref_of(indexed, ancestor) {
      Some(@semantics.NodeRef::Annotation(_)) => ()
      Some(
        @semantics.NodeRef::WordPart(@parser.WordPart::CommandSubstitution(_))
      )
      | Some(
        @semantics.NodeRef::WordPart(
          @parser.WordPart::BraceCommandSubstitution(_, _)
        )
      )
      | Some(@semantics.NodeRef::WordPart(@parser.WordPart::BackQuoted(_)))
      | Some(
        @semantics.NodeRef::WordPart(
          @parser.WordPart::ProcessSubstitution(_, _)
        )
      ) => return true
      _ => ()
    }
  }
  false
}

///|
fn non_reading_commands() -> Array[String] {
  [
    "alias", "basename", "bg", "cal", "cd", "chgrp", "chmod", "chown", "cp", "du",
    "echo", "export", "fg", "fuser", "getconf", "getopt", "getopts", "ipcrm", "ipcs",
    "jobs", "kill", "ln", "ls", "locale", "mv", "printf", "ps", "pwd", "readlink",
    "realpath", "renice", "rm", "rmdir", "set", "sleep", "touch", "trap", "ulimit",
    "unalias", "uname",
  ]
}

///|
fn check_useless_bang_q(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard @semantics.has_set_e(script) else { return }
  q_visit_script_for_useless_bang(script, 0, 0, true, diagnostics)
}

///|
fn q_visit_script_for_useless_bang(
  script : @parser.Script,
  compound_depth : Int,
  function_depth : Int,
  drop_last : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let limit = if drop_last && script.items.length() > 0 {
    script.items.length() - 1
  } else {
    script.items.length()
  }
  let mut i = 0
  while i < limit {
    q_maybe_push_useless_bang_item(
      script.items[i],
      compound_depth,
      function_depth,
      diagnostics,
    )
    i += 1
  }
  for item in script.items {
    q_visit_and_or_for_useless_bang(
      item.and_or,
      compound_depth,
      function_depth,
      diagnostics,
    )
  }
}

///|
fn q_maybe_push_useless_bang_item(
  item : @parser.ListItem,
  compound_depth : Int,
  function_depth : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard item.and_or.tail.length() == 0 else { return }
  let pipeline = item.and_or.head
  guard pipeline.segments.length() > 0 else { return }
  let segment = pipeline.segments[0]
  guard segment.bangs > 0 else { return }
  let message = "This ! is not on a condition and skips errexit. Use `&& exit 1` instead, or make sure $? is checked."
  let bang_span = span_prefix(segment.span, 1)
  if segment.bangs == 1 {
    push_diagnostic_with_fix(
      diagnostics,
      bang_span,
      CheckSeverity::Info,
      2251,
      message,
      q_useless_bang_fix(
        bang_span,
        pipeline.span.end,
        compound_depth,
        function_depth,
      ),
    )
  } else {
    push_diagnostic(diagnostics, bang_span, CheckSeverity::Info, 2251, message)
  }
}

///|
fn q_useless_bang_fix(
  bang_span : @parser.Span,
  pipeline_end : @parser.Position,
  compound_depth : Int,
  function_depth : Int,
) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      bang_span.start,
      bang_span.end,
      "",
      q_fix_precedence(3, compound_depth, function_depth),
      @fixer.InsertionPoint::after(),
    ),
    @fixer.Replacement::new(
      "",
      pipeline_end,
      pipeline_end,
      " && exit 1",
      q_fix_precedence(4, compound_depth, function_depth),
      @fixer.InsertionPoint::before(),
    ),
  ])
}

///|
fn q_visit_and_or_for_useless_bang(
  list : @parser.AndOrList,
  compound_depth : Int,
  function_depth : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  q_visit_pipeline_for_useless_bang(
    list.head,
    compound_depth,
    function_depth,
    diagnostics,
  )
  for pair in list.tail {
    let (_, pipeline) = pair
    q_visit_pipeline_for_useless_bang(
      pipeline, compound_depth, function_depth, diagnostics,
    )
  }
}

///|
fn q_visit_pipeline_for_useless_bang(
  pipeline : @parser.Pipeline,
  compound_depth : Int,
  function_depth : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for segment in pipeline.segments {
    q_visit_command_for_useless_bang(
      segment.command,
      compound_depth,
      function_depth,
      diagnostics,
    )
  }
}

///|
fn q_visit_function_body_for_useless_bang(
  body : @parser.Command,
  compound_depth : Int,
  function_depth : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match body.kind {
    @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      q_visit_script_for_useless_bang(
        script,
        compound_depth + 1,
        function_depth + 1,
        true,
        diagnostics,
      )
    _ =>
      q_visit_command_for_useless_bang(
        body,
        compound_depth,
        function_depth + 1,
        diagnostics,
      )
  }
}

///|
fn q_visit_command_for_useless_bang(
  command : @parser.Command,
  compound_depth : Int,
  function_depth : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match command.kind {
    @parser.CommandKind::BraceGroup(script) =>
      q_visit_script_for_useless_bang(
        script,
        compound_depth + 1,
        function_depth,
        false,
        diagnostics,
      )
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      q_visit_script_for_useless_bang(
        script,
        compound_depth + 1,
        function_depth,
        true,
        diagnostics,
      )
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        q_visit_script_for_useless_bang(
          arm.condition,
          compound_depth + 1,
          function_depth,
          true,
          diagnostics,
        )
        q_visit_script_for_useless_bang(
          arm.body,
          compound_depth + 1,
          function_depth,
          false,
          diagnostics,
        )
      }
      match clause.else_body {
        Some(body) =>
          q_visit_script_for_useless_bang(
            body,
            compound_depth + 1,
            function_depth,
            false,
            diagnostics,
          )
        None => ()
      }
    }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) => {
      q_visit_script_for_useless_bang(
        clause.condition,
        compound_depth + 1,
        function_depth,
        true,
        diagnostics,
      )
      q_visit_script_for_useless_bang(
        clause.body,
        compound_depth + 1,
        function_depth,
        false,
        diagnostics,
      )
    }
    @parser.CommandKind::ForIn(clause) =>
      q_visit_script_for_useless_bang(
        clause.body,
        compound_depth + 1,
        function_depth,
        false,
        diagnostics,
      )
    @parser.CommandKind::ForArithmetic(clause) =>
      q_visit_script_for_useless_bang(
        clause.body,
        compound_depth + 1,
        function_depth,
        false,
        diagnostics,
      )
    @parser.CommandKind::Select(clause) =>
      q_visit_script_for_useless_bang(
        clause.body,
        compound_depth + 1,
        function_depth,
        false,
        diagnostics,
      )
    @parser.CommandKind::Function(function_) =>
      q_visit_function_body_for_useless_bang(
        function_.body,
        compound_depth,
        function_depth,
        diagnostics,
      )
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Time(_)
    | @parser.CommandKind::Case(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_)
    | @parser.CommandKind::CoProc(_) => ()
  }
}

///|
fn check_modified_arithmetic_in_redirection_q(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell != @semantics.ShellDialect::Dash &&
    shell != @semantics.ShellDialect::BusyboxSh else {
    return
  }
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) if simple.words.length() > 0 =>
        for redirect in command.redirects {
          q_check_redirection_for_modified_arithmetic(redirect, diagnostics)
        }
      _ => ()
    }
  })
}

///|
fn q_check_redirection_for_modified_arithmetic(
  redirect : @parser.Redirection,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match redirect.target {
    @parser.RedirectionTarget::Word(word) =>
      for part in word.parts {
        q_check_redirection_word_part(part, word, diagnostics)
      }
    @parser.RedirectionTarget::HereDoc(doc) =>
      match doc.parts {
        Some(parts) =>
          for part in parts {
            q_check_redirection_here_doc_part(part, redirect.span, diagnostics)
          }
        None => ()
      }
  }
}

///|
fn q_check_redirection_word_part(
  part : @parser.WordPart,
  word : @parser.Word,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match part {
    @parser.WordPart::ArithmeticExpansion(expr)
    | @parser.WordPart::DollarBracket(expr) =>
      q_maybe_push_modified_arithmetic_diagnostic(
        expr,
        word.span,
        Some(word.source),
        diagnostics,
      )
    _ => ()
  }
}

///|
fn q_check_redirection_here_doc_part(
  part : @parser.WordPart,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match part {
    @parser.WordPart::ArithmeticExpansion(expr)
    | @parser.WordPart::DollarBracket(expr) =>
      q_maybe_push_modified_arithmetic_diagnostic(expr, span, None, diagnostics)
    _ => ()
  }
}

///|
fn q_maybe_push_modified_arithmetic_diagnostic(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  source : String?,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match q_assignment_effect_span(expr, span, source) {
    Some(effect_span) =>
      push_diagnostic(
        diagnostics,
        effect_span,
        CheckSeverity::Warning,
        2257,
        "Arithmetic modifications in command redirections may be discarded. Do them separately.",
      )
    None => ()
  }
}

///|
fn q_assignment_effect_span(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  source : String?,
) -> @parser.Span? {
  match q_first_assignment_effect_offset(expr.raw) {
    Some((offset, op)) =>
      match source {
        Some(source_text) =>
          match q_string_index_of(source_text, expr.raw) {
            Some(expr_offset) =>
              Some(q_span_offset(span, expr_offset + offset, op[:].length()))
            None => Some(q_span_offset(span, offset, op[:].length()))
          }
        None => Some(q_span_offset(span, offset, op[:].length()))
      }
    None => None
  }
}

///|
fn q_first_assignment_effect_offset(raw : String) -> (Int, String)? {
  let view = raw[:]
  let mut i = 0
  let mut paren_depth = 0
  let mut brace_depth = 0
  let mut bracket_depth = 0
  let mut in_single = false
  let mut in_double = false
  let mut escaped = false
  while i < view.length() {
    let ch = view[i]
    if escaped {
      escaped = false
      i += 1
      continue
    }
    if in_single {
      if ch == '\'' {
        in_single = false
      }
      i += 1
      continue
    }
    if in_double {
      if ch == '\\' {
        escaped = true
      } else if ch == '"' {
        in_double = false
      }
      i += 1
      continue
    }
    match ch {
      '\'' => {
        in_single = true
        i += 1
      }
      '"' => {
        in_double = true
        i += 1
      }
      '\\' => {
        escaped = true
        i += 1
      }
      '(' => {
        paren_depth += 1
        i += 1
      }
      ')' => {
        if paren_depth > 0 {
          paren_depth -= 1
        }
        i += 1
      }
      '{' => {
        brace_depth += 1
        i += 1
      }
      '}' => {
        if brace_depth > 0 {
          brace_depth -= 1
        }
        i += 1
      }
      '[' => {
        bracket_depth += 1
        i += 1
      }
      ']' => {
        if bracket_depth > 0 {
          bracket_depth -= 1
        }
        i += 1
      }
      _ =>
        if paren_depth == 0 && brace_depth == 0 && bracket_depth == 0 {
          match q_assignment_effect_operator_at(raw, i) {
            Some(op) => return Some((i, op))
            None => i += 1
          }
        } else {
          i += 1
        }
    }
  }
  None
}

///|
fn q_assignment_effect_operator_at(raw : String, offset : Int) -> String? {
  for op in q_assignment_effect_operators() {
    let length = op[:].length()
    if offset + length > raw.length() {
      continue
    }
    let fragment = raw
      .view(start_offset=offset, end_offset=offset + length)
      .to_string()
    if fragment == op && q_operator_is_effectful(raw, offset, op) {
      return Some(op)
    }
  }
  None
}

///|
fn q_assignment_effect_operators() -> Array[String] {
  [
    "<<=", ">>=", "+=", "-=", "*=", "/=", "%=", "&=", "^=", "|=", "++", "--", "=",
  ]
}

///|
fn q_operator_is_effectful(raw : String, offset : Int, op : String) -> Bool {
  if op != "=" {
    return true
  }
  let before = if offset > 0 {
    Some(raw.view(start_offset=offset - 1, end_offset=offset).to_string())
  } else {
    None
  }
  let after = if offset + 1 < raw.length() {
    Some(raw.view(start_offset=offset + 1, end_offset=offset + 2).to_string())
  } else {
    None
  }
  before != Some("!") &&
  before != Some("<") &&
  before != Some(">") &&
  before != Some("=") &&
  after != Some("=")
}

///|
fn check_bad_test_and_or_q(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  q_visit_script_for_bad_test_and_or(script, 0, 0, diagnostics)
}

///|
fn q_visit_script_for_bad_test_and_or(
  script : @parser.Script,
  compound_depth : Int,
  function_depth : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for item in script.items {
    if item.terminator is Some(@parser.Terminator::Background) &&
      q_and_or_last_command_is_test(item.and_or) {
      let operator_span = q_background_terminator_span(item)
      push_diagnostic_with_fix(
        diagnostics,
        operator_span,
        CheckSeverity::Error,
        2265,
        "Use && for logical AND. Single & will background and return true.",
        @fixer.Fix::from_replacements([
          @fixer.Replacement::new(
            "",
            operator_span.end,
            operator_span.end,
            "&",
            q_fix_precedence(3, compound_depth, function_depth),
            @fixer.InsertionPoint::before(),
          ),
        ]),
      )
    }
    q_visit_and_or_for_bad_test_and_or(
      item.and_or,
      compound_depth,
      function_depth,
      diagnostics,
    )
  }
}

///|
fn q_and_or_last_command_is_test(list : @parser.AndOrList) -> Bool {
  let pipeline = match list.tail.get(list.tail.length() - 1) {
    Some((_, pipeline)) => pipeline
    None => list.head
  }
  match pipeline.segments.get(pipeline.segments.length() - 1) {
    Some(segment) => q_command_is_test_command(segment.command)
    None => false
  }
}

///|
fn q_background_terminator_span(item : @parser.ListItem) -> @parser.Span {
  @parser.Span::new(
    item.and_or.span.end,
    q_position_advance(item.and_or.span.end, 1),
  )
}

///|
fn q_visit_and_or_for_bad_test_and_or(
  list : @parser.AndOrList,
  compound_depth : Int,
  function_depth : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  q_visit_pipeline_for_bad_test_and_or(
    list.head,
    compound_depth,
    function_depth,
    diagnostics,
  )
  for pair in list.tail {
    let (_, pipeline) = pair
    q_visit_pipeline_for_bad_test_and_or(
      pipeline, compound_depth, function_depth, diagnostics,
    )
  }
}

///|
fn q_visit_pipeline_for_bad_test_and_or(
  pipeline : @parser.Pipeline,
  compound_depth : Int,
  function_depth : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut i = 0
  while i < pipeline.operators.length() {
    if pipeline.operators[i] is @parser.PipeOperator::Pipe &&
      (
        q_command_is_test_command(pipeline.segments[i].command) ||
        q_command_is_test_command(pipeline.segments[i + 1].command)
      ) {
      let operator_span = q_pipe_operator_span(pipeline, i, 1)
      push_diagnostic_with_fix(
        diagnostics,
        operator_span,
        CheckSeverity::Warning,
        2266,
        "Use || for logical OR. Single | will pipe.",
        @fixer.Fix::from_replacements([
          @fixer.Replacement::new(
            "",
            operator_span.end,
            operator_span.end,
            "|",
            q_fix_precedence(4, compound_depth, function_depth),
            @fixer.InsertionPoint::before(),
          ),
        ]),
      )
    }
    i += 1
  }
  for segment in pipeline.segments {
    q_visit_command_for_bad_test_and_or(
      segment.command,
      compound_depth,
      function_depth,
      diagnostics,
    )
  }
}

///|
fn q_visit_function_body_for_bad_test_and_or(
  body : @parser.Command,
  compound_depth : Int,
  function_depth : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match body.kind {
    @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      q_visit_script_for_bad_test_and_or(
        script,
        compound_depth + 1,
        function_depth + 1,
        diagnostics,
      )
    _ =>
      q_visit_command_for_bad_test_and_or(
        body,
        compound_depth,
        function_depth + 1,
        diagnostics,
      )
  }
}

///|
fn q_visit_command_for_bad_test_and_or(
  command : @parser.Command,
  compound_depth : Int,
  function_depth : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match command.kind {
    @parser.CommandKind::Time(clause) =>
      q_visit_pipeline_for_bad_test_and_or(
        clause.body,
        compound_depth + 1,
        function_depth,
        diagnostics,
      )
    @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      q_visit_script_for_bad_test_and_or(
        script,
        compound_depth + 1,
        function_depth,
        diagnostics,
      )
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        q_visit_script_for_bad_test_and_or(
          arm.condition,
          compound_depth + 1,
          function_depth,
          diagnostics,
        )
        q_visit_script_for_bad_test_and_or(
          arm.body,
          compound_depth + 1,
          function_depth,
          diagnostics,
        )
      }
      match clause.else_body {
        Some(body) =>
          q_visit_script_for_bad_test_and_or(
            body,
            compound_depth + 1,
            function_depth,
            diagnostics,
          )
        None => ()
      }
    }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) => {
      q_visit_script_for_bad_test_and_or(
        clause.condition,
        compound_depth + 1,
        function_depth,
        diagnostics,
      )
      q_visit_script_for_bad_test_and_or(
        clause.body,
        compound_depth + 1,
        function_depth,
        diagnostics,
      )
    }
    @parser.CommandKind::ForIn(clause) =>
      q_visit_script_for_bad_test_and_or(
        clause.body,
        compound_depth + 1,
        function_depth,
        diagnostics,
      )
    @parser.CommandKind::ForArithmetic(clause) =>
      q_visit_script_for_bad_test_and_or(
        clause.body,
        compound_depth + 1,
        function_depth,
        diagnostics,
      )
    @parser.CommandKind::Select(clause) =>
      q_visit_script_for_bad_test_and_or(
        clause.body,
        compound_depth + 1,
        function_depth,
        diagnostics,
      )
    @parser.CommandKind::Case(clause) =>
      for item in clause.items {
        q_visit_script_for_bad_test_and_or(
          item.body,
          compound_depth + 1,
          function_depth,
          diagnostics,
        )
      }
    @parser.CommandKind::Function(function_) =>
      q_visit_function_body_for_bad_test_and_or(
        function_.body,
        compound_depth,
        function_depth,
        diagnostics,
      )
    @parser.CommandKind::CoProc(clause) =>
      q_visit_command_for_bad_test_and_or(
        clause.body,
        compound_depth + 1,
        function_depth,
        diagnostics,
      )
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_) => ()
  }
}

///|
fn q_command_is_test_command(command : @parser.Command) -> Bool {
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
fn q_fix_precedence(
  base : Int,
  compound_depth : Int,
  function_depth : Int,
) -> Int {
  base + compound_depth * 3 + function_depth
}

///|
fn q_pipe_operator_span(
  pipeline : @parser.Pipeline,
  operator_index : Int,
  width : Int,
) -> @parser.Span {
  match pipeline.segments.get(operator_index) {
    Some(current_segment) => {
      let start = current_segment.span.end
      let end_ = @parser.Position::new(
        start.offset + width,
        start.line,
        start.column + width,
      )
      @parser.Span::new(start, end_)
    }
    None => pipeline.span
  }
}

///|
fn q_position_advance(
  position : @parser.Position,
  width : Int,
) -> @parser.Position {
  @parser.Position::new(
    position.offset + width,
    position.line,
    position.column + width,
  )
}

///|
fn q_span_offset(
  span : @parser.Span,
  offset : Int,
  width : Int,
) -> @parser.Span {
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
fn q_string_index_of(text : String, needle : String) -> Int? {
  let haystack = text[:]
  let target = needle[:]
  guard target.length() > 0 else { return Some(0) }
  if target.length() > haystack.length() {
    return None
  }
  let limit = haystack.length() - target.length()
  let mut i = 0
  while i <= limit {
    let mut matched = true
    let mut j = 0
    while j < target.length() {
      if haystack[i + j] != target[j] {
        matched = false
        break
      }
      j += 1
    }
    if matched {
      return Some(i)
    }
    i += 1
  }
  None
}
