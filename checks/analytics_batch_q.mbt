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
  ]
}

///|
fn run_analytics_batch_q_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  let indexed = @semantics.build_index(script)
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
