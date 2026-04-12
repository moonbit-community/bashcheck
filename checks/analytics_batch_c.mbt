///|
fn append_analytics_batch_c_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_c_descriptions() {
    descriptions.push(description)
  }
}

///|
// CHECK THIS: THUNK
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
      code: 2181,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Check command success directly instead of reading $?.",
    },
    {
      code: 2128,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Expanding an array without an index only yields the first element.",
    },
    {
      code: 2218,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Functions should be defined before they are invoked.",
    },
    {
      code: 2247,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Flip leading $ and \" if this should be a quoted substitution.",
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
  check_exit_code_tests(script, diagnostics)
  check_dollar_quote_paren(script, diagnostics)
  let cfg = @cfg.build_cfg(
    script,
    @cfg.CfgParameters::new(
      @semantics.has_lastpipe(script, shell),
      @semantics.has_pipefail(script),
    ),
  )
  let analysis = @cfg.analyze_control_flow(cfg)
  check_array_without_index(cfg, analysis, diagnostics)
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
fn check_exit_code_tests(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let first_function_commands = collect_first_function_command_spans(script)
  visit_script_commands(script, fn(command) {
    if first_function_commands.any(fn(span) { span == command.span }) {
      return
    }
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        visit_exit_code_condition_expr(condition.expr, diagnostics)
      _ => ()
    }
  })
}

///|
fn visit_exit_code_condition_expr(
  expr : @parser.ConditionExpr,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match expr {
    @parser.ConditionExpr::Binary(op, _, lhs, rhs) =>
      match exit_code_test_diagnostic(op, lhs, rhs) {
        Some((span, message)) =>
          push_diagnostic(
            diagnostics,
            span,
            CheckSeverity::Style,
            2181,
            message,
          )
        None => ()
      }
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      visit_exit_code_condition_expr(inner, diagnostics)
    @parser.ConditionExpr::And(lhs, rhs)
    | @parser.ConditionExpr::Or(lhs, rhs) => {
      visit_exit_code_condition_expr(lhs, diagnostics)
      visit_exit_code_condition_expr(rhs, diagnostics)
    }
    @parser.ConditionExpr::Empty
    | @parser.ConditionExpr::Word(_)
    | @parser.ConditionExpr::Unary(_, _, _) => ()
  }
}

///|
fn exit_code_test_diagnostic(
  op : String,
  lhs : @parser.Word,
  rhs : @parser.Word,
) -> (@parser.Span, String)? {
  if word_is_zero_literal(rhs) && word_is_exit_code(lhs) {
    return Some(
      (lhs.span, exit_code_test_message(exit_code_test_checks_success_lhs(op))),
    )
  }
  if word_is_zero_literal(lhs) && word_is_exit_code(rhs) {
    return Some(
      (rhs.span, exit_code_test_message(exit_code_test_checks_success_rhs(op))),
    )
  }
  None
}

///|
fn exit_code_test_checks_success_lhs(op : String) -> Bool {
  op != "-gt" && op != "-ne" && op != "!=" && op != "!"
}

///|
fn exit_code_test_checks_success_rhs(op : String) -> Bool {
  op != "-ne" && op != "!="
}

///|
fn exit_code_test_message(for_success : Bool) -> String {
  "Check exit code directly with e.g. 'if " +
  (if for_success { "" } else { "! " }) +
  "mycmd;', not indirectly with $?."
}

///|
fn word_is_zero_literal(word : @parser.Word) -> Bool {
  @semantics.literal_text(word) == Some("0")
}

///|
fn word_is_exit_code(word : @parser.Word) -> Bool {
  @semantics.literal_text(word) == Some("?")
}

