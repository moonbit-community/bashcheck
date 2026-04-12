///|
fn append_analytics_batch_o_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_o_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_o_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2264,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "This function unconditionally re-invokes itself.",
    },
  ]
}

///|
fn run_analytics_batch_o_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_blatant_recursion(script, diagnostics)
}

///|
fn check_blatant_recursion(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Function(function_def) =>
        check_blatant_recursion_function(
          function_def.name,
          function_def.body,
          diagnostics,
        )
      _ => ()
    }
  })
}

///|
fn check_blatant_recursion_function(
  function_name : String,
  body : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match blatant_recursion_first_sequence_commands(body) {
    Some(commands) =>
      for command in commands {
        check_blatant_recursion_command(function_name, command, diagnostics)
      }
    None => ()
  }
}

///|
fn function_has_blatant_recursion(
  function_name : String,
  body : @parser.Command,
) -> Bool {
  match blatant_recursion_first_sequence_commands(body) {
    Some(commands) =>
      commands.any(fn(command) {
        blatant_recursion_command_word(function_name, command) is Some(_)
      })
    None => false
  }
}

///|
fn blatant_recursion_first_sequence_commands(
  command : @parser.Command,
) -> Array[@parser.Command]? {
  match command.kind {
    @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      blatant_recursion_first_pipeline_commands(script)
    @parser.CommandKind::If(clause) =>
      match clause.arms.get(0) {
        Some(arm) => blatant_recursion_first_pipeline_commands(arm.condition)
        None =>
          match clause.else_body {
            Some(body) => blatant_recursion_first_pipeline_commands(body)
            None => None
          }
      }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) =>
      blatant_recursion_first_pipeline_commands(clause.condition)
    @parser.CommandKind::ForIn(clause) =>
      blatant_recursion_first_pipeline_commands(clause.body)
    @parser.CommandKind::ForArithmetic(clause) =>
      blatant_recursion_first_pipeline_commands(clause.body)
    @parser.CommandKind::Select(clause) =>
      blatant_recursion_first_pipeline_commands(clause.body)
    @parser.CommandKind::CoProc(clause) =>
      blatant_recursion_first_sequence_commands(clause.body)
    _ => None
  }
}

///|
fn blatant_recursion_first_pipeline_commands(
  script : @parser.Script,
) -> Array[@parser.Command]? {
  match script.items.get(0) {
    Some(item) => blatant_recursion_pipeline_commands(item.and_or.head)
    None => None
  }
}

///|
fn blatant_recursion_pipeline_commands(
  pipeline : @parser.Pipeline,
) -> Array[@parser.Command]? {
  guard pipeline.segments.length() > 0 else { return None }
  let commands : Array[@parser.Command] = []
  for segment in pipeline.segments {
    commands.push(segment.command)
  }
  Some(commands)
}

///|
fn check_blatant_recursion_command(
  function_name : String,
  command : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match blatant_recursion_command_word(function_name, command) {
    Some(word) =>
      push_diagnostic_with_fix(
        diagnostics,
        word.span,
        CheckSeverity::Error,
        2264,
        "This function unconditionally re-invokes itself. Missing 'command'?",
        blatant_recursion_fix(word),
      )
    None => ()
  }
}

///|
fn blatant_recursion_command_word(
  function_name : String,
  command : @parser.Command,
) -> @parser.Word? {
  match (@semantics.command_name(command), command.kind) {
    (Some(name), @parser.CommandKind::Simple(simple)) if name == function_name =>
      simple.words.get(0)
    _ => None
  }
}

///|
fn blatant_recursion_fix(word : @parser.Word) -> @fixer.Fix {
  let precedence = word.span.start.column + 3
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      word.span.start,
      word.span.start,
      "command ",
      precedence,
      @fixer.InsertionPoint::after(),
    ),
  ])
}
