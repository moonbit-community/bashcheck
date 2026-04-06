///|
// CHECK THIS: THUNK
fn control_flow_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2154,
      severity: CheckSeverity::Warning,
      category: "control-flow",
      summary: "Referenced variable may not be assigned on all paths.",
    },
    {
      code: 2178,
      severity: CheckSeverity::Warning,
      category: "control-flow",
      summary: "Variable was used as an array but is now assigned a string.",
    },
    {
      code: 2179,
      severity: CheckSeverity::Warning,
      category: "control-flow",
      summary: "Use array+=(\"item\") to append items to an array.",
    },
    {
      code: 2317,
      severity: CheckSeverity::Info,
      category: "control-flow",
      summary: "Command appears to be unreachable.",
    },
  ]
}

///|
fn control_flow_suite() -> ToggleableCheckSuiteRegistration {
  {
    name: "control-flow",
    descriptions: control_flow_descriptions(),
    run: run_control_flow_checks,
  }
}

///|
fn run_control_flow_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let cfg = @cfg.build_cfg(
    script,
    @cfg.CfgParameters::new(
      @semantics.has_lastpipe(script, shell),
      @semantics.has_pipefail(script),
    ),
  )
  let analysis = @cfg.analyze_control_flow(cfg)
  for id in @cfg.ast_ids(cfg) {
    match @cfg.ast_ref_of(cfg, id) {
      Some(@semantics.NodeRef::Command(command)) => {
        check_unreachable_command(cfg, analysis, id, command, diagnostics)
        check_command_reads(cfg, analysis, id, command, false, diagnostics)
      }
      Some(@semantics.NodeRef::Assignment(assignment)) =>
        check_array_scalar_conflict(cfg, analysis, id, assignment, diagnostics)
      Some(@semantics.NodeRef::WordPart(@parser.WordPart::Parameter(name))) =>
        check_unassigned_read(cfg, analysis, id, name, false, diagnostics)
      Some(
        @semantics.NodeRef::WordPart(@parser.WordPart::SpecialParameter(name))
      ) => check_unassigned_read(cfg, analysis, id, name, false, diagnostics)
      Some(@semantics.NodeRef::ParameterExpansion(expansion)) =>
        check_parameter_expansion_read(
          cfg, analysis, id, expansion, false, diagnostics,
        )
      _ => ()
    }
  }
}

///|
fn run_unassigned_uppercase_optional_check(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let cfg = @cfg.build_cfg(
    script,
    @cfg.CfgParameters::new(
      @semantics.has_lastpipe(script, shell),
      @semantics.has_pipefail(script),
    ),
  )
  let analysis = @cfg.analyze_control_flow(cfg)
  for id in @cfg.ast_ids(cfg) {
    match @cfg.ast_ref_of(cfg, id) {
      Some(@semantics.NodeRef::Command(command)) =>
        check_command_reads(cfg, analysis, id, command, true, diagnostics)
      Some(@semantics.NodeRef::WordPart(@parser.WordPart::Parameter(name))) =>
        check_unassigned_read(cfg, analysis, id, name, true, diagnostics)
      Some(
        @semantics.NodeRef::WordPart(@parser.WordPart::SpecialParameter(name))
      ) => check_unassigned_read(cfg, analysis, id, name, true, diagnostics)
      Some(@semantics.NodeRef::ParameterExpansion(expansion)) =>
        check_parameter_expansion_read(
          cfg, analysis, id, expansion, true, diagnostics,
        )
      _ => ()
    }
  }
}

///|
fn check_command_reads(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  command : @parser.Command,
  uppercase_only : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match command.kind {
    @parser.CommandKind::Arithmetic(arithmetic) =>
      check_arithmetic_expr_reads(
        cfg,
        analysis,
        id,
        arithmetic.expr,
        uppercase_only,
        diagnostics,
      )
    @parser.CommandKind::ForArithmetic(clause) => {
      check_arithmetic_expr_reads(
        cfg,
        analysis,
        id,
        clause.init,
        uppercase_only,
        diagnostics,
      )
      check_arithmetic_expr_reads(
        cfg,
        analysis,
        id,
        clause.condition,
        uppercase_only,
        diagnostics,
      )
      check_arithmetic_expr_reads(
        cfg,
        analysis,
        id,
        clause.step,
        uppercase_only,
        diagnostics,
      )
    }
    _ => ()
  }
}

