///|
fn append_analytics_batch_c_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_c_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_c_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2000,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Prefer ${#var} over echo \"$var\" | wc -c.",
    },
    {
      code: 2087,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Quote ssh heredoc delimiters when the body expands locally.",
    },
    {
      code: 2218,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Functions should be defined before they are invoked.",
    },
    {
      code: 2319,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Using $? after a test can accidentally read the test status instead.",
    },
    {
      code: 2320,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Using $? after echo/printf can accidentally read the print status instead.",
    },
  ]
}

///|
fn run_analytics_batch_c_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_echo_wc(script, diagnostics)
  check_ssh_here_doc(script, diagnostics)
  let cfg = @cfg.build_cfg(
    script,
    @cfg.CfgParameters::new(
      @semantics.has_lastpipe(script, shell),
      @semantics.has_pipefail(script),
    ),
  )
  let analysis = @cfg.analyze_control_flow(cfg)
  check_use_before_definition(cfg, analysis, diagnostics)
  check_overwritten_exit_code(cfg, analysis, diagnostics)
}

///|
fn check_echo_wc(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_pipelines(script, fn(pipeline) {
    if pipeline.segments.length() != 2 {
      return
    }
    let lhs = @semantics.oversimplify_command(pipeline.segments[0].command)
    let rhs = @semantics.oversimplify_command(pipeline.segments[1].command)
    if lhs == ["echo", "${VAR}"] && (rhs == ["wc", "-c"] || rhs == ["wc", "-m"]) {
      push_diagnostic(
        diagnostics,
        pipeline.span,
        CheckSeverity::Style,
        2000,
        "See if you can use ${#variable} instead.",
      )
    }
  })
}

///|
fn check_ssh_here_doc(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    guard command_matches_basename(command, "ssh") else { return }
    for redirect in command.redirects {
      match redirect.target {
        @parser.RedirectionTarget::HereDoc(doc) =>
          if !doc.quoted && here_doc_has_expansion(doc) {
            push_diagnostic(
              diagnostics,
              here_doc_delimiter_span(redirect, doc.delimiter),
              CheckSeverity::Warning,
              2087,
              "Quote '\{doc.delimiter}' to make here document expansions happen on the server side rather than on the client.",
            )
          }
        @parser.RedirectionTarget::Word(_) => ()
      }
    }
  })
}

///|
fn here_doc_has_expansion(doc : @parser.HereDoc) -> Bool {
  match doc.parts {
    Some(parts) => word_parts_have_dynamic_expansion(parts)
    None => false
  }
}

///|
fn word_parts_have_dynamic_expansion(parts : Array[@parser.WordPart]) -> Bool {
  for part in parts {
    if word_part_has_dynamic_expansion(part) {
      return true
    }
  }
  false
}

///|
fn word_part_has_dynamic_expansion(part : @parser.WordPart) -> Bool {
  match part {
    @parser.WordPart::Literal(_)
    | @parser.WordPart::SingleQuoted(_)
    | @parser.WordPart::DollarSingleQuoted(_)
    | @parser.WordPart::Glob(_) => false
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      word_parts_have_dynamic_expansion(parts)
    @parser.WordPart::ExtGlob(pattern) =>
      pattern.alternatives.any(fn(word) { word_has_dynamic_expansion(word) })
    @parser.WordPart::BraceExpansion(expansion) =>
      expansion.elements.any(fn(word) { word_has_dynamic_expansion(word) })
    @parser.WordPart::Parameter(_)
    | @parser.WordPart::SpecialParameter(_)
    | @parser.WordPart::BracedParameter(_)
    | @parser.WordPart::BraceCommandSubstitution(_, _)
    | @parser.WordPart::CommandSubstitution(_)
    | @parser.WordPart::BackQuoted(_)
    | @parser.WordPart::ArithmeticExpansion(_)
    | @parser.WordPart::DollarBracket(_)
    | @parser.WordPart::ProcessSubstitution(_, _) => true
  }
}

///|
fn word_has_dynamic_expansion(word : @parser.Word) -> Bool {
  word.parts.any(word_part_has_dynamic_expansion)
}

///|
fn here_doc_delimiter_span(
  redirect : @parser.Redirection,
  delimiter : String,
) -> @parser.Span {
  let end_ = redirect.span.end
  let width = delimiter.length()
  let start = @parser.Position::new(
    end_.offset - width,
    end_.line,
    end_.column - width,
  )
  @parser.Span::new(start, end_)
}

