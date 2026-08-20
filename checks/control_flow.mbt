///|
// CHECK THIS: THUNK
fn control_flow_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2154,
      severity: Warning,
      category: "control-flow",
      summary: "Referenced variable may not be assigned on all paths.",
    },
    {
      code: 2178,
      severity: Warning,
      category: "control-flow",
      summary: "Variable was used as an array but is now assigned a string.",
    },
    {
      code: 2179,
      severity: Warning,
      category: "control-flow",
      summary: "Use array+=(\"item\") to append items to an array.",
    },
    {
      code: 2317,
      severity: Info,
      category: "control-flow",
      summary: "Command appears to be unreachable.",
    },
    {
      code: 2329,
      severity: Info,
      category: "control-flow",
      summary: "This function is never invoked.",
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
  let lastpipe = @semantics.has_lastpipe(script, shell)
  let cfg = @cfg.build_cfg(
    script,
    @cfg.CfgParameters::new(lastpipe, @semantics.has_pipefail(script)),
  )
  let analysis = @cfg.analyze_control_flow(cfg)
  let dead_subshell_reads = batch_v_dead_read_ids(cfg, lastpipe)
  for id in @cfg.ast_ids(cfg) {
    match @cfg.ast_ref_of(cfg, id) {
      Some(Command(command)) => {
        check_unreachable_command(cfg, analysis, id, command, diagnostics)
        check_command_reads(
          cfg, analysis, id, command, false, dead_subshell_reads, diagnostics,
        )
      }
      Some(FunctionDef(function_def)) =>
        check_unreachable_function(cfg, analysis, id, function_def, diagnostics)
      Some(Assignment(assignment)) =>
        check_array_scalar_conflict(cfg, analysis, id, assignment, diagnostics)
      Some(WordPart(Parameter(name))) =>
        check_unassigned_read(
          cfg, analysis, id, name, false, dead_subshell_reads, diagnostics,
        )
      Some(WordPart(SpecialParameter(name))) =>
        check_unassigned_read(
          cfg, analysis, id, name, false, dead_subshell_reads, diagnostics,
        )
      Some(ParameterExpansion(expansion)) =>
        check_parameter_expansion_read(
          cfg, analysis, id, expansion, false, dead_subshell_reads, diagnostics,
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
  let lastpipe = @semantics.has_lastpipe(script, shell)
  let cfg = @cfg.build_cfg(
    script,
    @cfg.CfgParameters::new(lastpipe, @semantics.has_pipefail(script)),
  )
  let analysis = @cfg.analyze_control_flow(cfg)
  let dead_subshell_reads = batch_v_dead_read_ids(cfg, lastpipe)
  for id in @cfg.ast_ids(cfg) {
    match @cfg.ast_ref_of(cfg, id) {
      Some(Command(command)) =>
        check_command_reads(
          cfg, analysis, id, command, true, dead_subshell_reads, diagnostics,
        )
      Some(WordPart(Parameter(name))) =>
        check_unassigned_read(
          cfg, analysis, id, name, true, dead_subshell_reads, diagnostics,
        )
      Some(WordPart(SpecialParameter(name))) =>
        check_unassigned_read(
          cfg, analysis, id, name, true, dead_subshell_reads, diagnostics,
        )
      Some(ParameterExpansion(expansion)) =>
        check_parameter_expansion_read(
          cfg, analysis, id, expansion, true, dead_subshell_reads, diagnostics,
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
  dead_subshell_reads : Array[@cfg.CfgAstId],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match command.kind {
    Arithmetic(arithmetic) =>
      check_arithmetic_expr_reads(
        cfg,
        analysis,
        id,
        arithmetic.expr,
        uppercase_only,
        dead_subshell_reads,
        diagnostics,
      )
    ForArithmetic(clause) => {
      check_arithmetic_expr_reads(
        cfg,
        analysis,
        id,
        clause.init,
        uppercase_only,
        dead_subshell_reads,
        diagnostics,
      )
      check_arithmetic_expr_reads(
        cfg,
        analysis,
        id,
        clause.condition,
        uppercase_only,
        dead_subshell_reads,
        diagnostics,
      )
      check_arithmetic_expr_reads(
        cfg,
        analysis,
        id,
        clause.step,
        uppercase_only,
        dead_subshell_reads,
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
  guard !has_unreachable_function_ancestor(cfg, analysis, id) else { return }
  guard !has_source_command_ancestor(cfg, id) else { return }
  guard command_is_reportable(command) else { return }
  push_diagnostic(
    diagnostics,
    command.span,
    Info,
    2317,
    "Command appears to be unreachable. Check usage (or ignore if invoked indirectly).",
  )
}

///|
fn check_unreachable_function(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  function_def : @parser.FunctionDef,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard !function_def_is_reachable(cfg, analysis, id) else { return }
  guard has_reachable_terminal_script_command(cfg, analysis) else { return }
  guard function_body_has_reportable_command(function_def.body) else { return }
  guard !function_has_blatant_recursion(function_def.name, function_def.body) else {
    return
  }
  guard !has_unreachable_command_ancestor(cfg, analysis, id) else { return }
  guard !has_unreachable_function_ancestor(cfg, analysis, id) else { return }
  guard !has_source_command_ancestor(cfg, id) else { return }
  push_diagnostic(
    diagnostics,
    control_flow_precise_ast_span(cfg, id),
    Info,
    2329,
    "This function is never invoked. Check usage (or ignored if invoked indirectly).",
  )
}

///|
fn function_body_has_reportable_command(body : @parser.Command) -> Bool {
  match body.kind {
    Simple(simple) =>
      simple.words.length() > 0 || simple.assignments.length() > 0
    Source(_) | Condition(_) | Arithmetic(_) => true
    Time(clause) => pipeline_has_reportable_command(clause.body)
    Subshell(script) | BraceGroup(script) | BatsTest({ body: script, .. }) =>
      script_has_reportable_command(script)
    If(clause) => if_clause_has_reportable_command(clause)
    While(clause) | Until(clause) =>
      script_has_reportable_command(clause.condition) ||
      script_has_reportable_command(clause.body)
    ForIn(clause) => script_has_reportable_command(clause.body)
    ForArithmetic(clause) => script_has_reportable_command(clause.body)
    Select(clause) => script_has_reportable_command(clause.body)
    Case(clause) => case_clause_has_reportable_command(clause)
    CoProc(clause) => function_body_has_reportable_command(clause.body)
    Function(_) => false
  }
}

///|
fn script_has_reportable_command(script : @parser.Script) -> Bool {
  for item in script.items {
    if and_or_list_has_reportable_command(item.and_or) {
      return true
    }
  }
  false
}

///|
fn and_or_list_has_reportable_command(list : @parser.AndOrList) -> Bool {
  if pipeline_has_reportable_command(list.head) {
    return true
  }
  for pair in list.tail {
    let (_, pipeline) = pair
    if pipeline_has_reportable_command(pipeline) {
      return true
    }
  }
  false
}

///|
fn pipeline_has_reportable_command(pipeline : @parser.Pipeline) -> Bool {
  for segment in pipeline.segments {
    if function_body_has_reportable_command(segment.command) {
      return true
    }
  }
  false
}

///|
fn if_clause_has_reportable_command(clause : @parser.IfClause) -> Bool {
  for arm in clause.arms {
    if script_has_reportable_command(arm.condition) ||
      script_has_reportable_command(arm.body) {
      return true
    }
  }
  if clause.else_body is Some(body) {
    script_has_reportable_command(body)
  } else {
    false
  }
}

///|
fn case_clause_has_reportable_command(clause : @parser.CaseClause) -> Bool {
  for item in clause.items {
    if script_has_reportable_command(item.body) {
      return true
    }
  }
  false
}

///|
fn has_unreachable_command_ancestor(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
) -> Bool {
  let mut current = @cfg.ast_parent_of(cfg, id)
  while current is Some(_) {
    if current is Some(parent) {
      match @cfg.ast_ref_of(cfg, parent) {
        Some(Command(_)) =>
          if !@cfg.command_is_reachable(analysis, parent) {
            return true
          } else {
            current = @cfg.ast_parent_of(cfg, parent)
          }
        _ => current = @cfg.ast_parent_of(cfg, parent)
      }
    }
  }
  false
}

///|
fn has_unreachable_function_ancestor(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
) -> Bool {
  let mut current = @cfg.ast_parent_of(cfg, id)
  while current is Some(_) {
    let parent = if current is Some(parent) { parent } else { break }
    match @cfg.ast_ref_of(cfg, parent) {
      Some(FunctionDef(_)) =>
        if !function_def_is_reachable(cfg, analysis, parent) {
          return true
        }
      _ => ()
    }
    current = @cfg.ast_parent_of(cfg, parent)
  }
  false
}

///|
fn function_def_is_reachable(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
) -> Bool {
  if function_def_body_command_id(cfg, id) is Some(body_id) {
    @cfg.command_is_reachable(analysis, body_id)
  } else {
    false
  }
}

///|
fn has_reachable_terminal_script_command(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
) -> Bool {
  for id in @cfg.ast_ids(cfg) {
    guard @cfg.command_is_reachable(analysis, id) else { continue }
    guard command_is_top_level_script_command(cfg, id) else { continue }
    match @cfg.ast_ref_of(cfg, id) {
      Some(Command(command)) =>
        if command_is_terminal_for_unreachable_function(command) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn command_is_top_level_script_command(
  cfg : @cfg.CFG,
  id : @cfg.CfgAstId,
) -> Bool {
  let mut current = @cfg.ast_parent_of(cfg, id)
  while current is Some(_) {
    let parent = if current is Some(parent) { parent } else { break }
    match @cfg.ast_ref_of(cfg, parent) {
      Some(FunctionDef(_)) | Some(BatsTestClause(_)) | Some(SourceCommand(_)) =>
        return false
      _ => current = @cfg.ast_parent_of(cfg, parent)
    }
  }
  true
}

///|
fn command_is_terminal_for_unreachable_function(
  command : @parser.Command,
) -> Bool {
  command_matches_exact_name(command, "exit")
}

///|
fn function_def_body_command_id(
  cfg : @cfg.CFG,
  id : @cfg.CfgAstId,
) -> @cfg.CfgAstId? {
  for child in @cfg.ast_children_of(cfg, id) {
    match @cfg.ast_ref_of(cfg, child) {
      Some(Command(_)) => return Some(child)
      _ => ()
    }
  }
  None
}

///|
fn has_source_command_ancestor(cfg : @cfg.CFG, id : @cfg.CfgAstId) -> Bool {
  let mut current = @cfg.ast_parent_of(cfg, id)
  while current is Some(_) {
    let parent = if current is Some(parent) { parent } else { break }
    match @cfg.ast_ref_of(cfg, parent) {
      Some(SourceCommand(_)) => return true
      Some(Command(command)) =>
        match command.kind {
          Source(_) => return true
          _ => ()
        }
      _ => ()
    }
    current = @cfg.ast_parent_of(cfg, parent)
  }
  false
}

///|
fn command_is_reportable(command : @parser.Command) -> Bool {
  match command.kind {
    Simple(_) | Source(_) | Condition(_) | Arithmetic(_) | Time(_) => true
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
            Warning,
            2179,
            "Use array+=(\"item\") to append items to an array.",
          )
        } else {
          push_diagnostic(
            diagnostics,
            assignment_name_span(assignment),
            Warning,
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
    ArrayLiteral(_) => true
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
  dead_subshell_reads : Array[@cfg.CfgAstId],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard !has_parameter_expansion_ancestor(cfg, id) else { return }
  guard !parameter_expansion_allows_unset(expansion) else { return }
  if expansion.name is Some(name) {
    check_unassigned_read(
      cfg, analysis, id, name, uppercase_only, dead_subshell_reads, diagnostics,
    )
  }
}

///|
fn check_unassigned_read(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  name : String,
  uppercase_only : Bool,
  dead_subshell_reads : Array[@cfg.CfgAstId],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard !has_parameter_expansion_ancestor(cfg, id) else { return }
  guard should_consider_variable_name(name, uppercase_only) else { return }
  guard !read_is_guarded(cfg, id, name) else { return }
  guard !batch_v_has_ast_id(dead_subshell_reads, id) else { return }
  match @cfg.incoming_state_of_ast(analysis, id) {
    Some(state) if state.state_is_reachable =>
      if variable_is_unassigned(state, name) {
        push_diagnostic(
          diagnostics,
          control_flow_unassigned_read_span(cfg, id),
          Warning,
          2154,
          "\{name} is referenced but not assigned.",
        )
      }
    _ => ()
  }
}

///|
fn has_parameter_expansion_ancestor(cfg : @cfg.CFG, id : @cfg.CfgAstId) -> Bool {
  let mut current = @cfg.ast_parent_of(cfg, id)
  while current is Some(_) {
    let parent = if current is Some(parent) { parent } else { break }
    match @cfg.ast_ref_of(cfg, parent) {
      Some(ParameterExpansion(_)) => return true
      _ => current = @cfg.ast_parent_of(cfg, parent)
    }
  }
  false
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
    if current is Some(parent) {
      match @cfg.ast_ref_of(cfg, parent) {
        Some(ParameterExpansion(expansion)) =>
          if expansion.name == Some(name) {
            match expansion.operator {
              Some(AlternateValue(_)) => return true
              _ => ()
            }
          }
        _ => ()
      }
    }
    current = if current is Some(parent) {
      @cfg.ast_parent_of(cfg, parent)
    } else {
      None
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
    let parent = if current is Some(parent) { parent } else { break }
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
    Some(IfArm(arm)) =>
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
  let parent = if @cfg.ast_parent_of(cfg, candidate) is Some(parent) {
    parent
  } else {
    return false
  }
  match (@cfg.ast_ref_of(cfg, candidate), @cfg.ast_ref_of(cfg, parent)) {
    (Some(LoopClause(clause)), Some(Command(command))) =>
      match command.kind {
        While(_) =>
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
  if last_script_list_item(script) is Some(item) {
    and_or_list_success_proves_defined(item.and_or, name)
  } else {
    false
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
      AndIf => proved || next
      OrIf => proved && next
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
    Condition(condition) =>
      condition_expr_success_proves_defined(condition.expr, name)
    Subshell(script) | BraceGroup(script) | BatsTest({ body: script, .. }) =>
      script_success_proves_defined(script, name)
    Time(clause) => pipeline_success_proves_defined(clause.body, name)
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
  dead_subshell_reads : Array[@cfg.CfgAstId],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut i = 0
  while i < expr.tokens.length() {
    match expr.tokens[i] {
      Variable(name, _) =>
        if arithmetic_token_needs_read(expr.tokens, i) {
          check_unassigned_read(
            cfg, analysis, id, name, uppercase_only, dead_subshell_reads, diagnostics,
          )
        }
      Group(inner) =>
        check_arithmetic_expr_reads(
          cfg, analysis, id, inner, uppercase_only, dead_subshell_reads, diagnostics,
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
    Variable(_, _) =>
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
      Operator(op) => return Some(op)
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
    Unary(op, _, word) =>
      (op == "-v" || op == "-R") &&
      condition_test_target_name(word) == Some(name)
    Group(inner) => condition_expr_success_proves_defined(inner, name)
    And(_, lhs, rhs) =>
      condition_expr_success_proves_defined(lhs, name) ||
      condition_expr_success_proves_defined(rhs, name)
    Or(_, lhs, rhs) =>
      condition_expr_success_proves_defined(lhs, name) &&
      condition_expr_success_proves_defined(rhs, name)
    _ => false
  }
}

///|
fn condition_test_target_name(word : @parser.Word) -> String? {
  let text = if @semantics.literal_text(word) is Some(text) {
    text
  } else if @semantics.leading_unquoted_text(word) is Some(text) {
    text
  } else {
    return None
  }
  let view = text[:]
  let mut end = 0
  while end < view.length() &&
        is_identifier_continue(view[end].unsafe_to_char()) {
    end += 1
  }
  let name = text.view(end_offset=end).to_owned()
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
  if @cfg.ast_enclosing_span_of(cfg, id) is Some(span) {
    span
  } else {
    panic()
  }
}

///|
fn control_flow_precise_ast_span(
  cfg : @cfg.CFG,
  id : @cfg.CfgAstId,
) -> @parser.Span {
  if @cfg.ast_span_of(cfg, id) is Some(span) {
    span
  } else {
    ast_effect_span(cfg, id)
  }
}

///|
fn control_flow_unassigned_read_span(
  cfg : @cfg.CFG,
  id : @cfg.CfgAstId,
) -> @parser.Span {
  match @cfg.ast_ref_of(cfg, id) {
    Some(ParameterExpansion(expansion)) =>
      if parent_word_of(cfg, id) is Some(word) {
        if word_subspan(word, "${\{expansion.raw}}") is Some(span) {
          span
        } else {
          control_flow_precise_ast_span(cfg, id)
        }
      } else {
        control_flow_precise_ast_span(cfg, id)
      }
    _ => control_flow_precise_ast_span(cfg, id)
  }
}

///|
fn span_contains(outer : @parser.Span, inner : @parser.Span) -> Bool {
  outer.start.offset <= inner.start.offset &&
  inner.end.offset <= outer.end.offset
}

///|
fn variable_is_unassigned(state : @cfg.ProgramState, name : String) -> Bool {
  if state.variables_in_scope.get(name) is Some(_) {
    @cfg.variable_may_be_unset(state, name)
  } else {
    true
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