///|
fn check_unreachable_command(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  command : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard !@cfg.command_is_reachable(analysis, id) else { return }
  guard !has_unreachable_command_ancestor(cfg, analysis, id) else { return }
  guard command_is_reportable(command) else { return }
  push_diagnostic(
    diagnostics,
    command.span,
    CheckSeverity::Info,
    2317,
    "Command appears to be unreachable. Check usage (or ignore if invoked indirectly).",
  )
}

///|
fn has_unreachable_command_ancestor(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
) -> Bool {
  let mut current = @cfg.ast_parent_of(cfg, id)
  while current is Some(_) {
    match current {
      Some(parent) =>
        match @cfg.ast_ref_of(cfg, parent) {
          Some(@semantics.NodeRef::Command(_)) =>
            if !@cfg.command_is_reachable(analysis, parent) {
              return true
            } else {
              current = @cfg.ast_parent_of(cfg, parent)
            }
          _ => current = @cfg.ast_parent_of(cfg, parent)
        }
      None => ()
    }
  }
  false
}

///|
fn command_is_reportable(command : @parser.Command) -> Bool {
  match command.kind {
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_)
    | @parser.CommandKind::Time(_) => true
    _ => false
  }
}

///|
fn check_array_scalar_conflict(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  assignment : @parser.Assignment,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard assignment.indexes.length() == 0 else { return }
  guard !assignment_value_is_array_literal(assignment.value) else { return }
  match @cfg.incoming_state_of_ast(analysis, id) {
    Some(state) if state.state_is_reachable =>
      if @cfg.variable_may_be_array(state, assignment.name) {
        if assignment.append {
          push_diagnostic(
            diagnostics,
            assignment_name_span(assignment),
            CheckSeverity::Warning,
            2179,
            "Use array+=(\"item\") to append items to an array.",
          )
        } else {
          push_diagnostic(
            diagnostics,
            assignment_name_span(assignment),
            CheckSeverity::Warning,
            2178,
            "Variable was used as an array but is now assigned a string.",
          )
        }
      }
    _ => ()
  }
  ignore(cfg)
}

///|
fn assignment_value_is_array_literal(value : @parser.AssignmentValue) -> Bool {
  match value {
    @parser.AssignmentValue::ArrayLiteral(_) => true
    _ => false
  }
}

///|
fn check_parameter_expansion_read(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  expansion : @parser.ParameterExpansion,
  uppercase_only : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard !parameter_expansion_allows_unset(expansion) else { return }
  match expansion.name {
    Some(name) =>
      check_unassigned_read(
        cfg, analysis, id, name, uppercase_only, diagnostics,
      )
    None => ()
  }
}

///|
fn check_unassigned_read(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  name : String,
  uppercase_only : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard should_consider_variable_name(name, uppercase_only) else { return }
  guard !read_is_guarded(cfg, id, name) else { return }
  match @cfg.incoming_state_of_ast(analysis, id) {
    Some(state) if state.state_is_reachable =>
      if variable_is_unassigned(state, name) {
        push_diagnostic(
          diagnostics,
          ast_effect_span(cfg, id),
          CheckSeverity::Warning,
          2154,
          "\{name} is referenced but not assigned.",
        )
      }
    _ => ()
  }
}

///|
fn read_is_guarded(cfg : @cfg.CFG, id : @cfg.CfgAstId, name : String) -> Bool {
  guarded_by_alternate_parameter_expansion(cfg, id, name) ||
  guarded_by_condition_success(cfg, id, name)
}

///|
fn guarded_by_alternate_parameter_expansion(
  cfg : @cfg.CFG,
  id : @cfg.CfgAstId,
  name : String,
) -> Bool {
  let mut current = @cfg.ast_parent_of(cfg, id)
  while current is Some(_) {
    match current {
      Some(parent) =>
        match @cfg.ast_ref_of(cfg, parent) {
          Some(@semantics.NodeRef::ParameterExpansion(expansion)) =>
            if expansion.name == Some(name) {
              match expansion.operator {
                Some(@parser.ParameterOperator::AlternateValue(_)) =>
                  return true
                _ => ()
              }
            }
          _ => ()
        }
      None => ()
    }
    current = match current {
      Some(parent) => @cfg.ast_parent_of(cfg, parent)
      None => None
    }
  }
  false
}

