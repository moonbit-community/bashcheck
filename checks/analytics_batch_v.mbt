///|
fn append_analytics_batch_v_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_v_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_v_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2030,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Assignments in subshells do not affect the parent shell later.",
    },
    {
      code: 2031,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Later reads may miss assignments that only happened in a subshell.",
    },
  ]
}

///|
fn run_analytics_batch_v_checks(
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
  check_subshell_assignments_v(
    cfg,
    @semantics.has_lastpipe(script, shell),
    diagnostics,
  )
}

///|
priv enum BatchVEffectKind {
  Read
  Write
} derive(Eq)

///|
priv struct BatchVEffect {
  name : String
  span : @parser.Span
  kind : BatchVEffectKind
}

///|
priv struct BatchVDeadVar {
  span : @parser.Span
  reason : String
}

///|
priv struct BatchVWrite {
  name : String
  span : @parser.Span
}

///|
priv struct BatchVScope {
  reason : String
  writes : Array[BatchVWrite]
}

///|
fn check_subshell_assignments_v(
  cfg : @cfg.CFG,
  lastpipe : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let dead_read_ids : Array[@cfg.CfgAstId] = []
  run_batch_v_analysis(cfg, lastpipe, dead_read_ids, diagnostics)
}

///|
fn batch_v_dead_read_ids(
  cfg : @cfg.CFG,
  lastpipe : Bool,
) -> Array[@cfg.CfgAstId] {
  let dead_read_ids : Array[@cfg.CfgAstId] = []
  let diagnostics : Array[CheckDiagnostic] = []
  run_batch_v_analysis(cfg, lastpipe, dead_read_ids, diagnostics)
  dead_read_ids
}

///|
fn batch_v_has_ast_id(
  ids : Array[@cfg.CfgAstId],
  target : @cfg.CfgAstId,
) -> Bool {
  ids.any(fn(id) { id == target })
}

///|
fn run_batch_v_analysis(
  cfg : @cfg.CFG,
  lastpipe : Bool,
  dead_read_ids : Array[@cfg.CfgAstId],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let effects = collect_batch_v_effects(cfg)
  let scopes : Array[BatchVScope] = []
  let dead_vars : Map[String, BatchVDeadVar] = Map::new()
  let reported_origins : Array[@parser.Span] = []
  walk_batch_v_ast(
    cfg,
    @cfg.root_ast_id(cfg),
    lastpipe,
    effects,
    scopes,
    dead_vars,
    dead_read_ids,
    reported_origins,
    diagnostics,
  )
}

///|
fn collect_batch_v_effects(
  cfg : @cfg.CFG,
) -> Map[@cfg.CfgAstId, Array[BatchVEffect]] {
  let effects : Map[@cfg.CfgAstId, Array[BatchVEffect]] = Map::new()
  for node_id in @cfg.id_to_nodes(cfg, @cfg.root_ast_id(cfg)) {
    match @cfg.node_of(cfg, node_id) {
      Some({ kind: @cfg.CfgNodeKind::ApplyEffects(tagged_effects), .. }) =>
        for tagged in tagged_effects {
          match batch_v_effect_from_tagged(cfg, tagged) {
            Some(effect) => batch_v_push_effect(effects, tagged.ast_id, effect)
            None => ()
          }
        }
      _ => ()
    }
  }
  effects
}

