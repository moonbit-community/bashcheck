///|
priv struct Range {
  start : CfgNodeId
  end_ : CfgNodeId
}

///|
priv enum AstTag {
  Script
  Annotation
  ListItem
  AndOrList
  Pipeline
  PipelineSegment
  Command
  SimpleCommand
  SourceCommand
  ArithmeticExpr
  ArithmeticToken
  ArrayIndex
  TimeClause
  Assignment
  ArrayElement
  IfClause
  IfArm
  LoopClause
  ForClause
  ArithmeticForClause
  SelectClause
  CaseClause
  CaseItem
  ConditionCommand
  ConditionExpr
  ArithmeticCommand
  CoProcClause
  BatsTestClause
  FunctionDef
  Redirection
  HereDoc
  ExtGlobPattern
  BraceExpansion
  Word
  WordPart
  ParameterExpansion
} derive(Eq, Debug)

///|
priv struct AstEntry {
  id : CfgAstId
  kind : AstTag
  node_ref : @semantics.NodeRef
  span : @parser.Span?
  enclosing_span : @parser.Span
  parent : CfgAstId?
  children : Array[CfgAstId]
} derive(Eq, Debug)

///|
/// A lowered control-flow graph together with AST-to-node mappings.
pub struct CFG {
  priv root : CfgAstId
  priv ast_entries : Array[AstEntry]
  priv ast_ranges : Array[(CfgNodeId, CfgNodeId)?]
  priv ast_nodes : Array[Array[CfgNodeId]]
  priv nodes : Array[CfgNode]
  priv graph_edges : Array[CfgEdge]
  priv post_dominators : Array[Array[CfgNodeId]]
  priv main_exit : CfgNodeId
} derive(Eq, Debug)

///|
fn cfg_ast_id(value : Int) -> CfgAstId {
  { value, }
}

///|
fn cfg_node_id(value : Int) -> CfgNodeId {
  { value, }
}

///|
fn node_range(node : CfgNodeId) -> Range {
  { start: node, end_: node }
}

///|
fn ast_entry_at(cfg : CFG, id : CfgAstId) -> AstEntry? {
  cfg.ast_entries.get(id.to_int())
}

///|
fn node_at(cfg : CFG, id : CfgNodeId) -> CfgNode? {
  cfg.nodes.get(id.to_int())
}

///|
/// Returns the CFG id of the root script AST node.
pub fn root_ast_id(cfg : CFG) -> CfgAstId {
  cfg.root
}

///|
/// Returns the indexed AST reference associated with a CFG AST id.
pub fn ast_ref_of(cfg : CFG, id : CfgAstId) -> @semantics.NodeRef? {
  match ast_entry_at(cfg, id) {
    Some(entry) => Some(entry.node_ref)
    None => None
  }
}

///|
/// Returns the exact span of a CFG AST node when one exists.
pub fn ast_span_of(cfg : CFG, id : CfgAstId) -> @parser.Span? {
  match ast_entry_at(cfg, id) {
    Some(entry) => entry.span
    None => None
  }
}

///|
/// Returns the enclosing span of a CFG AST node.
pub fn ast_enclosing_span_of(cfg : CFG, id : CfgAstId) -> @parser.Span? {
  match ast_entry_at(cfg, id) {
    Some(entry) => Some(entry.enclosing_span)
    None => None
  }
}

///|
/// Returns the parent AST id of a CFG AST node.
pub fn ast_parent_of(cfg : CFG, id : CfgAstId) -> CfgAstId? {
  match ast_entry_at(cfg, id) {
    Some(entry) => entry.parent
    None => None
  }
}

///|
/// Returns the child AST ids of a CFG AST node.
pub fn ast_children_of(cfg : CFG, id : CfgAstId) -> Array[CfgAstId] {
  match ast_entry_at(cfg, id) {
    Some(entry) => copy_ast_ids(entry.children)
    None => []
  }
}

///|
/// Returns every AST id known to the CFG.
pub fn ast_ids(cfg : CFG) -> Array[CfgAstId] {
  let ids : Array[CfgAstId] = []
  let mut i = 0
  while i < cfg.ast_entries.length() {
    ids.push(cfg_ast_id(i))
    i += 1
  }
  ids
}

///|
/// Returns the semantic node kind associated with a CFG AST id.
pub fn node_kind_of(cfg : CFG, id : CfgAstId) -> @semantics.NodeKind? {
  match ast_entry_at(cfg, id) {
    Some(entry) => Some(entry.node_ref.kind())
    None => None
  }
}

///|
/// Returns the CFG node stored at a node id.
pub fn node_of(cfg : CFG, id : CfgNodeId) -> CfgNode? {
  node_at(cfg, id)
}

///|
/// Returns a copy of all directed CFG edges.
pub fn edges(cfg : CFG) -> Array[CfgEdge] {
  copy_cfg_edges(cfg.graph_edges)
}

///|
/// Returns the node-id range associated with one AST id.
pub fn id_to_range(cfg : CFG, id : CfgAstId) -> (CfgNodeId, CfgNodeId)? {
  match cfg.ast_ranges.get(id.to_int()) {
    Some(value) => value
    None => None
  }
}

///|
/// Returns all CFG nodes associated with one AST id.
pub fn id_to_nodes(cfg : CFG, id : CfgAstId) -> Array[CfgNodeId] {
  match cfg.ast_nodes.get(id.to_int()) {
    Some(nodes) => copy_node_ids(nodes)
    None => []
  }
}

///|
/// Returns the precomputed post-dominator sets for every CFG node.
pub fn compute_post_dominators(cfg : CFG) -> Array[Array[CfgNodeId]] {
  copy_post_dominators(cfg.post_dominators)
}

///|
/// Reports whether one AST node post-dominates another in the CFG.
pub fn post_dominates(cfg : CFG, target : CfgAstId, base : CfgAstId) -> Bool {
  let target_range = match id_to_range(cfg, target) {
    Some(range) => range
    None => return false
  }
  let base_range = match id_to_range(cfg, base) {
    Some(range) => range
    None => return false
  }
  contains_node_id(cfg.post_dominators[base_range.1.to_int()], target_range.0)
}

///|
/// Lowers a parsed script into a control-flow graph.
pub fn build_cfg(script : @parser.Script, params : CfgParameters) -> CFG {
  let collector = AstCollector::new()
  let root = collector.copy_script(script, None)
  let builder = GraphBuilder::new(root, collector.entries, params)
  builder.build()
}

///|
fn ast_tag_of(node_ref : @semantics.NodeRef) -> AstTag {
  match node_ref {
    @semantics.NodeRef::Script(_) => AstTag::Script
    @semantics.NodeRef::Annotation(_) => AstTag::Annotation
    @semantics.NodeRef::ListItem(_) => AstTag::ListItem
    @semantics.NodeRef::AndOrList(_) => AstTag::AndOrList
    @semantics.NodeRef::Pipeline(_) => AstTag::Pipeline
    @semantics.NodeRef::PipelineSegment(_) => AstTag::PipelineSegment
    @semantics.NodeRef::Command(_) => AstTag::Command
    @semantics.NodeRef::SimpleCommand(_) => AstTag::SimpleCommand
    @semantics.NodeRef::SourceCommand(_) => AstTag::SourceCommand
    @semantics.NodeRef::ArithmeticExpr(_) => AstTag::ArithmeticExpr
    @semantics.NodeRef::ArithmeticToken(_) => AstTag::ArithmeticToken
    @semantics.NodeRef::ArrayIndex(_) => AstTag::ArrayIndex
    @semantics.NodeRef::TimeClause(_) => AstTag::TimeClause
    @semantics.NodeRef::Assignment(_) => AstTag::Assignment
    @semantics.NodeRef::ArrayElement(_) => AstTag::ArrayElement
    @semantics.NodeRef::IfClause(_) => AstTag::IfClause
    @semantics.NodeRef::IfArm(_) => AstTag::IfArm
    @semantics.NodeRef::LoopClause(_) => AstTag::LoopClause
    @semantics.NodeRef::ForClause(_) => AstTag::ForClause
    @semantics.NodeRef::ArithmeticForClause(_) => AstTag::ArithmeticForClause
    @semantics.NodeRef::SelectClause(_) => AstTag::SelectClause
    @semantics.NodeRef::CaseClause(_) => AstTag::CaseClause
    @semantics.NodeRef::CaseItem(_) => AstTag::CaseItem
    @semantics.NodeRef::ConditionCommand(_) => AstTag::ConditionCommand
    @semantics.NodeRef::ConditionExpr(_) => AstTag::ConditionExpr
    @semantics.NodeRef::ArithmeticCommand(_) => AstTag::ArithmeticCommand
    @semantics.NodeRef::CoProcClause(_) => AstTag::CoProcClause
    @semantics.NodeRef::BatsTestClause(_) => AstTag::BatsTestClause
    @semantics.NodeRef::FunctionDef(_) => AstTag::FunctionDef
    @semantics.NodeRef::Redirection(_) => AstTag::Redirection
    @semantics.NodeRef::HereDoc(_) => AstTag::HereDoc
    @semantics.NodeRef::ExtGlobPattern(_) => AstTag::ExtGlobPattern
    @semantics.NodeRef::BraceExpansion(_) => AstTag::BraceExpansion
    @semantics.NodeRef::Word(_) => AstTag::Word
    @semantics.NodeRef::WordPart(_) => AstTag::WordPart
    @semantics.NodeRef::ParameterExpansion(_) => AstTag::ParameterExpansion
  }
}

///|
priv struct AstCollector {
  entries : Array[AstEntry]
}

///|
// CHECK THIS: THUNK
fn AstCollector::new() -> AstCollector {
  { entries: [] }
}

///|
fn AstCollector::append(
  self : AstCollector,
  node_ref : @semantics.NodeRef,
  span : @parser.Span?,
  enclosing_span : @parser.Span,
  parent : CfgAstId?,
) -> CfgAstId {
  let id = cfg_ast_id(self.entries.length())
  self.entries.push({
    id,
    kind: ast_tag_of(node_ref),
    node_ref,
    span,
    enclosing_span,
    parent,
    children: [],
  })
  match parent {
    Some(parent) =>
      match self.entries.get(parent.to_int()) {
        Some(entry) => {
          let updated = entry
          updated.children.push(id)
          self.entries[parent.to_int()] = updated
        }
        None => panic()
      }
    None => ()
  }
  id
}

///|
fn AstCollector::copy_script(
  self : AstCollector,
  script : @parser.Script,
  parent : CfgAstId?,
) -> CfgAstId {
  let indexed = @semantics.build_index(script)
  self.copy_from_indexed(indexed, @semantics.root_id(indexed), parent)
}

///|
fn AstCollector::copy_from_indexed(
  self : AstCollector,
  indexed : @semantics.IndexedScript,
  source_id : @semantics.NodeId,
  parent : CfgAstId?,
) -> CfgAstId {
  let node_ref = match @semantics.node_ref_of(indexed, source_id) {
    Some(node_ref) => node_ref
    None => panic()
  }
  let enclosing_span = match @semantics.enclosing_span_of(indexed, source_id) {
    Some(enclosing_span) => enclosing_span
    None => panic()
  }
  let id = self.append(
    node_ref,
    @semantics.span_of(indexed, source_id),
    enclosing_span,
    parent,
  )
  for child in @semantics.children_of(indexed, source_id) {
    let _ = self.copy_from_indexed(indexed, child, Some(id))
  }
  match node_ref {
    @semantics.NodeRef::SourceCommand(source) =>
      match source.included {
        Some(included) => {
          let _ = self.copy_script(included, Some(id))
        }
        None => ()
      }
    _ => ()
  }
  id
}

///|
priv struct GraphBuilder {
  root : CfgAstId
  ast_entries : Array[AstEntry]
  ast_ranges : Array[(CfgNodeId, CfgNodeId)?]
  ast_nodes : Array[Array[CfgNodeId]]
  nodes : Array[CfgNode]
  edges : Array[CfgEdge]
  ast_stack : Array[CfgAstId]
  mut loop_break_targets : Array[CfgNodeId]
  mut loop_continue_targets : Array[CfgNodeId]
  mut is_condition : Bool
  mut is_function : Bool
  mut exit_target : CfgNodeId?
  mut return_target : CfgNodeId?
  params : CfgParameters
}

///|
fn GraphBuilder::new(
  root : CfgAstId,
  ast_entries : Array[AstEntry],
  params : CfgParameters,
) -> GraphBuilder {
  {
    root,
    ast_entries,
    ast_ranges: init_ast_ranges(ast_entries.length()),
    ast_nodes: init_ast_nodes(ast_entries.length()),
    nodes: [],
    edges: [],
    ast_stack: [],
    loop_break_targets: [],
    loop_continue_targets: [],
    is_condition: false,
    is_function: false,
    exit_target: None,
    return_target: None,
    params,
  }
}