///|
fn guarded_by_condition_success(
  cfg : @cfg.CFG,
  id : @cfg.CfgAstId,
  name : String,
) -> Bool {
  let mut current = @cfg.ast_parent_of(cfg, id)
  while current is Some(_) {
    let parent = match current {
      Some(parent) => parent
      None => break
    }
    if if_arm_body_is_guarded(cfg, parent, id, name) ||
      while_body_is_guarded(cfg, parent, id, name) {
      return true
    }
    current = @cfg.ast_parent_of(cfg, parent)
  }
  false
}

///|
fn if_arm_body_is_guarded(
  cfg : @cfg.CFG,
  candidate : @cfg.CfgAstId,
  target : @cfg.CfgAstId,
  name : String,
) -> Bool {
  let target_span = ast_effect_span(cfg, target)
  match @cfg.ast_ref_of(cfg, candidate) {
    Some(@semantics.NodeRef::IfArm(arm)) =>
      span_contains(arm.body.span, target_span) &&
      script_success_proves_defined(arm.condition, name)
    _ => false
  }
}

///|
fn while_body_is_guarded(
  cfg : @cfg.CFG,
  candidate : @cfg.CfgAstId,
  target : @cfg.CfgAstId,
  name : String,
) -> Bool {
  let target_span = ast_effect_span(cfg, target)
  let parent = match @cfg.ast_parent_of(cfg, candidate) {
    Some(parent) => parent
    None => return false
  }
  match (@cfg.ast_ref_of(cfg, candidate), @cfg.ast_ref_of(cfg, parent)) {
    (
      Some(@semantics.NodeRef::LoopClause(clause)),
      Some(@semantics.NodeRef::Command(command)),
    ) =>
      match command.kind {
        @parser.CommandKind::While(_) =>
          span_contains(clause.body.span, target_span) &&
          script_success_proves_defined(clause.condition, name)
        _ => false
      }
    _ => false
  }
}

///|
fn script_success_proves_defined(
  script : @parser.Script,
  name : String,
) -> Bool {
  match last_script_list_item(script) {
    Some(item) => and_or_list_success_proves_defined(item.and_or, name)
    None => false
  }
}

///|
fn and_or_list_success_proves_defined(
  list : @parser.AndOrList,
  name : String,
) -> Bool {
  let mut proved = pipeline_success_proves_defined(list.head, name)
  for pair in list.tail {
    let (op, pipeline) = pair
    let next = pipeline_success_proves_defined(pipeline, name)
    proved = match op {
      @parser.AndOrOperator::AndIf => proved || next
      @parser.AndOrOperator::OrIf => proved && next
    }
  }
  proved
}

///|
fn pipeline_success_proves_defined(
  pipeline : @parser.Pipeline,
  name : String,
) -> Bool {
  guard pipeline.segments.length() == 1 else { return false }
  let segment = pipeline.segments[0]
  if segment.bangs % 2 != 0 {
    return false
  }
  command_success_proves_defined(segment.command, name)
}

///|
fn command_success_proves_defined(
  command : @parser.Command,
  name : String,
) -> Bool {
  match command.kind {
    @parser.CommandKind::Condition(condition) =>
      condition_expr_success_proves_defined(condition.expr, name)
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      script_success_proves_defined(script, name)
    @parser.CommandKind::Time(clause) =>
      pipeline_success_proves_defined(clause.body, name)
    _ => false
  }
}

///|
fn last_script_list_item(script : @parser.Script) -> @parser.ListItem? {
  guard script.items.length() > 0 else { return None }
  script.items.get(script.items.length() - 1)
}

///|
fn check_arithmetic_expr_reads(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  expr : @parser.ArithmeticExpr,
  uppercase_only : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut i = 0
  while i < expr.tokens.length() {
    match expr.tokens[i] {
      @parser.ArithmeticToken::Variable(name, _) =>
        if arithmetic_token_needs_read(expr.tokens, i) {
          check_unassigned_read(
            cfg, analysis, id, name, uppercase_only, diagnostics,
          )
        }
      @parser.ArithmeticToken::Group(inner) =>
        check_arithmetic_expr_reads(
          cfg, analysis, id, inner, uppercase_only, diagnostics,
        )
      _ => ()
    }
    i += 1
  }
}