///|
fn check_use_before_definition(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let functions : Map[String, Array[@cfg.CfgAstId]] = Map::new()
  let mut has_function = false
  for id in @cfg.ast_ids(cfg) {
    match @cfg.ast_ref_of(cfg, id) {
      Some(@semantics.NodeRef::FunctionDef(function_def)) => {
        push_function_definition(functions, function_def.name, id)
        has_function = true
      }
      _ => ()
    }
  }
  guard has_function else { return }
  for id in @cfg.ast_ids(cfg) {
    match @cfg.ast_ref_of(cfg, id) {
      Some(@semantics.NodeRef::SimpleCommand(simple)) =>
        match simple_command_name_word(simple) {
          Some((name, word)) =>
            match functions.get(name) {
              Some(definitions) =>
                if function_is_only_defined_later(analysis, id, definitions) {
                  push_diagnostic(
                    diagnostics,
                    word.span,
                    CheckSeverity::Error,
                    2218,
                    "This function is only defined later. Move the definition up.",
                  )
                }
              None => ()
            }
          None => ()
        }
      _ => ()
    }
  }
  ignore(cfg)
}

///|
fn push_function_definition(
  functions : Map[String, Array[@cfg.CfgAstId]],
  name : String,
  id : @cfg.CfgAstId,
) -> Unit {
  match functions.get(name) {
    Some(definitions) => {
      let updated : Array[@cfg.CfgAstId] = []
      for definition in definitions {
        updated.push(definition)
      }
      updated.push(id)
      functions.set(name, updated)
    }
    None => functions.set(name, [id])
  }
}

///|
fn simple_command_name_word(
  simple : @parser.SimpleCommand,
) -> (String, @parser.Word)? {
  match simple.words.get(0) {
    Some(word) =>
      match @semantics.literal_text(word) {
        Some(name) => Some((name, word))
        None => None
      }
    None => None
  }
}

///|
fn function_is_only_defined_later(
  analysis : @cfg.CfgAnalysis,
  invocation : @cfg.CfgAstId,
  definitions : Array[@cfg.CfgAstId],
) -> Bool {
  let mut defined_later = false
  let mut defined_earlier = false
  for definition in definitions {
    if @cfg.does_post_dominate(analysis, definition, invocation) {
      defined_later = true
    }
    if @cfg.does_post_dominate(analysis, invocation, definition) {
      defined_earlier = true
    }
  }
  defined_later && !defined_earlier
}

///|
fn check_overwritten_exit_code(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for id in @cfg.ast_ids(cfg) {
    match @cfg.ast_ref_of(cfg, id) {
      Some(
        @semantics.NodeRef::WordPart(@parser.WordPart::SpecialParameter("?"))
      ) =>
        check_overwritten_exit_code_use(
          cfg,
          analysis,
          id,
          exit_code_span(cfg, id),
          diagnostics,
        )
      Some(@semantics.NodeRef::ParameterExpansion(expansion)) =>
        if parameter_expansion_is_exit_code(expansion) {
          check_overwritten_exit_code_use(
            cfg,
            analysis,
            id,
            exit_code_span(cfg, id),
            diagnostics,
          )
        }
      _ => ()
    }
  }
}

///|
fn parameter_expansion_is_exit_code(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  !expansion.length_prefix && !expansion.indirect && expansion.name == Some("?")
}

///|
fn check_overwritten_exit_code_use(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match @cfg.incoming_state_of_ast(analysis, id) {
    Some(state) if state.state_is_reachable => {
      let mut has_exit_code = false
      let mut all_conditions = true
      let mut all_printing = true
      for exit_id in state.exit_codes {
        has_exit_code = true
        if !exit_code_is_condition_like(cfg, exit_id) {
          all_conditions = false
        }
        if !exit_code_is_printing_command(cfg, exit_id) {
          all_printing = false
        }
      }
      if !has_exit_code {
        return
      }
      if all_conditions &&
        !exit_codes_used_unconditionally(analysis, id, state.exit_codes) {
        push_diagnostic(
          diagnostics,
          span,
          CheckSeverity::Warning,
          2319,
          "This $? refers to a condition, not a command. Assign to a variable to avoid it being overwritten.",
        )
      }
      if all_printing {
        push_diagnostic(
          diagnostics,
          span,
          CheckSeverity::Warning,
          2320,
          "This $? refers to echo/printf, not a previous command. Assign to variable to avoid it being overwritten.",
        )
      }
    }
    _ => ()
  }
}