///|
fn GraphBuilder::build(self : GraphBuilder) -> CFG {
  self.ast_stack.push(self.root)
  let entry = self.new_node(CfgNodeKind::EntryPoint("MAIN"))
  let implied_exit = self.new_node(CfgNodeKind::ImpliedExit)
  let main_exit = self.new_node(CfgNodeKind::Structural)
  let old_exit = self.exit_target
  let old_return = self.return_target
  self.exit_target = Some(main_exit)
  self.return_target = Some(implied_exit)
  let body = self.build_ast_inner(self.root)
  self.exit_target = old_exit
  self.return_target = old_return
  let range = self.link_ranges([
    node_range(entry),
    body,
    node_range(implied_exit),
    node_range(main_exit),
  ])
  self.record_range(self.root, range)
  let _ = self.ast_stack.pop()
  let cfg = {
    root: self.root,
    ast_entries: copy_ast_entries(self.ast_entries),
    ast_ranges: copy_ast_ranges(self.ast_ranges),
    ast_nodes: copy_nested_node_ids(self.ast_nodes),
    nodes: copy_cfg_nodes(self.nodes),
    graph_edges: copy_cfg_edges(self.edges),
    post_dominators: [],
    main_exit,
  }
  let post_dominators = compute_post_dominators_inner(cfg)
  {
    root: cfg.root,
    ast_entries: cfg.ast_entries,
    ast_ranges: cfg.ast_ranges,
    ast_nodes: cfg.ast_nodes,
    nodes: cfg.nodes,
    graph_edges: cfg.graph_edges,
    post_dominators,
    main_exit: cfg.main_exit,
  }
}

///|
fn GraphBuilder::entry_at(self : GraphBuilder, id : CfgAstId) -> AstEntry {
  match self.ast_entries.get(id.to_int()) {
    Some(entry) => entry
    None => panic()
  }
}

///|
fn GraphBuilder::parent_command_of(
  self : GraphBuilder,
  id : CfgAstId,
) -> @parser.Command? {
  match self.entry_at(id).parent {
    Some(parent) =>
      match self.entry_at(parent).node_ref {
        @semantics.NodeRef::Command(command) => Some(command)
        _ => None
      }
    None => None
  }
}

///|
fn GraphBuilder::children_of(
  self : GraphBuilder,
  id : CfgAstId,
) -> Array[CfgAstId] {
  copy_ast_ids(self.entry_at(id).children)
}

///|
fn GraphBuilder::children_with_kind(
  self : GraphBuilder,
  id : CfgAstId,
  kind : AstTag,
) -> Array[CfgAstId] {
  let ids : Array[CfgAstId] = []
  for child in self.entry_at(id).children {
    match self.ast_entries.get(child.to_int()) {
      Some(entry) if entry.kind == kind => ids.push(child)
      _ => ()
    }
  }
  ids
}

///|
fn GraphBuilder::first_child_with_kind(
  self : GraphBuilder,
  id : CfgAstId,
  kind : AstTag,
) -> CfgAstId? {
  for child in self.entry_at(id).children {
    match self.ast_entries.get(child.to_int()) {
      Some(entry) if entry.kind == kind => return Some(child)
      _ => ()
    }
  }
  None
}

///|
fn GraphBuilder::new_node(self : GraphBuilder, kind : CfgNodeKind) -> CfgNodeId {
  let id = cfg_node_id(self.nodes.length())
  self.nodes.push({ id, kind })
  for ast_id in self.ast_stack {
    self.ast_nodes[ast_id.to_int()].push(id)
  }
  id
}

///|
fn GraphBuilder::new_node_range(
  self : GraphBuilder,
  kind : CfgNodeKind,
) -> Range {
  node_range(self.new_node(kind))
}

///|
fn GraphBuilder::none(self : GraphBuilder) -> Range {
  self.new_node_range(CfgNodeKind::Structural)
}

///|
fn GraphBuilder::record_range(
  self : GraphBuilder,
  id : CfgAstId,
  range : Range,
) -> Unit {
  self.ast_ranges[id.to_int()] = Some((range.start, range.end_))
}

///|
fn GraphBuilder::push_loop_targets(
  self : GraphBuilder,
  break_target : CfgNodeId,
  continue_target : CfgNodeId,
) -> Unit {
  self.loop_break_targets.push(break_target)
  self.loop_continue_targets.push(continue_target)
}

///|
fn GraphBuilder::pop_loop_targets(self : GraphBuilder) -> Unit {
  let _ = self.loop_break_targets.pop()
  let _ = self.loop_continue_targets.pop()
}

///|
fn GraphBuilder::loop_target(
  self : GraphBuilder,
  continue_ : Bool,
  args : Array[@parser.Word],
) -> CfgNodeId? {
  let depth = loop_control_depth(args)
  let targets = if continue_ {
    self.loop_continue_targets
  } else {
    self.loop_break_targets
  }
  if depth <= 0 || depth > targets.length() {
    None
  } else {
    Some(targets[targets.length() - depth])
  }
}

///|
fn GraphBuilder::link(
  self : GraphBuilder,
  from : CfgNodeId,
  to : CfgNodeId,
  kind : CfgEdgeKind,
) -> Unit {
  self.edges.push({ from, to, kind })
}

///|
fn GraphBuilder::link_range(
  self : GraphBuilder,
  lhs : Range,
  rhs : Range,
) -> Range {
  self.link(lhs.end_, rhs.start, CfgEdgeKind::Flow)
  { start: lhs.start, end_: rhs.end_ }
}

///|
fn GraphBuilder::link_range_as(
  self : GraphBuilder,
  kind : CfgEdgeKind,
  lhs : Range,
  rhs : Range,
) -> Range {
  self.link(lhs.end_, rhs.start, kind)
  { start: lhs.start, end_: rhs.end_ }
}

///|
fn GraphBuilder::span_range(
  self : GraphBuilder,
  lhs : Range,
  rhs : Range,
) -> Range {
  ignore(self)
  { start: lhs.start, end_: rhs.end_ }
}

///|
fn GraphBuilder::link_ranges(
  self : GraphBuilder,
  ranges : Array[Range],
) -> Range {
  guard ranges.length() > 0 else { panic() }
  let mut current = ranges[0]
  let mut i = 1
  while i < ranges.length() {
    current = self.link_range(current, ranges[i])
    i += 1
  }
  current
}

///|
fn GraphBuilder::sequence_ids(
  self : GraphBuilder,
  ids : Array[CfgAstId],
) -> Range {
  if ids.length() == 0 {
    return self.none()
  }
  let ranges : Array[Range] = []
  for id in ids {
    ranges.push(self.build_ast(id))
  }
  self.link_ranges(ranges)
}

///|
fn GraphBuilder::build_ast(self : GraphBuilder, id : CfgAstId) -> Range {
  self.ast_stack.push(id)
  let range = self.build_ast_inner(id)
  self.record_range(id, range)
  let _ = self.ast_stack.pop()
  range
}

///|
fn GraphBuilder::build_ast_inner(self : GraphBuilder, id : CfgAstId) -> Range {
  match self.entry_at(id).node_ref {
    @semantics.NodeRef::Script(_) => self.sequence_ids(self.children_of(id))
    @semantics.NodeRef::Annotation(_) => self.none()
    @semantics.NodeRef::ListItem(item) => self.build_list_item(id, item)
    @semantics.NodeRef::AndOrList(list) => self.build_and_or_list(id, list)
    @semantics.NodeRef::Pipeline(pipeline) => self.build_pipeline(id, pipeline)
    @semantics.NodeRef::PipelineSegment(segment) =>
      self.build_pipeline_segment(id, segment)
    @semantics.NodeRef::Command(command) => self.build_command(id, command)
    @semantics.NodeRef::SimpleCommand(simple) =>
      self.build_simple_command(id, simple)
    @semantics.NodeRef::SourceCommand(source) =>
      self.build_source_command(id, source)
    @semantics.NodeRef::ArithmeticExpr(expr) =>
      self.build_arithmetic_expr(id, expr)
    @semantics.NodeRef::ArithmeticToken(token) =>
      self.build_arithmetic_token(id, token)
    @semantics.NodeRef::ArrayIndex(_) => self.sequence_ids(self.children_of(id))
    @semantics.NodeRef::TimeClause(_) => self.sequence_ids(self.children_of(id))
    @semantics.NodeRef::Assignment(assignment) =>
      self.build_assignment(id, assignment, None)
    @semantics.NodeRef::ArrayElement(_) =>
      self.sequence_ids(self.children_of(id))
    @semantics.NodeRef::IfClause(clause) => self.build_if_clause(id, clause)
    @semantics.NodeRef::IfArm(_) => self.sequence_ids(self.children_of(id))
    @semantics.NodeRef::LoopClause(_) => self.build_loop_clause(id)
    @semantics.NodeRef::ForClause(clause) => self.build_for_clause(id, clause)
    @semantics.NodeRef::ArithmeticForClause(_) =>
      self.build_arithmetic_for_clause(id)
    @semantics.NodeRef::SelectClause(clause) =>
      self.build_select_clause(id, clause)
    @semantics.NodeRef::CaseClause(clause) => self.build_case_clause(id, clause)
    @semantics.NodeRef::CaseItem(_) => self.sequence_ids(self.children_of(id))
    @semantics.NodeRef::ConditionCommand(_) => self.build_condition_command(id)
    @semantics.NodeRef::ConditionExpr(expr) =>
      self.build_condition_expr(id, expr)
    @semantics.NodeRef::ArithmeticCommand(_) =>
      self.build_arithmetic_command(id)
    @semantics.NodeRef::CoProcClause(clause) =>
      self.build_co_proc_clause(id, clause)
    @semantics.NodeRef::BatsTestClause(_) => self.build_bats_test_clause(id)
    @semantics.NodeRef::FunctionDef(function_def) =>
      self.build_function_def(id, function_def)
    @semantics.NodeRef::Redirection(redirect) =>
      self.build_redirection(id, redirect)
    @semantics.NodeRef::HereDoc(_) => self.sequence_ids(self.children_of(id))
    @semantics.NodeRef::ExtGlobPattern(_) =>
      self.sequence_ids(self.children_of(id))
    @semantics.NodeRef::BraceExpansion(_) =>
      self.sequence_ids(self.children_of(id))
    @semantics.NodeRef::Word(_) => self.sequence_ids(self.children_of(id))
    @semantics.NodeRef::WordPart(part) => self.build_word_part(id, part)
    @semantics.NodeRef::ParameterExpansion(expansion) =>
      self.build_parameter_expansion(id, expansion)
  }
}

///|
fn GraphBuilder::build_list_item(
  self : GraphBuilder,
  id : CfgAstId,
  item : @parser.ListItem,
) -> Range {
  let annotations = self.children_with_kind(id, AstTag::Annotation)
  let prefix = self.sequence_ids(annotations)
  let and_or_id = self.first_child_with_kind(id, AstTag::AndOrList)
  let main = match item.terminator {
    Some(@parser.Terminator::Background) => {
      let start = self.none()
      let fork = match and_or_id {
        Some(and_or_id) => self.build_subshell("background '&'", and_or_id)
        None => self.none()
      }
      let pid = self.new_node_range(CfgNodeKind::SetBackgroundPid(id))
      let status = self.new_node_range(CfgNodeKind::SetExitCode(id))
      let _ = self.link_range(start, fork)
      let _ = self.link_range_as(CfgEdgeKind::FalseFlow, fork, pid)
      self.link_ranges([start, pid, status])
    }
    _ =>
      match and_or_id {
        Some(and_or_id) => self.build_ast(and_or_id)
        None => self.none()
      }
  }
  self.link_range(prefix, main)
}

///|
fn GraphBuilder::build_and_or_list(
  self : GraphBuilder,
  id : CfgAstId,
  list : @parser.AndOrList,
) -> Range {
  let pipelines = self.children_with_kind(id, AstTag::Pipeline)
  guard pipelines.length() > 0 else { return self.none() }
  let mut current = self.build_ast(pipelines[0])
  let mut i = 0
  while i < list.tail.length() && i + 1 < pipelines.length() {
    let right = self.build_ast(pipelines[i + 1])
    let end = self.none()
    let _ = self.link_range(current, right)
    let _ = self.link_range(right, end)
    let _ = self.link_range(current, end)
    current = self.span_range(current, end)
    i += 1
  }
  current
}

///|
fn GraphBuilder::build_pipeline(
  self : GraphBuilder,
  id : CfgAstId,
  pipeline : @parser.Pipeline,
) -> Range {
  ignore(pipeline)
  let segment_ids = self.children_with_kind(id, AstTag::PipelineSegment)
  if segment_ids.length() <= 1 {
    return self.sequence_ids(segment_ids)
  }
  let start = self.none()
  let result = self.build_pipeline_parts(id, segment_ids, self.params.lastpipe)
  let end = self.new_node_range(CfgNodeKind::SetExitCode(id))
  let leading_exit_edge = if self.params.pipefail {
    CfgEdgeKind::Flow
  } else {
    CfgEdgeKind::FalseFlow
  }
  for leading in result.0 {
    let _ = self.link_range(start, leading)
    let _ = self.link_range_as(leading_exit_edge, leading, end)
  }
  let ranges : Array[Range] = [start]
  for last in result.1 {
    ranges.push(last)
  }
  ranges.push(end)
  self.link_ranges(ranges)
}

///|
fn GraphBuilder::build_pipeline_parts(
  self : GraphBuilder,
  id : CfgAstId,
  segment_ids : Array[CfgAstId],
  lastpipe : Bool,
) -> (Array[Range], Array[Range]) {
  if lastpipe && segment_ids.length() == 1 {
    return ([], [self.build_ast(segment_ids[0])])
  }
  if segment_ids.length() == 0 {
    return ([], [])
  }
  let first = self.build_subshell("pipeline", segment_ids[0])
  let rest = slice_ast_ids(segment_ids, 1)
  let tail = self.build_pipeline_parts(id, rest, lastpipe)
  let leading : Array[Range] = [first]
  for range in tail.0 {
    leading.push(range)
  }
  (leading, tail.1)
}

///|
fn GraphBuilder::build_pipeline_segment(
  self : GraphBuilder,
  id : CfgAstId,
  segment : @parser.PipelineSegment,
) -> Range {
  let command = match self.first_child_with_kind(id, AstTag::Command) {
    Some(command) => self.build_ast(command)
    None => self.none()
  }
  if segment.bangs % 2 == 0 {
    return command
  }
  let status = self.new_node_range(CfgNodeKind::SetExitCode(id))
  self.link_range(command, status)
}

