///|
fn append_analytics_batch_k_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_k_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_k_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2095,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Commands in while read loops may swallow stdin.",
    },
  ]
}

///|
fn run_analytics_batch_k_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_while_read_pitfalls(script, diagnostics)
}

///|
fn check_while_read_pitfalls(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  analytics_visit_while_read_script(script, None, 0, 0, 0, 0, diagnostics)
}

///|
fn analytics_visit_while_read_script(
  script : @parser.Script,
  active_loop_span : @parser.Span?,
  structure_depth : Int,
  substitution_depth : Int,
  substitution_bonus : Int,
  background_bonus : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for item in script.items {
    let item_background_delta = match item.terminator {
      Some(@parser.Terminator::Background) => 1
      _ => 0
    }
    let item_background_bonus = background_bonus + item_background_delta
    analytics_visit_while_read_pipeline(
      item.and_or.head,
      active_loop_span,
      structure_depth,
      substitution_depth,
      substitution_bonus,
      item_background_bonus,
      diagnostics,
    )
    for pair in item.and_or.tail {
      let (_, pipeline) = pair
      analytics_visit_while_read_pipeline(
        pipeline, active_loop_span, structure_depth, substitution_depth, substitution_bonus,
        item_background_bonus, diagnostics,
      )
    }
  }
}

///|
fn analytics_visit_while_read_pipeline(
  pipeline : @parser.Pipeline,
  active_loop_span : @parser.Span?,
  structure_depth : Int,
  substitution_depth : Int,
  substitution_bonus : Int,
  background_bonus : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match pipeline.segments.get(0) {
    Some(segment) =>
      analytics_visit_while_read_command(
        segment.command,
        active_loop_span,
        structure_depth,
        substitution_depth,
        substitution_bonus,
        background_bonus,
        diagnostics,
      )
    None => ()
  }
}

///|
fn analytics_visit_while_read_command(
  command : @parser.Command,
  active_loop_span : @parser.Span?,
  structure_depth : Int,
  substitution_depth : Int,
  substitution_bonus : Int,
  background_bonus : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_direct_words_in_command(command, fn(word, place) {
    analytics_visit_while_read_word(
      word, place, active_loop_span, structure_depth, substitution_depth, substitution_bonus,
      background_bonus, diagnostics,
    )
  })

  if active_loop_span is Some(loop_span) {
    match
      analytics_while_read_muncher_diagnostic(
        command, structure_depth, substitution_depth, substitution_bonus, background_bonus,
      ) {
      Some((info_message, warning_message, fix)) => {
        push_diagnostic(
          diagnostics,
          loop_span,
          CheckSeverity::Info,
          2095,
          info_message,
        )
        push_diagnostic_with_fix(
          diagnostics,
          analytics_while_read_warning_span(command),
          CheckSeverity::Warning,
          2095,
          warning_message,
          fix,
        )
      }
      None => ()
    }
  }

  match command.kind {
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) => {
      let condition_loop_span = if active_loop_span is Some(loop_span) {
        Some(loop_span)
      } else {
        None
      }
      analytics_visit_while_read_script(
        clause.condition,
        condition_loop_span,
        structure_depth + 1,
        substitution_depth,
        substitution_bonus,
        background_bonus,
        diagnostics,
      )
      let body_loop_span = if analytics_command_is_while_read_loop(command) {
        Some(command.span)
      } else {
        active_loop_span
      }
      analytics_visit_while_read_script(
        clause.body,
        body_loop_span,
        structure_depth + 1,
        substitution_depth,
        substitution_bonus,
        background_bonus,
        diagnostics,
      )
    }
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      analytics_visit_while_read_script(
        script,
        active_loop_span,
        structure_depth + 1,
        substitution_depth,
        substitution_bonus,
        background_bonus,
        diagnostics,
      )
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        analytics_visit_while_read_script(
          arm.condition,
          active_loop_span,
          structure_depth + 1,
          substitution_depth,
          substitution_bonus,
          background_bonus,
          diagnostics,
        )
        analytics_visit_while_read_script(
          arm.body,
          active_loop_span,
          structure_depth + 1,
          substitution_depth,
          substitution_bonus,
          background_bonus,
          diagnostics,
        )
      }
      match clause.else_body {
        Some(body) =>
          analytics_visit_while_read_script(
            body,
            active_loop_span,
            structure_depth + 1,
            substitution_depth,
            substitution_bonus,
            background_bonus,
            diagnostics,
          )
        None => ()
      }
    }
    @parser.CommandKind::ForIn(clause) =>
      analytics_visit_while_read_script(
        clause.body,
        active_loop_span,
        structure_depth + 1,
        substitution_depth,
        substitution_bonus,
        background_bonus,
        diagnostics,
      )
    @parser.CommandKind::ForArithmetic(clause) =>
      analytics_visit_while_read_script(
        clause.body,
        active_loop_span,
        structure_depth + 1,
        substitution_depth,
        substitution_bonus,
        background_bonus,
        diagnostics,
      )
    @parser.CommandKind::Select(clause) =>
      analytics_visit_while_read_script(
        clause.body,
        active_loop_span,
        structure_depth + 1,
        substitution_depth,
        substitution_bonus,
        background_bonus,
        diagnostics,
      )
    @parser.CommandKind::Case(clause) =>
      for item in clause.items {
        analytics_visit_while_read_script(
          item.body,
          active_loop_span,
          structure_depth + 1,
          substitution_depth,
          substitution_bonus,
          background_bonus,
          diagnostics,
        )
      }
    @parser.CommandKind::Function(function_) =>
      analytics_visit_while_read_command(
        function_.body,
        active_loop_span,
        structure_depth + 1,
        substitution_depth,
        substitution_bonus,
        background_bonus,
        diagnostics,
      )
    @parser.CommandKind::CoProc(clause) =>
      analytics_visit_while_read_command(
        clause.body,
        active_loop_span,
        structure_depth + 1,
        substitution_depth,
        substitution_bonus,
        background_bonus,
        diagnostics,
      )
    @parser.CommandKind::Time(clause) =>
      analytics_visit_while_read_pipeline(
        clause.body,
        active_loop_span,
        structure_depth + 1,
        substitution_depth,
        substitution_bonus,
        background_bonus,
        diagnostics,
      )
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_) => ()
  }
}