///|
fn precise_ast_span(cfg : @cfg.CFG, id : @cfg.CfgAstId) -> @parser.Span {
  match @cfg.ast_span_of(cfg, id) {
    Some(span) => span
    None => ast_effect_span(cfg, id)
  }
}

///|
fn exit_code_span(cfg : @cfg.CFG, id : @cfg.CfgAstId) -> @parser.Span {
  match @cfg.ast_ref_of(cfg, id) {
    Some(@semantics.NodeRef::WordPart(@parser.WordPart::SpecialParameter("?"))) =>
      match parent_word_of(cfg, id) {
        Some(word) =>
          match word_subspan(word, "$?") {
            Some(span) => span
            None => precise_ast_span(cfg, id)
          }
        None => precise_ast_span(cfg, id)
      }
    Some(@semantics.NodeRef::ParameterExpansion(_)) =>
      match parent_word_of(cfg, id) {
        Some(word) =>
          match word_subspan(word, "${?}") {
            Some(span) => span
            None => precise_ast_span(cfg, id)
          }
        None => precise_ast_span(cfg, id)
      }
    _ => precise_ast_span(cfg, id)
  }
}

///|
fn parent_word_of(cfg : @cfg.CFG, id : @cfg.CfgAstId) -> @parser.Word? {
  match @cfg.ast_parent_of(cfg, id) {
    Some(parent) =>
      match @cfg.ast_ref_of(cfg, parent) {
        Some(@semantics.NodeRef::Word(word)) => Some(word)
        Some(@semantics.NodeRef::WordPart(_)) => parent_word_of(cfg, parent)
        _ => None
      }
    None => None
  }
}

///|
fn word_subspan(word : @parser.Word, needle : String) -> @parser.Span? {
  match string_index_of(word.source, needle) {
    Some(index) => {
      let start = @parser.Position::new(
        word.span.start.offset + index,
        word.span.start.line,
        word.span.start.column + index,
      )
      let end_ = @parser.Position::new(
        start.offset + needle.length(),
        start.line,
        start.column + needle.length(),
      )
      Some(@parser.Span::new(start, end_))
    }
    None => None
  }
}

///|
fn string_index_of(text : String, needle : String) -> Int? {
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

///|
fn exit_code_is_condition_like(cfg : @cfg.CFG, id : @cfg.CfgAstId) -> Bool {
  match @cfg.ast_ref_of(cfg, id) {
    Some(@semantics.NodeRef::ConditionCommand(_)) => true
    Some(@semantics.NodeRef::Command(command)) =>
      match command.kind {
        @parser.CommandKind::Condition(_) => true
        _ => command_matches_basename(command, "test")
      }
    Some(@semantics.NodeRef::SimpleCommand(_)) =>
      match parent_command_of(cfg, id) {
        Some(command) => command_matches_basename(command, "test")
        None => false
      }
    _ => false
  }
}

///|
fn exit_code_is_printing_command(cfg : @cfg.CFG, id : @cfg.CfgAstId) -> Bool {
  match @cfg.ast_ref_of(cfg, id) {
    Some(@semantics.NodeRef::Command(command)) =>
      command_matches_basename(command, "echo") ||
      command_matches_basename(command, "printf")
    Some(@semantics.NodeRef::SimpleCommand(_)) =>
      match parent_command_of(cfg, id) {
        Some(command) =>
          command_matches_basename(command, "echo") ||
          command_matches_basename(command, "printf")
        None => false
      }
    _ => false
  }
}

///|
fn parent_command_of(cfg : @cfg.CFG, id : @cfg.CfgAstId) -> @parser.Command? {
  match @cfg.ast_parent_of(cfg, id) {
    Some(parent) =>
      match @cfg.ast_ref_of(cfg, parent) {
        Some(@semantics.NodeRef::Command(command)) => Some(command)
        _ => None
      }
    None => None
  }
}

///|
fn exit_codes_used_unconditionally(
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  exit_codes : Set[@cfg.CfgAstId],
) -> Bool {
  for exit_code in exit_codes {
    if !@cfg.does_post_dominate(analysis, id, exit_code) {
      return false
    }
  }
  true
}