///|
fn GraphBuilder::build_command(
  self : GraphBuilder,
  id : CfgAstId,
  command : @parser.Command,
) -> Range {
  let body = match command.kind {
    @parser.CommandKind::Simple(_) =>
      match self.first_child_with_kind(id, AstTag::SimpleCommand) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::Source(_) =>
      match self.first_child_with_kind(id, AstTag::SourceCommand) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::Time(_) =>
      match self.first_child_with_kind(id, AstTag::TimeClause) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::Subshell(_) =>
      match self.first_child_with_kind(id, AstTag::Script) {
        Some(child) => {
          let main = self.build_subshell("explicit (..) subshell", child)
          let status = self.new_node_range(CfgNodeKind::SetExitCode(id))
          self.link_range(main, status)
        }
        None => self.none()
      }
    @parser.CommandKind::BraceGroup(_) =>
      match self.first_child_with_kind(id, AstTag::Script) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::If(_) =>
      match self.first_child_with_kind(id, AstTag::IfClause) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::While(_) | @parser.CommandKind::Until(_) =>
      match self.first_child_with_kind(id, AstTag::LoopClause) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::ForIn(_) =>
      match self.first_child_with_kind(id, AstTag::ForClause) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::ForArithmetic(_) =>
      match self.first_child_with_kind(id, AstTag::ArithmeticForClause) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::Select(_) =>
      match self.first_child_with_kind(id, AstTag::SelectClause) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::Case(_) =>
      match self.first_child_with_kind(id, AstTag::CaseClause) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::Condition(_) =>
      match self.first_child_with_kind(id, AstTag::ConditionCommand) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::Arithmetic(_) =>
      match self.first_child_with_kind(id, AstTag::ArithmeticCommand) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::Function(_) =>
      match self.first_child_with_kind(id, AstTag::FunctionDef) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::CoProc(_) =>
      match self.first_child_with_kind(id, AstTag::CoProcClause) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
    @parser.CommandKind::BatsTest(_) =>
      match self.first_child_with_kind(id, AstTag::BatsTestClause) {
        Some(child) => self.build_ast(child)
        None => self.none()
      }
  }
  let redirects = self.children_with_kind(id, AstTag::Redirection)
  if redirects.length() == 0 {
    return body
  }
  let redir = self.sequence_ids(redirects)
  self.link_range(redir, body)
}

///|
fn GraphBuilder::build_simple_command(
  self : GraphBuilder,
  id : CfgAstId,
  simple : @parser.SimpleCommand,
) -> Range {
  let assignment_ids = self.children_with_kind(id, AstTag::Assignment)
  let split_assignments = split_simple_assignment_ids(
    self, simple, assignment_ids,
  )
  let prefix_assignment_ids = split_assignments.0
  let suffix_assignment_ids = split_assignments.1
  let word_ids = self.children_with_kind(id, AstTag::Word)
  if simple.words.length() == 0 {
    let parts : Array[Range] = []
    for assignment_id in prefix_assignment_ids {
      let assignment = match self.entry_at(assignment_id).node_ref {
        @semantics.NodeRef::Assignment(assignment) => assignment
        _ => panic()
      }
      parts.push(self.build_assignment(assignment_id, assignment, None))
    }
    let prefix = if parts.length() == 0 {
      self.none()
    } else {
      self.link_ranges(parts)
    }
    let status = self.new_node_range(CfgNodeKind::SetExitCode(id))
    return self.link_range(prefix, status)
  }
  let args = self.sequence_ids(word_ids)
  let assignments = self.build_prefix_assignments(prefix_assignment_ids)
  let action_info = resolve_simple_command_action(self, id, simple)
  let action = if action_info.force_external {
    self.build_external_command(id, action_info.command_name)
  } else {
    self.build_command_action(
      id,
      action_info.command_name,
      action_info.args,
      suffix_assignment_ids,
    )
  }
  let ranges : Array[Range] = [args]
  for assignment in assignments {
    ranges.push(assignment)
  }
  ranges.push(action)
  if prefix_assignment_ids.length() > 0 {
    ranges.push(self.new_node_range(CfgNodeKind::DropPrefixAssignments))
  }
  self.link_ranges(ranges)
}

///|
fn GraphBuilder::build_source_command(
  self : GraphBuilder,
  id : CfgAstId,
  source : @parser.SourceCommand,
) -> Range {
  let children = self.children_of(id)
  let assignment_ids = self.children_with_kind(id, AstTag::Assignment)
  let word_ids = self.children_with_kind(id, AstTag::Word)
  let args = self.sequence_ids(word_ids)
  let assignments = self.build_prefix_assignments(assignment_ids)
  let action = self.build_external_command(id, Some(source.keyword))
  let ranges : Array[Range] = [args]
  for assignment in assignments {
    ranges.push(assignment)
  }
  ranges.push(action)
  let command_range = self.link_ranges(ranges)
  let cleanup = if assignment_ids.length() > 0 {
    Some(self.new_node_range(CfgNodeKind::DropPrefixAssignments))
  } else {
    None
  }
  let included = find_last_child_script(self, children)
  match source.included {
    Some(_) =>
      match included {
        Some(included_id) => {
          let end = self.none()
          let cleanup_target = match cleanup {
            Some(cleanup) => cleanup.start
            None => end.start
          }
          let old_return = self.return_target
          self.return_target = Some(cleanup_target)
          let inlined = self.build_ast(included_id)
          self.return_target = old_return
          let _ = self.link_range(command_range, inlined)
          match cleanup {
            Some(cleanup) => {
              let _ = self.link_range(inlined, cleanup)
              let _ = self.link_range(cleanup, end)
            }
            None => {
              let _ = self.link_range(inlined, end)
            }
          }
          self.span_range(command_range, end)
        }
        None => self.append_optional_cleanup(command_range, cleanup)
      }
    None => self.append_optional_cleanup(command_range, cleanup)
  }
}

///|
fn GraphBuilder::build_assignment(
  self : GraphBuilder,
  id : CfgAstId,
  assignment : @parser.Assignment,
  scope : CfgScope?,
) -> Range {
  let ranges : Array[Range] = [self.build_assignment_inputs(id)]
  if assignment.append {
    ranges.push(
      self.new_node_range(
        CfgNodeKind::ApplyEffects([
          { ast_id: id, effect: CfgEffect::ReadVariable(assignment.name) },
        ]),
      ),
    )
  }
  let effects : Array[CfgTaggedEffect] = [
    {
      ast_id: id,
      effect: assignment_write_effect(
        assignment,
        scope,
        assignment_value_type(id, assignment),
      ),
    },
  ]
  for prop in assignment_added_props(assignment) {
    effects.push({
      ast_id: id,
      effect: CfgEffect::SetProps(scope, assignment.name, [prop]),
    })
  }
  ranges.push(self.new_node_range(CfgNodeKind::ApplyEffects(effects)))
  let range = self.link_ranges(ranges)
  self.record_range(id, range)
  range
}

///|
fn GraphBuilder::build_assignment_inputs(
  self : GraphBuilder,
  id : CfgAstId,
) -> Range {
  let index_ids = self.children_with_kind(id, AstTag::ArrayIndex)
  let value_ids = assignment_value_children(self, id)
  let value = if value_ids.length() == 0 {
    self.none()
  } else {
    self.sequence_ids(value_ids)
  }
  let indexes = if index_ids.length() == 0 {
    self.none()
  } else {
    self.sequence_ids(index_ids)
  }
  self.link_ranges([value, indexes])
}

///|
fn GraphBuilder::build_if_clause(
  self : GraphBuilder,
  id : CfgAstId,
  clause : @parser.IfClause,
) -> Range {
  let start = self.none()
  let arm_ids = self.children_with_kind(id, AstTag::IfArm)
  let branch_starts : Array[Range] = []
  let branch_bodies : Array[Range] = []
  for arm_id in arm_ids {
    let arm = self.build_if_arm_parts(arm_id)
    branch_starts.push(arm.0)
    branch_bodies.push(arm.1)
  }
  let else_id = find_else_script_id(self, id, clause.arms.length())
  let else_body = match else_id {
    Some(else_id) => self.build_ast(else_id)
    None => self.new_node_range(CfgNodeKind::SetExitCode(id))
  }
  let end = self.none()
  let mut previous = start
  let mut i = 0
  while i < branch_starts.length() {
    let condition = branch_starts[i]
    let body = branch_bodies[i]
    let _ = self.link_range(previous, condition)
    let _ = self.link_range(condition, body)
    previous = condition
    i += 1
  }
  let _ = self.link_range(previous, else_body)
  for body in branch_bodies {
    let _ = self.link_range(body, end)
  }
  let _ = self.link_range(else_body, end)
  self.span_range(start, end)
}

///|
fn GraphBuilder::build_if_arm_parts(
  self : GraphBuilder,
  id : CfgAstId,
) -> (Range, Range) {
  self.ast_stack.push(id)
  let children = self.children_with_kind(id, AstTag::Script)
  let old_condition = self.is_condition
  self.is_condition = true
  let condition = match children.get(0) {
    Some(condition) => self.build_ast(condition)
    None => self.none()
  }
  self.is_condition = old_condition
  let body = match children.get(1) {
    Some(body) => self.build_ast(body)
    None => self.none()
  }
  self.record_range(id, self.span_range(condition, body))
  let _ = self.ast_stack.pop()
  (condition, body)
}

///|
fn GraphBuilder::build_loop_clause(self : GraphBuilder, id : CfgAstId) -> Range {
  let children = self.children_with_kind(id, AstTag::Script)
  let head = self.none()
  let end = self.new_node_range(CfgNodeKind::SetExitCode(id))
  self.push_loop_targets(end.start, head.start)
  let old_condition = self.is_condition
  self.is_condition = true
  let condition = match children.get(0) {
    Some(condition) => self.build_ast(condition)
    None => self.none()
  }
  self.is_condition = old_condition
  let body = match children.get(1) {
    Some(body) => self.build_ast(body)
    None => self.none()
  }
  self.pop_loop_targets()
  let _ = self.link_range(head, condition)
  let _ = self.link_range(condition, body)
  let _ = self.link_range(body, head)
  let _ = self.link_range(condition, end)
  self.span_range(head, end)
}

///|
fn GraphBuilder::build_for_clause(
  self : GraphBuilder,
  id : CfgAstId,
  clause : @parser.ForClause,
) -> Range {
  let value_ids = self.children_with_kind(id, AstTag::Word)
  let body = match self.first_child_with_kind(id, AstTag::Script) {
    Some(body) => body
    None => return self.none()
  }
  self.build_for_in_like(id, clause.name, value_ids, body)
}

///|
fn GraphBuilder::build_select_clause(
  self : GraphBuilder,
  id : CfgAstId,
  clause : @parser.SelectClause,
) -> Range {
  let value_ids = self.children_with_kind(id, AstTag::Word)
  let body = match self.first_child_with_kind(id, AstTag::Script) {
    Some(body) => body
    None => return self.none()
  }
  self.build_for_in_like(id, clause.name, value_ids, body)
}

///|
fn GraphBuilder::build_for_in_like(
  self : GraphBuilder,
  id : CfgAstId,
  name : String,
  value_ids : Array[CfgAstId],
  body_id : CfgAstId,
) -> Range {
  let entry = self.none()
  let expansion = self.sequence_ids(value_ids)
  let choice = self.none()
  let writes = loop_assignments(self, value_ids)
  let exit_ = self.none()
  self.push_loop_targets(exit_.start, choice.start)
  let body = self.build_ast(body_id)
  self.pop_loop_targets()
  for write in writes {
    let assign = self.new_node_range(
      CfgNodeKind::ApplyEffects([
        { ast_id: id, effect: CfgEffect::WriteVariable(name, write) },
      ]),
    )
    let _ = self.link_ranges([choice, assign, body])
  }
  let _ = self.link_ranges([entry, expansion, choice])
  let _ = self.link_range(body, exit_)
  let _ = self.link_range(body, choice)
  let _ = self.link_range(expansion, exit_)
  self.span_range(entry, exit_)
}

///|
fn GraphBuilder::build_arithmetic_for_clause(
  self : GraphBuilder,
  id : CfgAstId,
) -> Range {
  let exprs = self.children_with_kind(id, AstTag::ArithmeticExpr)
  let init = match exprs.get(0) {
    Some(init) => self.build_ast(init)
    None => self.none()
  }
  let condition = match exprs.get(1) {
    Some(condition) => self.build_ast(condition)
    None => self.none()
  }
  let step = match exprs.get(2) {
    Some(step) => self.build_ast(step)
    None => self.none()
  }
  let end = self.none()
  self.push_loop_targets(end.start, step.start)
  let body = match self.first_child_with_kind(id, AstTag::Script) {
    Some(body) => self.build_ast(body)
    None => self.none()
  }
  self.pop_loop_targets()
  let _ = self.link_ranges([init, condition, body, step])
  let _ = self.link_range(condition, end)
  let _ = self.link_range(step, condition)
  self.span_range(init, end)
}