///|
fn batch_v_effect_from_tagged(
  cfg : @cfg.CFG,
  tagged : @cfg.CfgTaggedEffect,
) -> BatchVEffect? {
  match tagged.effect {
    @cfg.CfgEffect::ReadVariable(name) =>
      Some({
        name,
        span: batch_v_read_effect_span(cfg, tagged.ast_id, name),
        kind: BatchVEffectKind::Read,
      })
    @cfg.CfgEffect::WriteVariable(name, _)
    | @cfg.CfgEffect::WriteGlobal(name, _)
    | @cfg.CfgEffect::WriteLocal(name, _) =>
      Some({
        name,
        span: batch_v_effect_span(cfg, tagged.ast_id, name),
        kind: BatchVEffectKind::Write,
      })
    @cfg.CfgEffect::WritePrefix(_, _)
    | @cfg.CfgEffect::SetProps(_, _, _)
    | @cfg.CfgEffect::UnsetProps(_, _, _)
    | @cfg.CfgEffect::DefineFunction(_, _, _, _)
    | @cfg.CfgEffect::Undefine(_)
    | @cfg.CfgEffect::UndefineVariable(_)
    | @cfg.CfgEffect::UndefineFunction(_)
    | @cfg.CfgEffect::UndefineNameref(_)
    | @cfg.CfgEffect::HintArray(_)
    | @cfg.CfgEffect::HintDefined(_) => None
  }
}

///|
fn batch_v_read_effect_span(
  cfg : @cfg.CFG,
  ast_id : @cfg.CfgAstId,
  name : String,
) -> @parser.Span {
  match @cfg.ast_ref_of(cfg, ast_id) {
    Some(@semantics.NodeRef::WordPart(@parser.WordPart::Parameter(_)))
    | Some(@semantics.NodeRef::WordPart(@parser.WordPart::SpecialParameter(_))) =>
      match batch_v_parent_word(cfg, ast_id) {
        Some(word) =>
          match batch_t_string_offset(word.source, "$" + name) {
            Some(offset) =>
              batch_t_span_offset(word.span, offset, name[:].length() + 1)
            None => batch_v_ast_span(cfg, ast_id)
          }
        None => batch_v_ast_span(cfg, ast_id)
      }
    Some(@semantics.NodeRef::ParameterExpansion(_)) =>
      match batch_v_parent_word(cfg, ast_id) {
        Some(word) =>
          match batch_v_find_braced_parameter_span(word, name) {
            Some(span) => span
            None => batch_v_ast_span(cfg, ast_id)
          }
        None => batch_v_ast_span(cfg, ast_id)
      }
    _ => batch_v_effect_span(cfg, ast_id, name)
  }
}

///|
fn batch_v_effect_span(
  cfg : @cfg.CFG,
  ast_id : @cfg.CfgAstId,
  name : String,
) -> @parser.Span {
  match @cfg.ast_ref_of(cfg, ast_id) {
    Some(@semantics.NodeRef::Assignment(assignment)) =>
      assignment_name_span(assignment)
    Some(@semantics.NodeRef::SimpleCommand(_))
    | Some(@semantics.NodeRef::SourceCommand(_)) =>
      match batch_v_parent_command(cfg, ast_id) {
        Some(command) => batch_v_command_write_span(command, name)
        None => batch_v_ast_span(cfg, ast_id)
      }
    Some(@semantics.NodeRef::ArithmeticExpr(_)) =>
      batch_v_arithmetic_write_span(cfg, ast_id, name)
    Some(@semantics.NodeRef::CoProcClause(clause)) =>
      batch_v_coproc_name_span(cfg, ast_id, clause, name)
    _ => batch_v_ast_span(cfg, ast_id)
  }
}

///|
fn batch_v_parent_word(cfg : @cfg.CFG, ast_id : @cfg.CfgAstId) -> @parser.Word? {
  let mut current = @cfg.ast_parent_of(cfg, ast_id)
  while current is Some(_) {
    let parent = match current {
      Some(parent) => parent
      None => break
    }
    match @cfg.ast_ref_of(cfg, parent) {
      Some(@semantics.NodeRef::Word(word)) => return Some(word)
      _ => current = @cfg.ast_parent_of(cfg, parent)
    }
  }
  None
}

///|
fn batch_v_find_braced_parameter_span(
  word : @parser.Word,
  name : String,
) -> @parser.Span? {
  let start = match batch_t_string_offset(word.source, "${" + name) {
    Some(start) => start
    None => return None
  }
  let view = word.source[:]
  let mut depth = 0
  let mut i = start + name[:].length() + 2
  while i < view.length() {
    match view[i].unsafe_to_char() {
      '{' => depth += 1
      '}' =>
        if depth == 0 {
          return Some(batch_t_span_offset(word.span, start, i - start + 1))
        } else {
          depth -= 1
        }
      _ => ()
    }
    i += 1
  }
  None
}