///|
fn analytics_visit_while_read_word(
  word : @parser.Word,
  place : WordPlace,
  active_loop_span : @parser.Span?,
  structure_depth : Int,
  substitution_depth : Int,
  substitution_bonus : Int,
  background_bonus : Int,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  walk_word_deep(word, fn(part) {
    match part {
      @parser.WordPart::CommandSubstitution(script)
      | @parser.WordPart::BraceCommandSubstitution(_, script)
      | @parser.WordPart::BackQuoted(script) => {
        let nested_bonus = if place == WordPlace::AssignmentValue {
          1
        } else {
          0
        }
        analytics_visit_while_read_script(
          script,
          active_loop_span,
          structure_depth,
          substitution_depth + 1,
          if substitution_bonus > nested_bonus {
            substitution_bonus
          } else {
            nested_bonus
          },
          background_bonus,
          diagnostics,
        )
      }
      _ => ()
    }
  })
}

///|
fn analytics_command_is_while_read_loop(command : @parser.Command) -> Bool {
  match command.kind {
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) =>
      analytics_script_is_stdin_read_loop(clause.condition)
    _ => false
  }
}

///|
fn analytics_script_is_stdin_read_loop(script : @parser.Script) -> Bool {
  match script.items {
    [item] if item.and_or.tail.length() == 0 =>
      match item.and_or.head.segments {
        [segment] => analytics_command_is_stdin_read_command(segment.command)
        _ => false
      }
    _ => false
  }
}

///|
fn analytics_command_is_stdin_read_command(command : @parser.Command) -> Bool {
  match @semantics.effective_command_name(command) {
    Some("read") => {
      if command.redirects.any(analytics_redirection_reads_from_stdin) {
        return false
      }
      !@semantics.effective_command_arguments(command).any(fn(argument) {
        @semantics.literal_text(argument) == Some("-u")
      })
    }
    _ => false
  }
}

///|
fn analytics_redirection_reads_from_stdin(
  redirect : @parser.Redirection,
) -> Bool {
  let source_reads_stdin = match redirect.source {
    None => true
    Some(@parser.RedirectionSource::Fd(fd)) => fd == 0
    Some(@parser.RedirectionSource::All) => true
    Some(@parser.RedirectionSource::Named(_)) => false
  }
  if !source_reads_stdin {
    return false
  }
  match redirect.op {
    @parser.RedirectionOperator::Read
    | @parser.RedirectionOperator::ReadWrite
    | @parser.RedirectionOperator::HereDoc
    | @parser.RedirectionOperator::HereDocStrip
    | @parser.RedirectionOperator::HereString
    | @parser.RedirectionOperator::DupInput => true
    _ => false
  }
}