///|
fn GraphBuilder::build_case_clause(
  self : GraphBuilder,
  id : CfgAstId,
  clause : @parser.CaseClause,
) -> Range {
  let start = self.none()
  let word = match self.first_child_with_kind(id, AstTag::Word) {
    Some(word) => self.build_ast(word)
    None => self.none()
  }
  let item_ids = self.children_with_kind(id, AstTag::CaseItem)
  if item_ids.length() == 0 {
    return self.link_range(start, word)
  }
  let entries : Array[(@parser.CaseSeparator, Range, Range)] = []
  for item_id in item_ids {
    let item = match self.entry_at(item_id).node_ref {
      @semantics.NodeRef::CaseItem(item) => item
      _ => panic()
    }
    let built = self.build_case_item_parts(item_id)
    entries.push((item.separator, built.0, built.1))
  }
  let end = self.none()
  let _ = self.link_range(start, word)
  let _ = self.link_range(word, entries[0].1)
  let mut i = 0
  while i + 1 < entries.length() {
    let current = entries[i]
    let next = entries[i + 1]
    let _ = self.link_range(current.1, next.1)
    match current.0 {
      @parser.CaseSeparator::Break => {
        let _ = self.link_range(current.2, end)
      }
      @parser.CaseSeparator::FallThrough => {
        let _ = self.link_range(current.2, next.2)
      }
      @parser.CaseSeparator::Continue => {
        let _ = self.link_range(current.2, next.1)
      }
    }
    i += 1
  }
  let _ = self.link_range(entries[entries.length() - 1].2, end)
  if !case_clause_has_catch_all(clause) {
    let _ = self.link_range(word, end)
  }
  self.span_range(start, end)
}

///|
fn GraphBuilder::build_case_item_parts(
  self : GraphBuilder,
  id : CfgAstId,
) -> (Range, Range) {
  self.ast_stack.push(id)
  let children = self.children_of(id)
  let pattern_ids : Array[CfgAstId] = []
  let mut body_id : CfgAstId? = None
  for child in children {
    match self.entry_at(child).kind {
      AstTag::Word => if body_id is None { pattern_ids.push(child) }
      AstTag::Script => body_id = Some(child)
      _ => ()
    }
  }
  let condition = self.build_case_patterns(pattern_ids)
  let body = match body_id {
    Some(body_id) => self.build_ast(body_id)
    None => self.none()
  }
  let _ = self.link_range(condition, body)
  self.record_range(id, self.span_range(condition, body))
  let _ = self.ast_stack.pop()
  (condition, body)
}

///|
fn GraphBuilder::build_case_patterns(
  self : GraphBuilder,
  pattern_ids : Array[CfgAstId],
) -> Range {
  let start = self.none()
  let end = self.none()
  if pattern_ids.length() == 0 {
    let _ = self.link_range(start, end)
    return self.span_range(start, end)
  }
  let ranges : Array[Range] = [start]
  for pattern_id in pattern_ids {
    let pattern = self.build_ast(pattern_id)
    ranges.push(pattern)
    let _ = self.link_range(pattern, end)
  }
  let _ = self.link_ranges(ranges)
  self.span_range(start, end)
}

///|
fn GraphBuilder::build_condition_command(
  self : GraphBuilder,
  id : CfgAstId,
) -> Range {
  let expr = match self.first_child_with_kind(id, AstTag::ConditionExpr) {
    Some(expr) => self.build_ast(expr)
    None => self.none()
  }
  let status = self.new_node_range(CfgNodeKind::SetExitCode(id))
  self.link_range(expr, status)
}

///|
fn GraphBuilder::build_condition_expr(
  self : GraphBuilder,
  id : CfgAstId,
  expr : @parser.ConditionExpr,
) -> Range {
  match expr {
    @parser.ConditionExpr::Empty => self.none()
    @parser.ConditionExpr::Word(_) =>
      self.sequence_ids(self.children_with_kind(id, AstTag::Word))
    @parser.ConditionExpr::Unary(op, word) => {
      let base = self.sequence_ids(self.children_with_kind(id, AstTag::Word))
      let effects = condition_unary_hint_effects(id, op, word)
      if effects.length() == 0 {
        base
      } else {
        self.link_range(
          base,
          self.new_node_range(CfgNodeKind::ApplyEffects(effects)),
        )
      }
    }
    @parser.ConditionExpr::Binary(_, _, _) =>
      self.sequence_ids(self.children_with_kind(id, AstTag::Word))
    @parser.ConditionExpr::Group(_) | @parser.ConditionExpr::Not(_) =>
      self.sequence_ids(self.children_of(id))
    @parser.ConditionExpr::And(_, _) | @parser.ConditionExpr::Or(_, _) => {
      let children = self.children_with_kind(id, AstTag::ConditionExpr)
      if children.length() < 2 {
        return self.sequence_ids(children)
      }
      let left = self.build_ast(children[0])
      let right = self.build_ast(children[1])
      let end = self.none()
      let _ = self.link_ranges([left, right, end])
      let _ = self.link_range(left, end)
      self.span_range(left, end)
    }
  }
}

///|
fn condition_unary_hint_effects(
  id : CfgAstId,
  op : String,
  word : @parser.Word,
) -> Array[CfgTaggedEffect] {
  guard op == "-v" || op == "-R" else { return [] }
  let name = match condition_test_target_name(word) {
    Some(name) => name
    None => return []
  }
  let effects : Array[CfgTaggedEffect] = [
    { ast_id: id, effect: CfgEffect::HintDefined(name) },
  ]
  if condition_test_target_is_indexed(word) {
    effects.push({ ast_id: id, effect: CfgEffect::HintArray(name) })
  }
  effects
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
  let name = condition_target_base_name(text)
  if is_variable_name(name) {
    Some(name)
  } else {
    None
  }
}

///|
fn condition_test_target_is_indexed(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some(text) => text.contains("[")
    None =>
      match @semantics.leading_unquoted_text(word) {
        Some(text) => text.contains("[")
        None => false
      }
  }
}

///|
fn condition_target_base_name(text : String) -> String {
  let view = text[:]
  let mut end = 0
  while end < view.length() && is_name_continue(view[end]) {
    end += 1
  }
  text.view(end_offset=end).to_string()
}

///|
fn GraphBuilder::build_arithmetic_command(
  self : GraphBuilder,
  id : CfgAstId,
) -> Range {
  let expr = match self.first_child_with_kind(id, AstTag::ArithmeticExpr) {
    Some(expr) => self.build_ast(expr)
    None => self.none()
  }
  let status = self.new_node_range(CfgNodeKind::SetExitCode(id))
  self.link_range(expr, status)
}

///|
fn GraphBuilder::build_arithmetic_expr(
  self : GraphBuilder,
  id : CfgAstId,
  expr : @parser.ArithmeticExpr,
) -> Range {
  let token_ids = self.children_with_kind(id, AstTag::ArithmeticToken)
  let ranges : Array[Range] = []
  let mut i = 0
  while i < expr.tokens.length() && i < token_ids.length() {
    ranges.push(
      self.build_arithmetic_token_with_read(
        token_ids[i],
        expr.tokens[i],
        arithmetic_token_needs_read(expr.tokens, i),
      ),
    )
    i += 1
  }
  let base = if ranges.length() == 0 {
    self.none()
  } else {
    self.link_ranges(ranges)
  }
  let effects = arithmetic_write_effects(id, expr.tokens)
  if effects.length() == 0 {
    base
  } else {
    self.link_range(
      base,
      self.new_node_range(CfgNodeKind::ApplyEffects(effects)),
    )
  }
}

///|
fn GraphBuilder::build_co_proc_clause(
  self : GraphBuilder,
  id : CfgAstId,
  clause : @parser.CoProcClause,
) -> Range {
  let start = self.none()
  let parent = match clause.name {
    Some(name) =>
      match @semantics.literal_text(name) {
        Some(name) =>
          self.new_node_range(
            CfgNodeKind::ApplyEffects([
              {
                ast_id: id,
                effect: CfgEffect::WriteVariable(name, CfgValue::Array),
              },
            ]),
          )
        None => self.none()
      }
    None =>
      self.new_node_range(
        CfgNodeKind::ApplyEffects([
          {
            ast_id: id,
            effect: CfgEffect::WriteVariable("COPROC", CfgValue::Array),
          },
        ]),
      )
  }
  let body_id = match self.first_child_with_kind(id, AstTag::Command) {
    Some(body_id) => body_id
    None => return self.none()
  }
  let child = self.build_subshell("coproc", body_id)
  let end = self.new_node_range(CfgNodeKind::SetExitCode(id))
  let _ = self.link_range(start, parent)
  let _ = self.link_range(start, child)
  let _ = self.link_range(parent, end)
  let _ = self.link_range_as(CfgEdgeKind::FalseFlow, child, end)
  self.span_range(start, end)
}

///|
fn GraphBuilder::build_bats_test_clause(
  self : GraphBuilder,
  id : CfgAstId,
) -> Range {
  let status = self.new_node_range(
    CfgNodeKind::ApplyEffects([
      {
        ast_id: id,
        effect: CfgEffect::WriteVariable("status", CfgValue::Integer),
      },
    ]),
  )
  let output = self.new_node_range(
    CfgNodeKind::ApplyEffects([
      {
        ast_id: id,
        effect: CfgEffect::WriteVariable("output", CfgValue::String),
      },
    ]),
  )
  let body = match self.first_child_with_kind(id, AstTag::Script) {
    Some(body) => self.build_ast(body)
    None => self.none()
  }
  self.link_ranges([status, output, body])
}

///|
fn GraphBuilder::build_function_def(
  self : GraphBuilder,
  id : CfgAstId,
  function_def : @parser.FunctionDef,
) -> Range {
  let body_id = match self.first_child_with_kind(id, AstTag::Command) {
    Some(body_id) => body_id
    None => return self.none()
  }
  let entry = self.new_node(
    CfgNodeKind::EntryPoint("function \{function_def.name}"),
  )
  let exit_ = self.new_node(CfgNodeKind::Structural)
  let old_exit = self.exit_target
  let old_return = self.return_target
  let old_function = self.is_function
  let old_break_targets = copy_node_ids(self.loop_break_targets)
  let old_continue_targets = copy_node_ids(self.loop_continue_targets)
  self.exit_target = None
  self.return_target = Some(exit_)
  self.is_function = true
  self.loop_break_targets = []
  self.loop_continue_targets = []
  let body = self.build_ast(body_id)
  self.exit_target = old_exit
  self.return_target = old_return
  self.is_function = old_function
  self.loop_break_targets = old_break_targets
  self.loop_continue_targets = old_continue_targets
  let _ = self.link_ranges([node_range(entry), body, node_range(exit_)])
  let definition = self.new_node_range(
    CfgNodeKind::ApplyEffects([
      {
        ast_id: id,
        effect: CfgEffect::DefineFunction(function_def.name, id, entry, exit_),
      },
    ]),
  )
  let status = self.new_node_range(CfgNodeKind::SetExitCode(id))
  self.link_ranges([definition, status])
}

///|
fn GraphBuilder::build_arithmetic_token(
  self : GraphBuilder,
  id : CfgAstId,
  token : @parser.ArithmeticToken,
) -> Range {
  self.build_arithmetic_token_with_read(id, token, true)
}

///|
fn GraphBuilder::build_arithmetic_token_with_read(
  self : GraphBuilder,
  id : CfgAstId,
  token : @parser.ArithmeticToken,
  should_read : Bool,
) -> Range {
  match token {
    @parser.ArithmeticToken::Literal(_)
    | @parser.ArithmeticToken::Operator(_) => self.none()
    @parser.ArithmeticToken::Variable(name, indexes) => {
      ignore(indexes)
      let index_ids = self.children_with_kind(id, AstTag::ArrayIndex)
      let ranges : Array[Range] = []
      if index_ids.length() > 0 {
        ranges.push(self.sequence_ids(index_ids))
        ranges.push(
          self.new_node_range(
            CfgNodeKind::ApplyEffects([
              { ast_id: id, effect: CfgEffect::HintArray(name) },
            ]),
          ),
        )
      }
      if should_read {
        ranges.push(
          self.new_node_range(
            CfgNodeKind::ApplyEffects([
              { ast_id: id, effect: CfgEffect::ReadVariable(name) },
            ]),
          ),
        )
      }
      if ranges.length() == 0 {
        self.none()
      } else if ranges.length() == 1 {
        ranges[0]
      } else {
        self.link_ranges(ranges)
      }
    }
    @parser.ArithmeticToken::Expansion(_) | @parser.ArithmeticToken::Group(_) =>
      self.sequence_ids(self.children_of(id))
  }
}

///|
fn GraphBuilder::build_word_part(
  self : GraphBuilder,
  id : CfgAstId,
  part : @parser.WordPart,
) -> Range {
  match part {
    @parser.WordPart::Literal(_)
    | @parser.WordPart::SingleQuoted(_)
    | @parser.WordPart::DollarSingleQuoted(_)
    | @parser.WordPart::Glob(_) => self.none()
    @parser.WordPart::Parameter(name) =>
      self.new_node_range(
        CfgNodeKind::ApplyEffects([
          { ast_id: id, effect: CfgEffect::ReadVariable(name) },
        ]),
      )
    @parser.WordPart::SpecialParameter(name) =>
      self.new_node_range(
        CfgNodeKind::ApplyEffects([
          { ast_id: id, effect: CfgEffect::ReadVariable(name) },
        ]),
      )
    @parser.WordPart::DoubleQuoted(_)
    | @parser.WordPart::DollarDoubleQuoted(_)
    | @parser.WordPart::ExtGlob(_)
    | @parser.WordPart::BraceExpansion(_) =>
      self.sequence_ids(self.children_of(id))
    @parser.WordPart::BracedParameter(_) =>
      match self.first_child_with_kind(id, AstTag::ParameterExpansion) {
        Some(expansion) => self.build_ast(expansion)
        None => self.none()
      }
    @parser.WordPart::BraceCommandSubstitution(_, _)
    | @parser.WordPart::CommandSubstitution(_)
    | @parser.WordPart::BackQuoted(_) =>
      match self.first_child_with_kind(id, AstTag::Script) {
        Some(script_id) =>
          self.build_subshell("command substitution", script_id)
        None => self.none()
      }
    @parser.WordPart::ArithmeticExpansion(_)
    | @parser.WordPart::DollarBracket(_) =>
      self.sequence_ids(self.children_with_kind(id, AstTag::ArithmeticExpr))
    @parser.WordPart::ProcessSubstitution(kind, _) =>
      match self.first_child_with_kind(id, AstTag::Script) {
        Some(script_id) => {
          let start = self.none()
          let body = self.build_subshell(
            "\{kind}() process substitution",
            script_id,
          )
          let end = self.none()
          let _ = self.link_range(start, body)
          let _ = self.link_range_as(CfgEdgeKind::FalseFlow, body, end)
          let _ = self.link_range(start, end)
          self.span_range(start, end)
        }
        None => self.none()
      }
  }
}