///|
fn batch_v_parent_command(
  cfg : @cfg.CFG,
  ast_id : @cfg.CfgAstId,
) -> @parser.Command? {
  match @cfg.ast_parent_of(cfg, ast_id) {
    Some(parent) =>
      match @cfg.ast_ref_of(cfg, parent) {
        Some(@semantics.NodeRef::Command(command)) => Some(command)
        _ => None
      }
    None => None
  }
}

///|
fn batch_v_command_write_span(
  command : @parser.Command,
  name : String,
) -> @parser.Span {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      for assignment in simple.assignments {
        if assignment.name == name {
          return assignment_name_span(assignment)
        }
      }
    @parser.CommandKind::Source(source) =>
      for assignment in source.assignments {
        if assignment.name == name {
          return assignment_name_span(assignment)
        }
      }
    _ => ()
  }
  for word in @semantics.effective_command_arguments(command) {
    match @semantics.literal_text(word) {
      Some(text) if text == name => return word.span
      Some(text) if batch_v_is_assignment_like_operand(text, name) =>
        return span_prefix(word.span, name[:].length())
      _ => ()
    }
  }
  effective_command_span(command)
}

///|
fn batch_v_is_assignment_like_operand(text : String, name : String) -> Bool {
  text.has_prefix(name + "=") ||
  text.has_prefix(name + "+=") ||
  text.has_prefix(name + "[")
}

///|
fn batch_v_arithmetic_write_span(
  cfg : @cfg.CFG,
  ast_id : @cfg.CfgAstId,
  name : String,
) -> @parser.Span {
  for child in @cfg.ast_children_of(cfg, ast_id) {
    match @cfg.ast_ref_of(cfg, child) {
      Some(@semantics.NodeRef::ArithmeticToken(token)) =>
        match token {
          @parser.ArithmeticToken::Variable(current, _) =>
            if current == name {
              return batch_v_ast_span(cfg, child)
            }
          _ => ()
        }
      _ => ()
    }
  }
  batch_v_ast_span(cfg, ast_id)
}

///|
fn batch_v_coproc_name_span(
  cfg : @cfg.CFG,
  ast_id : @cfg.CfgAstId,
  clause : @parser.CoProcClause,
  name : String,
) -> @parser.Span {
  match clause.name {
    Some(word) if @semantics.literal_text(word) == Some(name) => word.span
    _ => batch_v_ast_span(cfg, ast_id)
  }
}

///|
fn batch_v_ast_span(cfg : @cfg.CFG, ast_id : @cfg.CfgAstId) -> @parser.Span {
  match @cfg.ast_span_of(cfg, ast_id) {
    Some(span) => span
    None =>
      match @cfg.ast_enclosing_span_of(cfg, ast_id) {
        Some(span) => span
        None => abort("expected AST span")
      }
  }
}

///|
fn batch_v_push_effect(
  effects : Map[@cfg.CfgAstId, Array[BatchVEffect]],
  ast_id : @cfg.CfgAstId,
  effect : BatchVEffect,
) -> Unit {
  match effects.get(ast_id) {
    Some(existing) => {
      let updated : Array[BatchVEffect] = []
      for current in existing {
        updated.push(current)
      }
      updated.push(effect)
      effects.set(ast_id, updated)
    }
    None => effects.set(ast_id, [effect])
  }
}