///|
fn analytics_while_read_muncher_diagnostic(
  command : @parser.Command,
  structure_depth : Int,
  substitution_depth : Int,
  substitution_bonus : Int,
  background_bonus : Int,
) -> (String, String, @fixer.Fix)? {
  let command_name = match @semantics.effective_command_name(command) {
    Some(name) => name
    None => return None
  }
  if analytics_command_has_stdin_redirect(command) {
    return None
  }
  let fix = match command_name {
    "ssh" => {
      if analytics_effective_command_arguments_contain(command, "-n") {
        return None
      }
      analytics_insert_before_position_fix(
        analytics_effective_command_name_position(command),
        " -n",
        analytics_while_read_fix_precedence(
          9, structure_depth, substitution_depth, substitution_bonus, background_bonus,
        ),
      )
    }
    "ffmpeg" => {
      if analytics_effective_command_arguments_contain(command, "-nostdin") {
        return None
      }
      analytics_insert_before_position_fix(
        analytics_effective_command_name_position(command),
        " -nostdin",
        analytics_while_read_fix_precedence(
          9, structure_depth, substitution_depth, substitution_bonus, background_bonus,
        ),
      )
    }
    "mplayer" => {
      if analytics_effective_command_arguments_contain(
          command, "-noconsolecontrols",
        ) {
        return None
      }
      analytics_insert_before_position_fix(
        analytics_effective_command_name_position(command),
        " -noconsolecontrols",
        analytics_while_read_fix_precedence(
          9, structure_depth, substitution_depth, substitution_bonus, background_bonus,
        ),
      )
    }
    "HandBrakeCLI" =>
      analytics_insert_before_position_fix(
        command.span.end,
        " < /dev/null",
        analytics_while_read_fix_precedence(
          8, structure_depth, substitution_depth, substitution_bonus, background_bonus,
        ),
      )
    _ => return None
  }
  Some(
    (
      "\{command_name} may swallow stdin, preventing this loop from working properly.",
      analytics_while_read_warning_message(command_name),
      fix,
    ),
  )
}

///|
fn analytics_command_has_stdin_redirect(command : @parser.Command) -> Bool {
  command.redirects.any(analytics_redirection_reads_from_stdin)
}

///|
fn analytics_effective_command_arguments_contain(
  command : @parser.Command,
  value : String,
) -> Bool {
  @semantics.effective_command_arguments(command).any(fn(argument) {
    @semantics.literal_text(argument) == Some(value)
  })
}

///|
fn analytics_effective_command_name_position(
  command : @parser.Command,
) -> @parser.Position {
  match @semantics.effective_command_words(command).get(0) {
    Some(word) => word.span.end
    None => command.span.end
  }
}

///|
fn analytics_while_read_warning_span(command : @parser.Command) -> @parser.Span {
  let words = @semantics.effective_command_words(command)
  let start = match words.get(0) {
    Some(word) => word.span.start
    None => command.span.start
  }
  let mut end_ = start
  for word in words {
    if word.span.end.offset > end_.offset {
      end_ = word.span.end
    }
  }
  for redirect in command.redirects {
    if redirect.span.end.offset > end_.offset {
      end_ = redirect.span.end
    }
  }
  if end_ == start {
    command.span
  } else {
    @parser.Span::new(start, end_)
  }
}

///|
fn analytics_while_read_fix_precedence(
  base_precedence : Int,
  structure_depth : Int,
  substitution_depth : Int,
  substitution_bonus : Int,
  background_bonus : Int,
) -> Int {
  let structure_bonus = if structure_depth > 0 {
    (structure_depth - 1) * 3
  } else {
    0
  }
  base_precedence +
  structure_bonus +
  substitution_depth * 5 +
  substitution_bonus +
  background_bonus
}

///|
fn analytics_insert_before_position_fix(
  position : @parser.Position,
  text : String,
  precedence : Int,
) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      position,
      position,
      text,
      precedence,
      @fixer.InsertionPoint::before(),
    ),
  ])
}

///|
fn analytics_while_read_warning_message(command_name : String) -> String {
  match command_name {
    "ssh" => "Use ssh -n to prevent ssh from swallowing stdin."
    "ffmpeg" => "Use ffmpeg -nostdin to prevent ffmpeg from swallowing stdin."
    "mplayer" =>
      "Use mplayer -noconsolecontrols to prevent mplayer from swallowing stdin."
    "HandBrakeCLI" =>
      "Use HandBrakeCLI < /dev/null to prevent HandBrakeCLI from swallowing stdin."
    _ =>
      "Use \{command_name} with an explicit stdin guard to prevent it from swallowing stdin."
  }
}