///|
fn GraphBuilder::build_parameter_expansion(
  self : GraphBuilder,
  id : CfgAstId,
  expansion : @parser.ParameterExpansion,
) -> Range {
  let ranges : Array[Range] = []
  let children = self.children_of(id)
  if children.length() > 0 {
    ranges.push(self.sequence_ids(children))
  }
  match expansion.name {
    Some(name) => {
      if expansion.index is Some(_) {
        ranges.push(
          self.new_node_range(
            CfgNodeKind::ApplyEffects([
              { ast_id: id, effect: CfgEffect::HintArray(name) },
            ]),
          ),
        )
      }
      let read = self.new_node_range(
        CfgNodeKind::ApplyEffects([
          { ast_id: id, effect: CfgEffect::ReadVariable(name) },
        ]),
      )
      ranges.push(read)
      match expansion.operator {
        Some(@parser.ParameterOperator::AssignDefault(_)) => {
          let assign_value = parameter_assign_default_value(id, expansion)
          let assign = self.new_node_range(
            CfgNodeKind::ApplyEffects([
              {
                ast_id: id,
                effect: CfgEffect::WriteVariable(name, assign_value),
              },
            ]),
          )
          let result = self.none()
          let _ = self.link_range(assign, result)
          let total = if ranges.length() == 1 {
            ranges[0]
          } else {
            self.link_ranges(ranges)
          }
          let _ = self.link_range(total, assign)
          let _ = self.link_range(total, result)
          return self.span_range(total, result)
        }
        _ => ()
      }
    }
    None => ()
  }
  if ranges.length() == 0 {
    self.none()
  } else if ranges.length() == 1 {
    ranges[0]
  } else {
    self.link_ranges(ranges)
  }
}

///|
fn GraphBuilder::build_redirection(
  self : GraphBuilder,
  id : CfgAstId,
  redirect : @parser.Redirection,
) -> Range {
  let target = self.sequence_ids(self.children_of(id))
  match redirect.source {
    Some(@parser.RedirectionSource::Named(name)) => {
      let effect = self.new_node_range(
        CfgNodeKind::ApplyEffects([
          {
            ast_id: id,
            effect: if redirection_closes_named_fd(redirect) {
              CfgEffect::ReadVariable(name)
            } else {
              CfgEffect::WriteVariable(name, CfgValue::Integer)
            },
          },
        ]),
      )
      self.link_range(target, effect)
    }
    _ => target
  }
}

///|
fn GraphBuilder::build_prefix_assignments(
  self : GraphBuilder,
  assignment_ids : Array[CfgAstId],
) -> Array[Range] {
  let ranges : Array[Range] = []
  for assignment_id in assignment_ids {
    let assignment = match self.entry_at(assignment_id).node_ref {
      @semantics.NodeRef::Assignment(assignment) => assignment
      _ => panic()
    }
    ranges.push(
      self.build_assignment(assignment_id, assignment, Some(CfgScope::Prefix)),
    )
  }
  ranges
}

///|
fn GraphBuilder::build_command_action(
  self : GraphBuilder,
  id : CfgAstId,
  command_name : String?,
  effective_args : Array[@parser.Word],
  suffix_assignment_ids : Array[CfgAstId],
) -> Range {
  match command_name {
    Some("break") => self.build_break_action(id, effective_args)
    Some("continue") => self.build_continue_action(id, effective_args)
    Some("exit") => self.build_exit_action()
    Some("return") => self.build_return_action()
    Some("unset") => self.build_unset_action(id, effective_args)
    Some("declare")
    | Some("local")
    | Some("typeset")
    | Some("readonly")
    | Some("export") =>
      self.build_declare_action(
        id, command_name, effective_args, suffix_assignment_ids,
      )
    Some("printf") => self.build_printf_action(id, effective_args)
    Some("wait") => self.build_wait_action(id, effective_args)
    Some("mapfile") | Some("readarray") =>
      self.build_mapfile_action(id, effective_args)
    Some("read") => self.build_read_action(id, effective_args)
    Some("DEFINE_boolean")
    | Some("DEFINE_float")
    | Some("DEFINE_integer")
    | Some("DEFINE_string") => self.build_define_action(id, effective_args)
    _ => self.build_external_command(id, command_name)
  }
}

///|
fn GraphBuilder::build_exit_action(self : GraphBuilder) -> Range {
  match self.exit_target {
    Some(target) => {
      let exit_ = self.new_node(CfgNodeKind::ResolvedExit)
      self.link(exit_, target, CfgEdgeKind::Exit)
      let dead_end = self.new_node(CfgNodeKind::Unreachable)
      { start: exit_, end_: dead_end }
    }
    None => {
      let exit_ = self.new_node(CfgNodeKind::UnresolvedExit)
      let dead_end = self.new_node(CfgNodeKind::Unreachable)
      { start: exit_, end_: dead_end }
    }
  }
}

///|
fn GraphBuilder::build_return_action(self : GraphBuilder) -> Range {
  match self.return_target {
    Some(target) => {
      let ret = self.new_node(CfgNodeKind::Structural)
      self.link(ret, target, CfgEdgeKind::Flow)
      let dead_end = self.new_node(CfgNodeKind::Unreachable)
      { start: ret, end_: dead_end }
    }
    None => self.none()
  }
}

///|
fn GraphBuilder::build_break_action(
  self : GraphBuilder,
  id : CfgAstId,
  args : Array[@parser.Word],
) -> Range {
  self.build_loop_control_action(id, args, false)
}

///|
fn GraphBuilder::build_continue_action(
  self : GraphBuilder,
  id : CfgAstId,
  args : Array[@parser.Word],
) -> Range {
  self.build_loop_control_action(id, args, true)
}

///|
fn GraphBuilder::build_loop_control_action(
  self : GraphBuilder,
  id : CfgAstId,
  args : Array[@parser.Word],
  continue_ : Bool,
) -> Range {
  match self.loop_target(continue_, args) {
    Some(target) => {
      let status = self.new_node(CfgNodeKind::SetExitCode(id))
      let jump = self.new_node(CfgNodeKind::Structural)
      self.link(status, jump, CfgEdgeKind::Flow)
      self.link(jump, target, CfgEdgeKind::Flow)
      let dead_end = self.new_node(CfgNodeKind::Unreachable)
      { start: status, end_: dead_end }
    }
    None => self.append_status(id, self.none())
  }
}

///|
fn GraphBuilder::build_unset_action(
  self : GraphBuilder,
  id : CfgAstId,
  args : Array[@parser.Word],
) -> Range {
  let effects : Array[CfgTaggedEffect] = []
  match parse_gnu_literal_args(args, "vfn") {
    Some(parsed) => {
      let mode = unset_mode_from_parsed_flags(parsed.flags)
      for operand in parsed.operands {
        effects.push({ ast_id: id, effect: unset_effect(mode, operand) })
      }
    }
    None => {
      let flags = literal_args(args)
      let mode = unset_mode(flags)
      for text in flags {
        if text.has_prefix("-") || text.has_prefix("+") {
          continue
        }
        effects.push({ ast_id: id, effect: unset_effect(mode, text) })
      }
    }
  }
  self.append_status(
    id,
    self.new_node_range(CfgNodeKind::ApplyEffects(effects)),
  )
}

///|
fn GraphBuilder::build_declare_action(
  self : GraphBuilder,
  id : CfgAstId,
  command_name : String?,
  args : Array[@parser.Word],
  assignment_ids : Array[CfgAstId],
) -> Range {
  let parsed = parse_declare_action_info(args, command_name, self.is_function)
  let ranges : Array[Range] = []
  let effects : Array[CfgTaggedEffect] = []
  if !parsed.skip_variables {
    for assignment_id in assignment_ids {
      let assignment = match self.entry_at(assignment_id).node_ref {
        @semantics.NodeRef::Assignment(assignment) => assignment
        _ => panic()
      }
      ranges.push(
        self.build_declare_assignment_operand(
          assignment_id,
          assignment,
          parsed.scope,
          parsed.added_props,
          parsed.removed_props,
        ),
      )
    }
    for operand in parsed.operands {
      append_declare_operand_effects(
        effects,
        id,
        parsed.scope,
        parsed.added_props,
        parsed.removed_props,
        operand,
      )
    }
  }
  let operands = if effects.length() == 0 {
    self.none()
  } else {
    self.new_node_range(CfgNodeKind::ApplyEffects(effects))
  }
  ranges.push(operands)
  self.append_status(id, self.link_ranges(ranges))
}

///|
fn GraphBuilder::build_printf_action(
  self : GraphBuilder,
  id : CfgAstId,
  args : Array[@parser.Word],
) -> Range {
  let effects : Array[CfgTaggedEffect] = []
  match parse_bsd_literal_args(args, "v:") {
    Some(parsed) =>
      match find_parsed_option_value(parsed.flags, "v") {
        Some(name) =>
          effects.push({
            ast_id: id,
            effect: CfgEffect::WriteVariable(name, CfgValue::String),
          })
        None => ()
      }
    None => ()
  }
  self.append_status(
    id,
    self.new_node_range(CfgNodeKind::ApplyEffects(effects)),
  )
}

///|
fn GraphBuilder::build_wait_action(
  self : GraphBuilder,
  id : CfgAstId,
  args : Array[@parser.Word],
) -> Range {
  let effects : Array[CfgTaggedEffect] = []
  match parse_gnu_literal_args(args, "fnp:") {
    Some(parsed) =>
      match find_parsed_option_value(parsed.flags, "p") {
        Some(name) if is_variable_name(name) =>
          effects.push({
            ast_id: id,
            effect: CfgEffect::WriteVariable(name, CfgValue::Integer),
          })
        _ => ()
      }
    None =>
      match find_literal_gnu_option_value(args, "fnp:", "p") {
        Some(name) if is_variable_name(name) =>
          effects.push({
            ast_id: id,
            effect: CfgEffect::WriteVariable(name, CfgValue::Integer),
          })
        _ => ()
      }
  }
  self.append_status(
    id,
    self.new_node_range(CfgNodeKind::ApplyEffects(effects)),
  )
}

///|
fn GraphBuilder::build_mapfile_action(
  self : GraphBuilder,
  id : CfgAstId,
  args : Array[@parser.Word],
) -> Range {
  let name = resolve_mapfile_target(args)
  self.append_status(
    id,
    self.new_node_range(
      CfgNodeKind::ApplyEffects([
        { ast_id: id, effect: CfgEffect::WriteVariable(name, CfgValue::Array) },
      ]),
    ),
  )
}

///|
fn GraphBuilder::build_read_action(
  self : GraphBuilder,
  id : CfgAstId,
  args : Array[@parser.Word],
) -> Range {
  let effects : Array[CfgTaggedEffect] = []
  match parse_gnu_literal_args(args, flags_for_read()) {
    Some(parsed) =>
      match find_parsed_option_value(parsed.flags, "a") {
        Some(name) if is_variable_name(name) =>
          effects.push({
            ast_id: id,
            effect: CfgEffect::WriteVariable(name, CfgValue::Array),
          })
        _ => append_read_string_effects(effects, id, parsed.operands)
      }
    None =>
      match find_literal_gnu_option_value(args, flags_for_read(), "a") {
        Some(name) if is_variable_name(name) =>
          effects.push({
            ast_id: id,
            effect: CfgEffect::WriteVariable(name, CfgValue::Array),
          })
        _ => {
          let literal_suffix = trailing_literal_words(args)
          match parse_gnu_literal_args(literal_suffix, flags_for_read()) {
            Some(parsed) =>
              match find_parsed_option_value(parsed.flags, "a") {
                Some(name) if is_variable_name(name) =>
                  effects.push({
                    ast_id: id,
                    effect: CfgEffect::WriteVariable(name, CfgValue::Array),
                  })
                _ => append_read_string_effects(effects, id, parsed.operands)
              }
            None => append_read_string_effects(effects, id, [])
          }
        }
      }
  }
  self.append_status(
    id,
    self.new_node_range(CfgNodeKind::ApplyEffects(effects)),
  )
}

///|
fn GraphBuilder::build_define_action(
  self : GraphBuilder,
  id : CfgAstId,
  args : Array[@parser.Word],
) -> Range {
  let effects : Array[CfgTaggedEffect] = []
  match args.get(0) {
    Some(name_word) =>
      match @semantics.literal_text(name_word) {
        Some(name) =>
          effects.push({
            ast_id: id,
            effect: CfgEffect::WriteVariable("FLAGS_" + name, CfgValue::String),
          })
        None => ()
      }
    None => ()
  }
  self.append_status(
    id,
    self.new_node_range(CfgNodeKind::ApplyEffects(effects)),
  )
}