///|
fn arithmetic_token_needs_read(
  tokens : Array[@parser.ArithmeticToken],
  index : Int,
) -> Bool {
  match tokens[index] {
    @parser.ArithmeticToken::Variable(_, _) =>
      match arithmetic_next_operator(tokens, index) {
        Some("=") => false
        _ => true
      }
    _ => true
  }
}

///|
fn arithmetic_next_operator(
  tokens : Array[@parser.ArithmeticToken],
  index : Int,
) -> String? {
  let mut i = index + 1
  while i < tokens.length() {
    match tokens[i] {
      @parser.ArithmeticToken::Operator(op) => return Some(op)
      _ => ()
    }
    i += 1
  }
  None
}

///|
fn condition_expr_success_proves_defined(
  expr : @parser.ConditionExpr,
  name : String,
) -> Bool {
  match expr {
    @parser.ConditionExpr::Unary(op, word) =>
      (op == "-v" || op == "-R") &&
      condition_test_target_name(word) == Some(name)
    @parser.ConditionExpr::Group(inner) =>
      condition_expr_success_proves_defined(inner, name)
    @parser.ConditionExpr::And(lhs, rhs) =>
      condition_expr_success_proves_defined(lhs, name) ||
      condition_expr_success_proves_defined(rhs, name)
    @parser.ConditionExpr::Or(lhs, rhs) =>
      condition_expr_success_proves_defined(lhs, name) &&
      condition_expr_success_proves_defined(rhs, name)
    _ => false
  }
}

///|
fn condition_test_target_name(word : @parser.Word) -> String? {
  let text = match @semantics.literal_text(word) {
    Some(text) => text
    None =>
      match @semantics.leading_unquoted_text(word) {
        Some(text) => text
        None => return None
      }
  }
  let view = text[:]
  let mut end = 0
  while end < view.length() &&
        is_identifier_continue(view[end].unsafe_to_char()) {
    end += 1
  }
  let name = text.view(end_offset=end).to_string()
  if name != "" && is_identifier_name(name) {
    Some(name)
  } else {
    None
  }
}

///|
fn is_identifier_name(name : String) -> Bool {
  let view = name[:]
  guard view.length() > 0 else { return false }
  if !is_identifier_start(view[0].unsafe_to_char()) {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if !is_identifier_continue(view[i].unsafe_to_char()) {
      return false
    }
    i += 1
  }
  true
}

///|
fn ast_effect_span(cfg : @cfg.CFG, id : @cfg.CfgAstId) -> @parser.Span {
  match @cfg.ast_enclosing_span_of(cfg, id) {
    Some(span) => span
    None => panic()
  }
}

///|
fn span_contains(outer : @parser.Span, inner : @parser.Span) -> Bool {
  outer.start.offset <= inner.start.offset &&
  inner.end.offset <= outer.end.offset
}

///|
fn variable_is_unassigned(state : @cfg.ProgramState, name : String) -> Bool {
  match state.variables_in_scope.get(name) {
    Some(_) => @cfg.variable_may_be_unset(state, name)
    None => true
  }
}

///|
fn should_consider_variable_name(name : String, uppercase_only : Bool) -> Bool {
  if name == "" {
    return false
  }
  let view = name[:]
  let first = view[0].unsafe_to_char()
  if !is_identifier_start(first) {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if !is_identifier_continue(view[i].unsafe_to_char()) {
      return false
    }
    i += 1
  }
  if uppercase_only {
    !variable_name_has_lower(name) && variable_name_has_upper(name)
  } else {
    variable_name_has_lower(name)
  }
}

///|
fn variable_name_has_lower(name : String) -> Bool {
  for ch in name {
    if 'a' <= ch && ch <= 'z' {
      return true
    }
  }
  false
}

///|
fn variable_name_has_upper(name : String) -> Bool {
  for ch in name {
    if 'A' <= ch && ch <= 'Z' {
      return true
    }
  }
  false
}

///|
fn is_identifier_start(ch : Char) -> Bool {
  ('a' <= ch && ch <= 'z') || ('A' <= ch && ch <= 'Z') || ch == '_'
}

///|
fn is_identifier_continue(ch : Char) -> Bool {
  is_identifier_start(ch) || ('0' <= ch && ch <= '9')
}