///|
fn walk_batch_v_ast(
  cfg : @cfg.CFG,
  ast_id : @cfg.CfgAstId,
  lastpipe : Bool,
  effects : Map[@cfg.CfgAstId, Array[BatchVEffect]],
  scopes : Array[BatchVScope],
  dead_vars : Map[String, BatchVDeadVar],
  dead_read_ids : Array[@cfg.CfgAstId],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match @cfg.ast_ref_of(cfg, ast_id) {
    Some(@semantics.NodeRef::FunctionDef(_)) => {
      let isolated_scopes : Array[BatchVScope] = []
      let isolated_dead_vars : Map[String, BatchVDeadVar] = Map::new()
      let isolated_reported : Array[@parser.Span] = []
      for child in @cfg.ast_children_of(cfg, ast_id) {
        walk_batch_v_ast(
          cfg, child, lastpipe, effects, isolated_scopes, isolated_dead_vars, dead_read_ids,
          isolated_reported, diagnostics,
        )
      }
      return
    }
    _ => ()
  }

  let assign_first = batch_v_assigns_before_children(cfg, ast_id)
  let mut pushed_scope = false
  match batch_v_scope_reason(cfg, ast_id, lastpipe) {
    Some(reason) => {
      scopes.push({ reason, writes: [] })
      pushed_scope = true
    }
    None => ()
  }

  if assign_first {
    batch_v_process_ast_writes(effects, ast_id, scopes, dead_vars)
  }

  for child in @cfg.ast_children_of(cfg, ast_id) {
    walk_batch_v_ast(
      cfg, child, lastpipe, effects, scopes, dead_vars, dead_read_ids, reported_origins,
      diagnostics,
    )
  }

  batch_v_process_ast_reads(
    effects, ast_id, dead_vars, dead_read_ids, reported_origins, diagnostics,
  )
  if !assign_first {
    batch_v_process_ast_writes(effects, ast_id, scopes, dead_vars)
  }

  if pushed_scope {
    batch_v_close_scope(scopes, dead_vars)
  }
}

///|
fn batch_v_assigns_before_children(
  cfg : @cfg.CFG,
  ast_id : @cfg.CfgAstId,
) -> Bool {
  match @cfg.ast_ref_of(cfg, ast_id) {
    Some(@semantics.NodeRef::ForClause(_))
    | Some(@semantics.NodeRef::SelectClause(_))
    | Some(@semantics.NodeRef::BatsTestClause(_)) => true
    _ => false
  }
}

///|
fn batch_v_scope_reason(
  cfg : @cfg.CFG,
  ast_id : @cfg.CfgAstId,
  lastpipe : Bool,
) -> String? {
  match @cfg.ast_ref_of(cfg, ast_id) {
    Some(@semantics.NodeRef::ListItem(item)) =>
      match item.terminator {
        Some(@parser.Terminator::Background) => Some("backgrounding &")
        _ => None
      }
    Some(@semantics.NodeRef::Command(command)) =>
      match command.kind {
        @parser.CommandKind::Subshell(_) => Some("(..) group")
        @parser.CommandKind::BatsTest(_) => Some("@bats test")
        _ =>
          if batch_v_command_is_coproc_body(cfg, ast_id) {
            Some("coproc")
          } else if batch_v_command_is_pipeline_subshell(cfg, ast_id, lastpipe) {
            Some("pipeline")
          } else {
            None
          }
      }
    Some(@semantics.NodeRef::WordPart(part)) =>
      match part {
        @parser.WordPart::CommandSubstitution(_)
        | @parser.WordPart::BraceCommandSubstitution(_, _) =>
          Some("$(..) expansion")
        @parser.WordPart::BackQuoted(_) => Some("`..` expansion")
        _ => None
      }
    _ => None
  }
}

///|
fn batch_v_command_is_coproc_body(
  cfg : @cfg.CFG,
  ast_id : @cfg.CfgAstId,
) -> Bool {
  match @cfg.ast_parent_of(cfg, ast_id) {
    Some(parent) =>
      match @cfg.ast_ref_of(cfg, parent) {
        Some(@semantics.NodeRef::CoProcClause(_)) => true
        _ => false
      }
    None => false
  }
}