///|
fn GraphBuilder::build_external_command(
  self : GraphBuilder,
  id : CfgAstId,
  command_name : String?,
) -> Range {
  let execute = self.new_node_range(CfgNodeKind::ExecuteCommand(command_name))
  let status = self.new_node_range(CfgNodeKind::SetExitCode(id))
  self.link_range(execute, status)
}

///|
fn GraphBuilder::append_status(
  self : GraphBuilder,
  id : CfgAstId,
  range : Range,
) -> Range {
  let status = self.new_node_range(CfgNodeKind::SetExitCode(id))
  self.link_range(range, status)
}

///|
fn GraphBuilder::append_optional_cleanup(
  self : GraphBuilder,
  range : Range,
  cleanup : Range?,
) -> Range {
  match cleanup {
    Some(cleanup) => self.link_range(range, cleanup)
    None => {
      ignore(self)
      range
    }
  }
}

///|
fn GraphBuilder::build_subshell(
  self : GraphBuilder,
  reason : String,
  body_id : CfgAstId,
) -> Range {
  let entry = self.new_node(CfgNodeKind::EntryPoint("subshell \{reason}"))
  let end = self.new_node(CfgNodeKind::Structural)
  let old_exit = self.exit_target
  let old_return = self.return_target
  let old_break_targets = copy_node_ids(self.loop_break_targets)
  let old_continue_targets = copy_node_ids(self.loop_continue_targets)
  self.exit_target = Some(end)
  self.return_target = Some(end)
  self.loop_break_targets = []
  self.loop_continue_targets = []
  let body = self.build_ast(body_id)
  self.exit_target = old_exit
  self.return_target = old_return
  self.loop_break_targets = old_break_targets
  self.loop_continue_targets = old_continue_targets
  let _ = self.link_ranges([node_range(entry), body, node_range(end)])
  self.new_node_range(CfgNodeKind::ExecuteSubshell(reason, entry, end))
}

///|
fn GraphBuilder::build_declare_assignment_operand(
  self : GraphBuilder,
  id : CfgAstId,
  assignment : @parser.Assignment,
  scope : CfgScope?,
  added_props : Array[CfgVariableProp],
  removed_props : Array[CfgVariableProp],
) -> Range {
  self.ast_stack.push(id)
  let ranges : Array[Range] = [self.build_assignment_inputs(id)]
  if assignment.append {
    ranges.push(
      self.new_node_range(
        CfgNodeKind::ApplyEffects([
          { ast_id: id, effect: CfgEffect::ReadVariable(assignment.name) },
        ]),
      ),
    )
  }
  let effects : Array[CfgTaggedEffect] = [
    {
      ast_id: id,
      effect: scoped_write_effect(
        scope,
        assignment.name,
        assignment_value_type(id, assignment),
      ),
    },
  ]
  for prop in assignment_added_props(assignment) {
    effects.push({
      ast_id: id,
      effect: CfgEffect::SetProps(scope, assignment.name, [prop]),
    })
  }
  if added_props.length() > 0 {
    effects.push({
      ast_id: id,
      effect: CfgEffect::SetProps(scope, assignment.name, added_props),
    })
  }
  if removed_props.length() > 0 {
    effects.push({
      ast_id: id,
      effect: CfgEffect::UnsetProps(scope, assignment.name, removed_props),
    })
  }
  ranges.push(self.new_node_range(CfgNodeKind::ApplyEffects(effects)))
  let range = self.link_ranges(ranges)
  self.record_range(id, range)
  let _ = self.ast_stack.pop()
  range
}

///|
fn assignment_added_props(
  assignment : @parser.Assignment,
) -> Array[CfgVariableProp] {
  if assignment.indexes.length() > 0 {
    return [CfgVariableProp::Array]
  }
  match assignment.value {
    @parser.AssignmentValue::ArrayLiteral(_) => [CfgVariableProp::Array]
    _ => []
  }
}

///|
priv struct ParsedShortOption {
  name : String
  value : String
}

///|
priv struct SimpleCommandAction {
  command_name : String?
  args : Array[@parser.Word]
  force_external : Bool
}

///|
priv struct ParsedLiteralArgs {
  flags : Array[ParsedShortOption]
  operands : Array[String]
}

///|
priv struct DeclareActionInfo {
  operands : Array[@parser.Word]
  added_props : Array[CfgVariableProp]
  removed_props : Array[CfgVariableProp]
  scope : CfgScope?
  skip_variables : Bool
}

///|
fn init_ast_ranges(count : Int) -> Array[(CfgNodeId, CfgNodeId)?] {
  let ranges : Array[(CfgNodeId, CfgNodeId)?] = []
  for _ in 0..<count {
    ranges.push(None)
  }
  ranges
}

///|
fn split_simple_assignment_ids(
  builder : GraphBuilder,
  simple : @parser.SimpleCommand,
  assignment_ids : Array[CfgAstId],
) -> (Array[CfgAstId], Array[CfgAstId]) {
  guard simple.words.length() > 0 else { return (assignment_ids, []) }
  let first_word_offset = simple.words[0].span.start.offset
  let prefix : Array[CfgAstId] = []
  let suffix : Array[CfgAstId] = []
  for assignment_id in assignment_ids {
    let assignment = match builder.entry_at(assignment_id).node_ref {
      @semantics.NodeRef::Assignment(assignment) => assignment
      _ => panic()
    }
    if assignment.span.start.offset < first_word_offset {
      prefix.push(assignment_id)
    } else {
      suffix.push(assignment_id)
    }
  }
  (prefix, suffix)
}

///|
fn resolve_simple_command_action(
  builder : GraphBuilder,
  id : CfgAstId,
  simple : @parser.SimpleCommand,
) -> SimpleCommandAction {
  match builder.parent_command_of(id) {
    Some(command) =>
      resolve_wrapped_command_action(
        @semantics.command_name(command),
        @semantics.command_arguments(command),
        @semantics.effective_command_name(command),
        @semantics.effective_command_arguments(command),
      )
    None =>
      resolve_wrapped_command_action(
        match simple.words.get(0) {
          Some(word) => @semantics.literal_text(word)
          None => None
        },
        slice_words(simple.words, 1),
        match simple.words.get(0) {
          Some(word) => @semantics.literal_text(word)
          None => None
        },
        slice_words(simple.words, 1),
      )
  }
}

///|
fn resolve_wrapped_command_action(
  direct_name : String?,
  direct_args : Array[@parser.Word],
  effective_name : String?,
  effective_args : Array[@parser.Word],
) -> SimpleCommandAction {
  match direct_name {
    Some("builtin") =>
      if effective_name != direct_name {
        {
          command_name: effective_name,
          args: effective_args,
          force_external: false,
        }
      } else {
        { command_name: direct_name, args: direct_args, force_external: false }
      }
    Some("command") =>
      if effective_name != direct_name {
        {
          command_name: effective_name,
          args: effective_args,
          force_external: true,
        }
      } else {
        { command_name: direct_name, args: direct_args, force_external: false }
      }
    _ => { command_name: direct_name, args: direct_args, force_external: false }
  }
}

///|
fn init_ast_nodes(count : Int) -> Array[Array[CfgNodeId]] {
  let values : Array[Array[CfgNodeId]] = []
  for _ in 0..<count {
    values.push([])
  }
  values
}

///|
fn parameter_assign_default_value(
  id : CfgAstId,
  expansion : @parser.ParameterExpansion,
) -> CfgValue {
  match expansion.operator {
    Some(@parser.ParameterOperator::AssignDefault(value)) =>
      CfgValue::Computed(
        id,
        word_parts_to_string_parts(@parser.parse_text_as_word(value).parts),
      )
    _ => CfgValue::String
  }
}

///|
fn assignment_value_children(
  builder : GraphBuilder,
  id : CfgAstId,
) -> Array[CfgAstId] {
  let values : Array[CfgAstId] = []
  for child in builder.children_of(id) {
    if builder.entry_at(child).kind != AstTag::ArrayIndex {
      values.push(child)
    }
  }
  values
}

///|
fn assignment_value_type(
  id : CfgAstId,
  assignment : @parser.Assignment,
) -> CfgValue {
  if assignment.indexes.length() > 0 {
    return CfgValue::Array
  }
  match assignment.value {
    @parser.AssignmentValue::Empty =>
      scalar_assignment_value(id, assignment.name, assignment.append, [])
    @parser.AssignmentValue::Word(word) =>
      scalar_assignment_value(
        id,
        assignment.name,
        assignment.append,
        word_parts_to_string_parts(word.parts),
      )
    @parser.AssignmentValue::ArrayLiteral(_) => CfgValue::Array
  }
}

///|
fn scalar_assignment_value(
  id : CfgAstId,
  name : String,
  append : Bool,
  parts : Array[CfgStringPart],
) -> CfgValue {
  let combined : Array[CfgStringPart] = []
  if append {
    combined.push(CfgStringPart::Variable(name))
  }
  for part in parts {
    combined.push(part)
  }
  CfgValue::Computed(id, combined)
}

///|
fn assignment_write_effect(
  assignment : @parser.Assignment,
  scope : CfgScope?,
  value : CfgValue,
) -> CfgEffect {
  match scope {
    Some(CfgScope::Prefix) => CfgEffect::WritePrefix(assignment.name, value)
    Some(CfgScope::Local) => CfgEffect::WriteLocal(assignment.name, value)
    Some(CfgScope::Global) => CfgEffect::WriteGlobal(assignment.name, value)
    None => CfgEffect::WriteVariable(assignment.name, value)
  }
}

///|
fn loop_assignments(
  builder : GraphBuilder,
  value_ids : Array[CfgAstId],
) -> Array[CfgValue] {
  if value_ids.length() == 0 {
    return [CfgValue::String]
  }
  let values : Array[CfgValue] = []
  let mut all_constant = true
  for value_id in value_ids {
    match builder.entry_at(value_id).node_ref {
      @semantics.NodeRef::Word(word) =>
        if !@semantics.is_constant_word(word) {
          all_constant = false
        } else {
          values.push(
            CfgValue::Computed(value_id, word_parts_to_string_parts(word.parts)),
          )
        }
      _ => all_constant = false
    }
  }
  if !all_constant {
    return [CfgValue::String]
  }
  values
}

///|
fn find_else_script_id(
  builder : GraphBuilder,
  id : CfgAstId,
  arm_count : Int,
) -> CfgAstId? {
  ignore(arm_count)
  find_last_child_script(builder, builder.children_of(id))
}

///|
fn case_clause_has_catch_all(clause : @parser.CaseClause) -> Bool {
  for item in clause.items {
    if item.patterns.length() == 1 && item.patterns[0].source == "*" {
      return true
    }
  }
  false
}

///|
fn literal_args(args : Array[@parser.Word]) -> Array[String] {
  let values : Array[String] = []
  for arg in args {
    match @semantics.literal_text(arg) {
      Some(text) => values.push(text)
      None => ()
    }
  }
  values
}

///|
fn loop_control_depth(args : Array[@parser.Word]) -> Int {
  match args.get(0) {
    Some(arg) =>
      match @semantics.literal_text(arg) {
        Some(text) =>
          match parse_positive_int(text) {
            Some(depth) => depth
            None => 1
          }
        None => 1
      }
    None => 1
  }
}