///|
fn check_array_without_index(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for id in @cfg.ast_ids(cfg) {
    match @cfg.ast_ref_of(cfg, id) {
      Some(@semantics.NodeRef::WordPart(@parser.WordPart::Parameter(name))) =>
        maybe_push_array_without_index_diagnostic(
          cfg, analysis, id, name, diagnostics,
        )
      Some(@semantics.NodeRef::ParameterExpansion(expansion)) =>
        match plain_array_parameter_name(expansion) {
          Some(name) =>
            maybe_push_array_without_index_diagnostic(
              cfg, analysis, id, name, diagnostics,
            )
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn plain_array_parameter_name(
  expansion : @parser.ParameterExpansion,
) -> String? {
  if expansion.length_prefix ||
    expansion.indirect ||
    expansion.index is Some(_) ||
    parameter_has_names_operator(expansion) {
    return None
  }
  match expansion.operator {
    None => expansion.name
    _ => None
  }
}

///|
fn maybe_push_array_without_index_diagnostic(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  name : String,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match @cfg.incoming_state_of_ast(analysis, id) {
    Some(state) if state.state_is_reachable &&
      @cfg.variable_may_be_array(state, name) =>
      push_diagnostic(
        diagnostics,
        ast_effect_span(cfg, id),
        CheckSeverity::Warning,
        2128,
        "Expanding an array without an index only gives the first element.",
      )
    _ => ()
  }
}

///|
fn collect_first_function_command_spans(
  script : @parser.Script,
) -> Array[@parser.Span] {
  let spans : Array[@parser.Span] = []
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Function(function_) =>
        match first_executable_command(function_.body) {
          Some(first) => spans.push(first.span)
          None => ()
        }
      _ => ()
    }
  })
  spans
}

///|
fn first_executable_command(command : @parser.Command) -> @parser.Command? {
  match command.kind {
    @parser.CommandKind::Time(clause) =>
      first_executable_command_in_pipeline(clause.body)
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      first_executable_command_in_script(script)
    @parser.CommandKind::If(clause) =>
      match clause.arms.get(0) {
        Some(arm) => first_executable_command_in_script(arm.condition)
        None => Some(command)
      }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) =>
      first_executable_command_in_script(clause.condition)
    @parser.CommandKind::ForIn(clause) =>
      first_executable_command_in_script(clause.body)
    @parser.CommandKind::ForArithmetic(clause) =>
      first_executable_command_in_script(clause.body)
    @parser.CommandKind::Select(clause) =>
      first_executable_command_in_script(clause.body)
    @parser.CommandKind::Case(clause) =>
      match clause.items.get(0) {
        Some(item) => first_executable_command_in_script(item.body)
        None => Some(command)
      }
    @parser.CommandKind::CoProc(clause) => first_executable_command(clause.body)
    @parser.CommandKind::Function(function_) =>
      first_executable_command(function_.body)
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_) => Some(command)
  }
}

///|
fn first_executable_command_in_script(
  script : @parser.Script,
) -> @parser.Command? {
  for item in script.items {
    match first_executable_command_in_and_or(item.and_or) {
      Some(command) => return Some(command)
      None => ()
    }
  }
  None
}

///|
fn first_executable_command_in_and_or(
  list : @parser.AndOrList,
) -> @parser.Command? {
  match first_executable_command_in_pipeline(list.head) {
    Some(command) => return Some(command)
    None => ()
  }
  for pair in list.tail {
    let (_, pipeline) = pair
    match first_executable_command_in_pipeline(pipeline) {
      Some(command) => return Some(command)
      None => ()
    }
  }
  None
}

///|
fn first_executable_command_in_pipeline(
  pipeline : @parser.Pipeline,
) -> @parser.Command? {
  for segment in pipeline.segments {
    match first_executable_command(segment.command) {
      Some(command) => return Some(command)
      None => ()
    }
  }
  None
}

///|
fn check_dollar_quote_paren(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      if !word_starts_with_dollar_quote_paren(word) {
        return
      }
      push_diagnostic_with_fix(
        diagnostics,
        word.span,
        CheckSeverity::Warning,
        2247,
        "Flip leading $ and \" if this should be a quoted substitution.",
        @fixer.Fix::from_replacements([
          @fixer.Replacement::new(
            "",
            word.span.start,
            span_prefix(word.span, 2).end,
            "\"$",
            7,
            @fixer.InsertionPoint::after(),
          ),
        ]),
      )
    })
  })
}

///|
fn word_starts_with_dollar_quote_paren(word : @parser.Word) -> Bool {
  match word.parts {
    [@parser.WordPart::DollarDoubleQuoted(parts)] =>
      match parts.get(0) {
        Some(@parser.WordPart::Literal(text)) => {
          let view = text[:]
          view.length() > 0 && (view[0] == '(' || view[0] == '{')
        }
        _ => false
      }
    _ => false
  }
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