///|
fn batch_v_command_is_pipeline_subshell(
  cfg : @cfg.CFG,
  ast_id : @cfg.CfgAstId,
  lastpipe : Bool,
) -> Bool {
  let segment_id = match @cfg.ast_parent_of(cfg, ast_id) {
    Some(parent) =>
      match @cfg.ast_ref_of(cfg, parent) {
        Some(@semantics.NodeRef::PipelineSegment(_)) => parent
        _ => return false
      }
    None => return false
  }
  let pipeline_id = match @cfg.ast_parent_of(cfg, segment_id) {
    Some(parent) =>
      match @cfg.ast_ref_of(cfg, parent) {
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
  if !lastpipe {
    return true
  }
  let segment_ids = batch_v_pipeline_segment_ids(cfg, pipeline_id)
  match segment_ids.get(segment_ids.length() - 1) {
    Some(last_segment) => last_segment != segment_id
    None => false
  }
}

///|
fn batch_v_pipeline_segment_ids(
  cfg : @cfg.CFG,
  pipeline_id : @cfg.CfgAstId,
) -> Array[@cfg.CfgAstId] {
  let ids : Array[@cfg.CfgAstId] = []
  for child in @cfg.ast_children_of(cfg, pipeline_id) {
    match @cfg.ast_ref_of(cfg, child) {
      Some(@semantics.NodeRef::PipelineSegment(_)) => ids.push(child)
      _ => ()
    }
  }
  ids
}

///|
fn batch_v_process_ast_reads(
  effects : Map[@cfg.CfgAstId, Array[BatchVEffect]],
  ast_id : @cfg.CfgAstId,
  dead_vars : Map[String, BatchVDeadVar],
  dead_read_ids : Array[@cfg.CfgAstId],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match effects.get(ast_id) {
    Some(current) =>
      for effect in current {
        guard effect.kind == BatchVEffectKind::Read else { continue }
        guard !batch_v_ignores_name(effect.name) else { continue }
        match dead_vars.get(effect.name) {
          Some(dead) => {
            if !batch_v_has_ast_id(dead_read_ids, ast_id) {
              dead_read_ids.push(ast_id)
            }
            if !batch_v_has_span(reported_origins, dead.span) {
              reported_origins.push(dead.span)
              push_diagnostic(
                diagnostics,
                dead.span,
                CheckSeverity::Info,
                2030,
                "Modification of \{effect.name} is local (to subshell caused by \{dead.reason}).",
              )
            }
            push_diagnostic(
              diagnostics,
              effect.span,
              CheckSeverity::Info,
              2031,
              "\{effect.name} was modified in a subshell. That change might be lost.",
            )
          }
          None => ()
        }
      }
    None => ()
  }
}

///|
fn batch_v_process_ast_writes(
  effects : Map[@cfg.CfgAstId, Array[BatchVEffect]],
  ast_id : @cfg.CfgAstId,
  scopes : Array[BatchVScope],
  dead_vars : Map[String, BatchVDeadVar],
) -> Unit {
  match effects.get(ast_id) {
    Some(current) =>
      for effect in current {
        guard effect.kind == BatchVEffectKind::Write else { continue }
        dead_vars.remove(effect.name)
        if scopes.length() > 0 {
          match scopes.pop() {
            Some(scope) => {
              scope.writes.push({ name: effect.name, span: effect.span })
              scopes.push(scope)
            }
            None => ()
          }
        }
      }
    None => ()
  }
}

///|
fn batch_v_close_scope(
  scopes : Array[BatchVScope],
  dead_vars : Map[String, BatchVDeadVar],
) -> Unit {
  guard scopes.length() > 0 else { return }
  match scopes.pop() {
    Some(scope) =>
      for write in scope.writes {
        dead_vars.set(write.name, { span: write.span, reason: scope.reason })
      }
    None => ()
  }
}

///|
fn batch_v_ignores_name(name : String) -> Bool {
  name == "@" || name == "*" || name == "IFS"
}

///|
fn batch_v_has_span(spans : Array[@parser.Span], target : @parser.Span) -> Bool {
  spans.any(fn(span) { span == target })
}