///|
fn parse_positive_int(text : String) -> Int? {
  let view = text[:]
  if view.length() == 0 {
    return None
  }
  let mut value = 0
  for ch in view {
    if ch < '0' || ch > '9' {
      return None
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  if value <= 0 {
    None
  } else {
    Some(value)
  }
}

///|
fn unset_mode(flags : Array[String]) -> String {
  let mut saw_n = false
  let mut saw_v = false
  let mut saw_f = false
  for flag in flags {
    if !is_unset_cluster(flag) {
      continue
    }
    let view = flag[:]
    let mut i = 1
    while i < view.length() {
      match flag.view(start_offset=i, end_offset=i + 1).to_string() {
        "n" => saw_n = true
        "v" => saw_v = true
        "f" => saw_f = true
        _ => ()
      }
      i += 1
    }
  }
  if saw_n {
    "nameref"
  } else if saw_v {
    "variable"
  } else if saw_f {
    "function"
  } else {
    ""
  }
}

///|
fn is_unset_cluster(flag : String) -> Bool {
  if !flag.has_prefix("-") || flag == "-" {
    return false
  }
  let view = flag[:]
  let mut i = 1
  while i < view.length() {
    let ch = view[i]
    if ch != 'v' && ch != 'f' && ch != 'n' {
      return false
    }
    i += 1
  }
  true
}

///|
fn unset_mode_from_parsed_flags(flags : Array[ParsedShortOption]) -> String {
  let mut saw_n = false
  let mut saw_v = false
  let mut saw_f = false
  for flag in flags {
    if flag.name == "n" {
      saw_n = true
    } else if flag.name == "v" {
      saw_v = true
    } else if flag.name == "f" {
      saw_f = true
    }
  }
  if saw_n {
    "nameref"
  } else if saw_v {
    "variable"
  } else if saw_f {
    "function"
  } else {
    ""
  }
}

///|
fn unset_effect(mode : String, text : String) -> CfgEffect {
  match mode {
    "nameref" => CfgEffect::UndefineNameref(text)
    "variable" => CfgEffect::UndefineVariable(text)
    "function" => CfgEffect::UndefineFunction(text)
    _ => CfgEffect::Undefine(text)
  }
}

///|
fn push_prop(props : Array[CfgVariableProp], prop : CfgVariableProp) -> Unit {
  for current in props {
    if current == prop {
      return
    }
  }
  props.push(prop)
}

///|
fn scoped_write_effect(
  scope : CfgScope?,
  name : String,
  value : CfgValue,
) -> CfgEffect {
  match scope {
    Some(CfgScope::Local) => CfgEffect::WriteLocal(name, value)
    Some(CfgScope::Global) => CfgEffect::WriteGlobal(name, value)
    Some(CfgScope::Prefix) => CfgEffect::WritePrefix(name, value)
    None => CfgEffect::WriteVariable(name, value)
  }
}

///|
fn trailing_literal_words(args : Array[@parser.Word]) -> Array[@parser.Word] {
  let suffix : Array[@parser.Word] = []
  let mut i = args.length()
  while i > 0 {
    i -= 1
    match @semantics.literal_text(args[i]) {
      Some(_) => suffix.push(args[i])
      None => break
    }
  }
  reverse_words(suffix)
}

///|
fn parse_declare_action_info(
  args : Array[@parser.Word],
  command_name : String?,
  is_function : Bool,
) -> DeclareActionInfo {
  let operands : Array[@parser.Word] = []
  let added_props : Array[CfgVariableProp] = []
  let removed_props : Array[CfgVariableProp] = []
  let mut saw_global = false
  let mut skip_variables = false
  let mut end_of_options = false
  let mut saw_unexport = false
  for arg in args {
    if end_of_options {
      operands.push(arg)
      continue
    }
    match @semantics.literal_text(arg) {
      Some("--") => end_of_options = true
      Some(text) =>
        match command_name {
          Some("export") =>
            match parse_plus_minus_flag_token(text) {
              Some((true, flags)) =>
                for flag in flags {
                  match flag {
                    "f" | "F" | "p" => skip_variables = true
                    "n" => saw_unexport = true
                    _ => ()
                  }
                }
              _ => operands.push(arg)
            }
          Some("readonly") =>
            match parse_plus_minus_flag_token(text) {
              Some((true, flags)) =>
                for flag in flags {
                  match flag {
                    "A" => push_prop(added_props, CfgVariableProp::Associative)
                    "a" => push_prop(added_props, CfgVariableProp::Array)
                    "f" | "F" | "p" => skip_variables = true
                    _ => ()
                  }
                }
              _ => operands.push(arg)
            }
          _ =>
            match parse_plus_minus_flag_token(text) {
              Some((enabled, flags)) =>
                for flag in flags {
                  match flag {
                    "A" if enabled =>
                      push_prop(added_props, CfgVariableProp::Associative)
                    "a" if enabled =>
                      push_prop(added_props, CfgVariableProp::Array)
                    "i" if enabled =>
                      push_prop(added_props, CfgVariableProp::Integer)
                    "i" => push_prop(removed_props, CfgVariableProp::Integer)
                    "x" if enabled =>
                      push_prop(added_props, CfgVariableProp::Export)
                    "x" => push_prop(removed_props, CfgVariableProp::Export)
                    "g" if enabled => saw_global = true
                    "f" | "F" | "p" if enabled => skip_variables = true
                    _ => ()
                  }
                }
              None => operands.push(arg)
            }
        }
      None => operands.push(arg)
    }
  }
  match command_name {
    Some("export") =>
      if saw_unexport {
        push_prop(removed_props, CfgVariableProp::Export)
      } else if !skip_variables {
        push_prop(added_props, CfgVariableProp::Export)
      }
    _ => ()
  }
  let scope = match command_name {
    Some("local") => Some(CfgScope::Local)
    _ =>
      if saw_global {
        Some(CfgScope::Global)
      } else if is_function && declare_defaults_to_local_scope(command_name) {
        Some(CfgScope::Local)
      } else {
        None
      }
  }
  { operands, added_props, removed_props, scope, skip_variables }
}

///|
fn declare_defaults_to_local_scope(command_name : String?) -> Bool {
  match command_name {
    Some("declare") | Some("typeset") => true
    _ => false
  }
}

///|
fn parse_plus_minus_flag_token(text : String) -> (Bool, Array[String])? {
  guard text.length() > 1 else { return None }
  let view = text[:]
  let enabled = match view[0] {
    '-' => true
    '+' => false
    _ => return None
  }
  let flags : Array[String] = []
  let mut i = 1
  while i < view.length() {
    let ch = view[i]
    if !((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
      return None
    }
    flags.push(text.view(start_offset=i, end_offset=i + 1).to_string())
    i += 1
  }
  Some((enabled, flags))
}

///|
fn append_declare_operand_effects(
  effects : Array[CfgTaggedEffect],
  id : CfgAstId,
  scope : CfgScope?,
  added_props : Array[CfgVariableProp],
  removed_props : Array[CfgVariableProp],
  operand : @parser.Word,
) -> Unit {
  match @semantics.literal_text(operand) {
    Some(text) =>
      match split_declare_assignment(text) {
        Some((name, append, value)) => {
          if append {
            effects.push({ ast_id: id, effect: CfgEffect::ReadVariable(name) })
          }
          effects.push({
            ast_id: id,
            effect: scoped_write_effect(
              scope,
              name,
              scalar_assignment_value(
                id,
                name,
                append,
                declare_assignment_parts(value),
              ),
            ),
          })
          append_declare_property_effects(
            effects, id, scope, added_props, removed_props, name,
          )
        }
        None =>
          if is_variable_name(text) {
            append_declare_property_effects(
              effects, id, scope, added_props, removed_props, text,
            )
          }
      }
    None =>
      match leading_declare_assignment(operand) {
        Some((name, append)) => {
          if append {
            effects.push({ ast_id: id, effect: CfgEffect::ReadVariable(name) })
          }
          effects.push({
            ast_id: id,
            effect: scoped_write_effect(
              scope,
              name,
              scalar_assignment_value(id, name, append, [CfgStringPart::Unknown]),
            ),
          })
          append_declare_property_effects(
            effects, id, scope, added_props, removed_props, name,
          )
        }
        None => ()
      }
  }
}

///|
fn append_declare_property_effects(
  effects : Array[CfgTaggedEffect],
  id : CfgAstId,
  scope : CfgScope?,
  added_props : Array[CfgVariableProp],
  removed_props : Array[CfgVariableProp],
  name : String,
) -> Unit {
  if added_props.length() > 0 {
    effects.push({
      ast_id: id,
      effect: CfgEffect::SetProps(scope, name, added_props),
    })
  }
  if removed_props.length() > 0 {
    effects.push({
      ast_id: id,
      effect: CfgEffect::UnsetProps(scope, name, removed_props),
    })
  }
}

///|
fn split_declare_assignment(text : String) -> (String, Bool, String)? {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    if view[i] == '=' {
      if i == 0 {
        return None
      }
      let raw_name = text.view(end_offset=i).to_string()
      let append = raw_name.has_suffix("+")
      let name = if append {
        raw_name.view(end_offset=raw_name.length() - 1).to_string()
      } else {
        raw_name
      }
      if !is_variable_name(name) {
        return None
      }
      return Some((name, append, text.view(start_offset=i + 1).to_string()))
    }
    i += 1
  }
  None
}

///|
fn leading_declare_assignment(operand : @parser.Word) -> (String, Bool)? {
  match @semantics.leading_unquoted_text(operand) {
    Some(prefix) =>
      match split_declare_assignment(prefix) {
        Some((name, append, _)) => Some((name, append))
        None => None
      }
    None => None
  }
}

///|
fn declare_assignment_parts(value : String) -> Array[CfgStringPart] {
  if value == "" {
    []
  } else {
    [CfgStringPart::Literal(value)]
  }
}

///|
fn resolve_mapfile_target(args : Array[@parser.Word]) -> String {
  match parse_gnu_literal_args(args, flags_for_mapfile()) {
    Some(parsed) =>
      match parsed.operands.get(0) {
        Some(name) if is_variable_name(name) => name
        Some(_) => mapfile_fallback_target(args)
        None => "MAPFILE"
      }
    None => mapfile_fallback_target(args)
  }
}

///|
fn mapfile_fallback_target(args : Array[@parser.Word]) -> String {
  let mut i = args.length()
  while i > 0 {
    i -= 1
    match @semantics.literal_text(args[i]) {
      Some(name) if is_variable_name(name) => return name
      _ => ()
    }
  }
  "MAPFILE"
}

///|
fn append_read_string_effects(
  effects : Array[CfgTaggedEffect],
  id : CfgAstId,
  names : Array[String],
) -> Unit {
  if names.length() == 0 {
    effects.push({
      ast_id: id,
      effect: CfgEffect::WriteVariable("REPLY", CfgValue::String),
    })
    return
  }
  for name in names {
    effects.push({
      ast_id: id,
      effect: CfgEffect::WriteVariable(name, CfgValue::String),
    })
  }
}

///|
fn flags_for_read() -> String {
  @semantics.read_option_spec()
}

///|
fn flags_for_mapfile() -> String {
  @semantics.mapfile_option_spec()
}

///|
fn parse_gnu_literal_args(
  args : Array[@parser.Word],
  spec : String,
) -> ParsedLiteralArgs? {
  parse_short_literal_args(args, spec, true)
}

///|
fn parse_bsd_literal_args(
  args : Array[@parser.Word],
  spec : String,
) -> ParsedLiteralArgs? {
  parse_short_literal_args(args, spec, false)
}

///|
fn parse_short_literal_args(
  args : Array[@parser.Word],
  spec : String,
  gnu_style : Bool,
) -> ParsedLiteralArgs? {
  let flags : Array[ParsedShortOption] = []
  let operands : Array[String] = []
  let mut end_of_options = false
  let mut i = 0
  while i < args.length() {
    let text = match @semantics.literal_text(args[i]) {
      Some(text) => text
      None =>
        if gnu_style {
          return None
        } else {
          end_of_options = true
          i += 1
          continue
        }
    }
    if end_of_options {
      operands.push(text)
      i += 1
      continue
    }
    if text == "--" {
      end_of_options = true
      i += 1
      continue
    }
    if text.has_prefix("--") {
      return None
    }
    if text.has_prefix("-") && text != "-" {
      let option_text = text.view(start_offset=1).to_string()
      let option_view = option_text[:]
      if option_view.length() == 0 {
        operands.push(text)
        i += 1
        continue
      }
      let mut j = 0
      while j < option_view.length() {
        let name = option_text
          .view(start_offset=j, end_offset=j + 1)
          .to_string()
        let needs_value = match
          short_flag_requires_value(spec, option_view[j]) {
          Some(needs_value) => needs_value
          None => return None
        }
        if needs_value {
          if j + 1 < option_view.length() {
            flags.push({
              name,
              value: option_text.view(start_offset=j + 1).to_string(),
            })
          } else {
            guard i + 1 < args.length() else { return None }
            let value = match @semantics.literal_text(args[i + 1]) {
              Some(value) => value
              None => return None
            }
            flags.push({ name, value })
            i += 1
          }
          break
        }
        flags.push({ name, value: name })
        j += 1
      }
    } else {
      operands.push(text)
      if !gnu_style {
        end_of_options = true
      }
    }
    i += 1
  }
  Some({ flags, operands })
}

///|
fn short_flag_requires_value(spec : String, flag : UInt16) -> Bool? {
  let view = spec[:]
  let mut i = 0
  while i < view.length() {
    if view[i] == flag {
      return Some(i + 1 < view.length() && view[i + 1] == ':')
    }
    if i + 1 < view.length() && view[i + 1] == ':' {
      i += 2
    } else {
      i += 1
    }
  }
  None
}

///|
fn find_parsed_option_value(
  flags : Array[ParsedShortOption],
  target : String,
) -> String? {
  for flag in flags {
    if flag.name == target {
      return Some(flag.value)
    }
  }
  None
}

///|
fn find_literal_gnu_option_value(
  args : Array[@parser.Word],
  spec : String,
  target : String,
) -> String? {
  let mut end_of_options = false
  let mut i = 0
  while i < args.length() {
    let text = match @semantics.literal_text(args[i]) {
      Some(text) => text
      None => {
        i += 1
        continue
      }
    }
    if end_of_options {
      i += 1
      continue
    }
    if text == "--" {
      end_of_options = true
      i += 1
      continue
    }
    if text.has_prefix("--") {
      return None
    }
    if text.has_prefix("-") && text != "-" {
      let option_text = text.view(start_offset=1).to_string()
      let option_view = option_text[:]
      if option_view.length() == 0 {
        i += 1
        continue
      }
      let mut j = 0
      while j < option_view.length() {
        let name = option_text
          .view(start_offset=j, end_offset=j + 1)
          .to_string()
        let needs_value = match
          short_flag_requires_value(spec, option_view[j]) {
          Some(needs_value) => needs_value
          None => return None
        }
        if needs_value {
          let value = if j + 1 < option_view.length() {
            Some(option_text.view(start_offset=j + 1).to_string())
          } else if i + 1 < args.length() {
            @semantics.literal_text(args[i + 1])
          } else {
            None
          }
          if name == target {
            match value {
              Some(value) => return Some(value)
              None => ()
            }
          }
          if j + 1 >= option_view.length() && i + 1 < args.length() {
            i += 1
          }
          break
        }
        j += 1
      }
    }
    i += 1
  }
  None
}

///|
fn is_variable_name(name : String) -> Bool {
  let view = name[:]
  if view.length() == 0 {
    return false
  }
  if !is_name_start(view[0]) {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if !is_name_continue(view[i]) {
      return false
    }
    i += 1
  }
  true
}

///|
fn is_name_start(ch : UInt16) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

///|
fn is_name_continue(ch : UInt16) -> Bool {
  is_name_start(ch) || (ch >= '0' && ch <= '9')
}

///|
fn word_parts_to_string_parts(
  parts : Array[@parser.WordPart],
) -> Array[CfgStringPart] {
  let values : Array[CfgStringPart] = []
  for part in parts {
    append_string_parts(values, part)
  }
  values
}

///|
fn append_string_parts(
  values : Array[CfgStringPart],
  part : @parser.WordPart,
) -> Unit {
  match part {
    @parser.WordPart::Literal(text) | @parser.WordPart::SingleQuoted(text) =>
      values.push(CfgStringPart::Literal(text))
    @parser.WordPart::DollarSingleQuoted(text) =>
      values.push(CfgStringPart::Literal(decode_dollar_single_quoted(text)))
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      for nested in parts {
        append_string_parts(values, nested)
      }
    @parser.WordPart::Parameter(name)
    | @parser.WordPart::SpecialParameter(name) =>
      values.push(CfgStringPart::Variable(name))
    @parser.WordPart::BracedParameter(expansion) =>
      match expansion.name {
        Some(name) if expansion.operator is None =>
          values.push(CfgStringPart::Variable(name))
        _ => values.push(CfgStringPart::Unknown)
      }
    @parser.WordPart::ArithmeticExpansion(_)
    | @parser.WordPart::DollarBracket(_) => values.push(CfgStringPart::Integer)
    _ => values.push(CfgStringPart::Unknown)
  }
}

///|
fn decode_dollar_single_quoted(text : String) -> String {
  let view = text[:]
  let buf = StringBuilder::new()
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch != '\\' {
      buf.write_char(ch.unsafe_to_char())
      i += 1
      continue
    }
    if i + 1 >= view.length() {
      buf.write_char('\\')
      i += 1
      continue
    }
    let next = view[i + 1]
    match next {
      'a' => {
        buf.write_char((7).unsafe_to_char())
        i += 2
      }
      'b' => {
        buf.write_char((8).unsafe_to_char())
        i += 2
      }
      'e' => {
        buf.write_char((27).unsafe_to_char())
        i += 2
      }
      'f' => {
        buf.write_char((12).unsafe_to_char())
        i += 2
      }
      'n' => {
        buf.write_char('\n')
        i += 2
      }
      'r' => {
        buf.write_char('\r')
        i += 2
      }
      't' => {
        buf.write_char('\t')
        i += 2
      }
      'v' => {
        buf.write_char((11).unsafe_to_char())
        i += 2
      }
      '\'' | '"' | '\\' => {
        buf.write_char(next.unsafe_to_char())
        i += 2
      }
      'x' => {
        let first = if i + 2 < view.length() {
          hex_digit_value(view[i + 2])
        } else {
          None
        }
        let second = if i + 3 < view.length() {
          hex_digit_value(view[i + 3])
        } else {
          None
        }
        match (first, second) {
          (Some(a), Some(b)) => {
            buf.write_char((a * 16 + b).unsafe_to_char())
            i += 4
          }
          (Some(a), None) => {
            buf.write_char(a.unsafe_to_char())
            i += 3
          }
          _ => {
            buf.write_char('\\')
            buf.write_char('x')
            i += 2
          }
        }
      }
      _ if is_octal_digit(next) => {
        let mut value = octal_digit_value(next)
        let mut consumed = 2
        if i + consumed < view.length() && is_octal_digit(view[i + consumed]) {
          value = value * 8 + octal_digit_value(view[i + consumed])
          consumed += 1
        }
        if i + consumed < view.length() && is_octal_digit(view[i + consumed]) {
          value = value * 8 + octal_digit_value(view[i + consumed])
          consumed += 1
        }
        buf.write_char((value % 256).unsafe_to_char())
        i += consumed
      }
      _ => {
        buf.write_char('\\')
        buf.write_char(next.unsafe_to_char())
        i += 2
      }
    }
  }
  buf.to_string()
}

///|
fn hex_digit_value(ch : UInt16) -> Int? {
  if ch >= '0' && ch <= '9' {
    return Some(ch.to_int() - '0'.to_int())
  }
  if ch >= 'a' && ch <= 'f' {
    return Some(ch.to_int() - 'a'.to_int() + 10)
  }
  if ch >= 'A' && ch <= 'F' {
    return Some(ch.to_int() - 'A'.to_int() + 10)
  }
  None
}

///|
fn is_octal_digit(ch : UInt16) -> Bool {
  ch >= '0' && ch <= '7'
}

///|
fn octal_digit_value(ch : UInt16) -> Int {
  ch.to_int() - '0'.to_int()
}

///|
fn find_last_child_script(
  builder : GraphBuilder,
  children : Array[CfgAstId],
) -> CfgAstId? {
  let mut i = children.length()
  while i > 0 {
    i -= 1
    if builder.entry_at(children[i]).kind == AstTag::Script {
      return Some(children[i])
    }
  }
  None
}

///|
fn copy_ast_ids(ids : Array[CfgAstId]) -> Array[CfgAstId] {
  let copied : Array[CfgAstId] = []
  for id in ids {
    copied.push(id)
  }
  copied
}

///|
fn copy_node_ids(ids : Array[CfgNodeId]) -> Array[CfgNodeId] {
  let copied : Array[CfgNodeId] = []
  for id in ids {
    copied.push(id)
  }
  copied
}

///|
fn copy_cfg_nodes(nodes : Array[CfgNode]) -> Array[CfgNode] {
  let copied : Array[CfgNode] = []
  for node in nodes {
    copied.push(node)
  }
  copied
}

///|
fn copy_cfg_edges(edges : Array[CfgEdge]) -> Array[CfgEdge] {
  let copied : Array[CfgEdge] = []
  for edge in edges {
    copied.push(edge)
  }
  copied
}

///|
fn copy_ast_entries(entries : Array[AstEntry]) -> Array[AstEntry] {
  let copied : Array[AstEntry] = []
  for entry in entries {
    copied.push({
      id: entry.id,
      kind: entry.kind,
      node_ref: entry.node_ref,
      span: entry.span,
      enclosing_span: entry.enclosing_span,
      parent: entry.parent,
      children: copy_ast_ids(entry.children),
    })
  }
  copied
}

///|
fn copy_ast_ranges(
  ranges : Array[(CfgNodeId, CfgNodeId)?],
) -> Array[(CfgNodeId, CfgNodeId)?] {
  let copied : Array[(CfgNodeId, CfgNodeId)?] = []
  for range in ranges {
    copied.push(range)
  }
  copied
}

///|
fn copy_nested_node_ids(
  values : Array[Array[CfgNodeId]],
) -> Array[Array[CfgNodeId]] {
  let copied : Array[Array[CfgNodeId]] = []
  for value in values {
    copied.push(copy_node_ids(value))
  }
  copied
}

///|
fn copy_post_dominators(
  values : Array[Array[CfgNodeId]],
) -> Array[Array[CfgNodeId]] {
  let copied : Array[Array[CfgNodeId]] = []
  for value in values {
    copied.push(copy_node_ids(value))
  }
  copied
}

///|
fn reverse_words(values : Array[@parser.Word]) -> Array[@parser.Word] {
  let reversed : Array[@parser.Word] = []
  let mut i = values.length()
  while i > 0 {
    i -= 1
    reversed.push(values[i])
  }
  reversed
}

///|
fn slice_ast_ids(values : Array[CfgAstId], start : Int) -> Array[CfgAstId] {
  let sliced : Array[CfgAstId] = []
  let mut i = start
  while i < values.length() {
    sliced.push(values[i])
    i += 1
  }
  sliced
}

///|
fn slice_words(
  values : Array[@parser.Word],
  start : Int,
) -> Array[@parser.Word] {
  let sliced : Array[@parser.Word] = []
  let mut i = start
  while i < values.length() {
    sliced.push(values[i])
    i += 1
  }
  sliced
}

///|
fn contains_node_id(values : Array[CfgNodeId], target : CfgNodeId) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
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
fn arithmetic_write_effects(
  id : CfgAstId,
  tokens : Array[@parser.ArithmeticToken],
) -> Array[CfgTaggedEffect] {
  let effects : Array[CfgTaggedEffect] = []
  let mut i = 0
  while i < tokens.length() {
    match tokens[i] {
      @parser.ArithmeticToken::Variable(name, indexes) =>
        if arithmetic_token_writes(
            arithmetic_prev_operator(tokens, i),
            arithmetic_next_operator(tokens, i),
          ) {
          effects.push({
            ast_id: id,
            effect: CfgEffect::WriteVariable(
              name,
              arithmetic_written_value(indexes),
            ),
          })
        }
      _ => ()
    }
    i += 1
  }
  effects
}

///|
fn arithmetic_token_writes(previous : String?, next : String?) -> Bool {
  match previous {
    Some(op) if is_arithmetic_incdec_operator(op) => true
    _ =>
      match next {
        Some(op) if is_arithmetic_write_operator(op) => true
        _ => false
      }
  }
}

///|
fn arithmetic_prev_operator(
  tokens : Array[@parser.ArithmeticToken],
  index : Int,
) -> String? {
  if index == 0 {
    return None
  }
  match tokens[index - 1] {
    @parser.ArithmeticToken::Operator(op) => Some(op)
    _ => None
  }
}

///|
fn arithmetic_next_operator(
  tokens : Array[@parser.ArithmeticToken],
  index : Int,
) -> String? {
  if index + 1 >= tokens.length() {
    return None
  }
  match tokens[index + 1] {
    @parser.ArithmeticToken::Operator(op) => Some(op)
    _ => None
  }
}

///|
fn arithmetic_written_value(indexes : Array[@parser.ArrayIndex]) -> CfgValue {
  if indexes.length() > 0 {
    CfgValue::Array
  } else {
    CfgValue::Integer
  }
}

///|
fn is_arithmetic_incdec_operator(op : String) -> Bool {
  op == "++" || op == "--"
}

///|
fn is_arithmetic_write_operator(op : String) -> Bool {
  is_arithmetic_incdec_operator(op) ||
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
  op == "|="
}

///|
fn redirection_closes_named_fd(redirect : @parser.Redirection) -> Bool {
  match redirect.op {
    @parser.RedirectionOperator::DupInput
    | @parser.RedirectionOperator::DupOutput =>
      match redirect.target {
        @parser.RedirectionTarget::Word(word) =>
          @semantics.literal_text(word) == Some("-")
        _ => false
      }
    _ => false
  }
}

///|
fn compute_post_dominators_inner(cfg : CFG) -> Array[Array[CfgNodeId]] {
  let all_nodes = all_cfg_node_ids(cfg)
  let current : Array[Array[CfgNodeId]] = []
  for node in all_nodes {
    if node == cfg.main_exit {
      current.push([cfg.main_exit])
    } else {
      current.push(copy_node_ids(all_nodes))
    }
  }
  let mut changed = true
  while changed {
    changed = false
    for node in all_nodes {
      if node == cfg.main_exit {
        continue
      }
      let successors = postdom_successors(cfg, node)
      let next = postdom_for_node(
        node,
        successors,
        current,
        all_nodes,
        cfg.main_exit,
      )
      if !same_node_id_arrays(current[node.to_int()], next) {
        current[node.to_int()] = next
        changed = true
      }
    }
  }
  current
}

///|
fn postdom_for_node(
  node : CfgNodeId,
  successors : Array[CfgNodeId],
  current : Array[Array[CfgNodeId]],
  all_nodes : Array[CfgNodeId],
  main_exit : CfgNodeId,
) -> Array[CfgNodeId] {
  let next : Array[CfgNodeId] = [node]
  let actual_successors = if successors.length() == 0 {
    [main_exit]
  } else {
    successors
  }
  for candidate in all_nodes {
    let mut in_all = true
    for successor in actual_successors {
      if !contains_node_id(current[successor.to_int()], candidate) {
        in_all = false
        break
      }
    }
    if in_all && candidate != node {
      next.push(candidate)
    }
  }
  next
}

///|
fn postdom_successors(cfg : CFG, node : CfgNodeId) -> Array[CfgNodeId] {
  let normal = real_successors(cfg, node)
  match node_at(cfg, node) {
    Some({ kind: CfgNodeKind::ExecuteSubshell(_, start, _), .. }) => [start]
    _ =>
      match subshell_execute_for_end(cfg, node) {
        Some(execute) => real_successors(cfg, execute)
        None =>
          if normal.length() == 0 && node != cfg.main_exit {
            [cfg.main_exit]
          } else {
            normal
          }
      }
  }
}

///|
fn subshell_execute_for_end(cfg : CFG, node : CfgNodeId) -> CfgNodeId? {
  for current in cfg.nodes {
    match current.kind {
      CfgNodeKind::ExecuteSubshell(_, _, end) if end == node =>
        return Some(current.id)
      _ => ()
    }
  }
  None
}

///|
fn real_successors(cfg : CFG, node : CfgNodeId) -> Array[CfgNodeId] {
  let successors : Array[CfgNodeId] = []
  for edge in cfg.graph_edges {
    if edge.from == node &&
      (edge.kind == CfgEdgeKind::Flow || edge.kind == CfgEdgeKind::Exit) {
      successors.push(edge.to)
    }
  }
  successors
}

///|
fn all_cfg_node_ids(cfg : CFG) -> Array[CfgNodeId] {
  let ids : Array[CfgNodeId] = []
  for node in cfg.nodes {
    ids.push(node.id)
  }
  ids
}

///|
fn same_node_id_arrays(lhs : Array[CfgNodeId], rhs : Array[CfgNodeId]) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  let mut i = 0
  while i < lhs.length() {
    if lhs[i] != rhs[i] {
      return false
    }
    i += 1
  }
  true
}
