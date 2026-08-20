///|
/// Identifier for a node in an `IndexedScript`.
pub struct NodeId {
  priv value : Int
} derive(Eq, Compare, Hash, Debug)

///|
/// Returns the raw integer value of a node id.
pub fn NodeId::to_int(self : NodeId) -> Int {
  self.value
}

///|
/// The categories of parser nodes indexed by `IndexedScript`.
pub enum NodeKind {
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
/// A tagged reference to one concrete parser node.
pub enum NodeRef {
  Script(@parser.Script)
  Annotation(@parser.Annotation)
  ListItem(@parser.ListItem)
  AndOrList(@parser.AndOrList)
  Pipeline(@parser.Pipeline)
  PipelineSegment(@parser.PipelineSegment)
  Command(@parser.Command)
  SimpleCommand(@parser.SimpleCommand)
  SourceCommand(@parser.SourceCommand)
  ArithmeticExpr(@parser.ArithmeticExpr)
  ArithmeticToken(@parser.ArithmeticToken)
  ArrayIndex(@parser.ArrayIndex)
  TimeClause(@parser.TimeClause)
  Assignment(@parser.Assignment)
  ArrayElement(@parser.ArrayElement)
  IfClause(@parser.IfClause)
  IfArm(@parser.IfArm)
  LoopClause(@parser.LoopClause)
  ForClause(@parser.ForClause)
  ArithmeticForClause(@parser.ArithmeticForClause)
  SelectClause(@parser.SelectClause)
  CaseClause(@parser.CaseClause)
  CaseItem(@parser.CaseItem)
  ConditionCommand(@parser.ConditionCommand)
  ConditionExpr(@parser.ConditionExpr)
  ArithmeticCommand(@parser.ArithmeticCommand)
  CoProcClause(@parser.CoProcClause)
  BatsTestClause(@parser.BatsTestClause)
  FunctionDef(@parser.FunctionDef)
  Redirection(@parser.Redirection)
  HereDoc(@parser.HereDoc)
  ExtGlobPattern(@parser.ExtGlobPattern)
  BraceExpansion(@parser.BraceExpansion)
  Word(@parser.Word)
  WordPart(@parser.WordPart)
  ParameterExpansion(@parser.ParameterExpansion)
} derive(Eq, Debug)

///|
/// Returns the `NodeKind` corresponding to a `NodeRef`.
pub fn NodeRef::kind(self : NodeRef) -> NodeKind {
  match self {
    Script(_) => Script
    Annotation(_) => Annotation
    ListItem(_) => ListItem
    AndOrList(_) => AndOrList
    Pipeline(_) => Pipeline
    PipelineSegment(_) => PipelineSegment
    Command(_) => Command
    SimpleCommand(_) => SimpleCommand
    SourceCommand(_) => SourceCommand
    ArithmeticExpr(_) => ArithmeticExpr
    ArithmeticToken(_) => ArithmeticToken
    ArrayIndex(_) => ArrayIndex
    TimeClause(_) => TimeClause
    Assignment(_) => Assignment
    ArrayElement(_) => ArrayElement
    IfClause(_) => IfClause
    IfArm(_) => IfArm
    LoopClause(_) => LoopClause
    ForClause(_) => ForClause
    ArithmeticForClause(_) => ArithmeticForClause
    SelectClause(_) => SelectClause
    CaseClause(_) => CaseClause
    CaseItem(_) => CaseItem
    ConditionCommand(_) => ConditionCommand
    ConditionExpr(_) => ConditionExpr
    ArithmeticCommand(_) => ArithmeticCommand
    CoProcClause(_) => CoProcClause
    BatsTestClause(_) => BatsTestClause
    FunctionDef(_) => FunctionDef
    Redirection(_) => Redirection
    HereDoc(_) => HereDoc
    ExtGlobPattern(_) => ExtGlobPattern
    BraceExpansion(_) => BraceExpansion
    Word(_) => Word
    WordPart(_) => WordPart
    ParameterExpansion(_) => ParameterExpansion
  }
}

///|
priv struct IndexedNode {
  id : NodeId
  kind : NodeKind
  span : @parser.Span?
  enclosing_span : @parser.Span
  parent : NodeId?
  children : Array[NodeId]
  node : NodeRef
} derive(Eq, Debug)

///|
/// A parser script augmented with parent/child links and stable node ids.
pub struct IndexedScript {
  priv script : @parser.Script
  priv root : NodeId
  priv nodes : Array[IndexedNode]
} derive(Eq, Debug)

///|
fn node_id(value : Int) -> NodeId {
  { value, }
}

///|
fn IndexedScript::node_at(self : IndexedScript, id : NodeId) -> IndexedNode? {
  self.nodes.get(id.value)
}

///|
fn NodeRef::exact_command(self : NodeRef) -> @parser.Command? {
  match self {
    Command(command) => Some(command)
    _ => None
  }
}

///|
fn NodeRef::exact_word(self : NodeRef) -> @parser.Word? {
  match self {
    Word(word) => Some(word)
    _ => None
  }
}

///|
/// Builds an index over a parsed script for fast structural queries.
pub fn build_index(script : @parser.Script) -> IndexedScript {
  let builder = IndexBuilder::new()
  let root = builder.visit_script(script)
  { script, root, nodes: builder.nodes }
}

///|
/// Returns the id of the indexed script root node.
pub fn root_id(indexed : IndexedScript) -> NodeId {
  indexed.root
}

///|
/// Returns the total number of indexed nodes.
pub fn node_count(indexed : IndexedScript) -> Int {
  indexed.nodes.length()
}

///|
/// Returns the indexed parser node associated with an id.
pub fn node_ref_of(indexed : IndexedScript, id : NodeId) -> NodeRef? {
  if indexed.node_at(id) is Some(node) {
    Some(node.node)
  } else {
    None
  }
}

///|
/// Returns the kind of node stored at an id.
pub fn node_kind_of(indexed : IndexedScript, id : NodeId) -> NodeKind? {
  if indexed.node_at(id) is Some(node) {
    Some(node.kind)
  } else {
    None
  }
}

///|
/// Returns the exact span of a node when one exists.
pub fn span_of(indexed : IndexedScript, id : NodeId) -> @parser.Span? {
  if indexed.node_at(id) is Some(node) {
    node.span
  } else {
    None
  }
}

///|
/// Returns the enclosing span used when a node has no exact span of its own.
pub fn enclosing_span_of(indexed : IndexedScript, id : NodeId) -> @parser.Span? {
  if indexed.node_at(id) is Some(node) {
    Some(node.enclosing_span)
  } else {
    None
  }
}

///|
/// Returns `span_of` when available, otherwise the enclosing span.
pub fn effective_span_of(indexed : IndexedScript, id : NodeId) -> @parser.Span? {
  if span_of(indexed, id) is Some(span) {
    Some(span)
  } else {
    enclosing_span_of(indexed, id)
  }
}

///|
/// Returns the parent id of a node.
pub fn parent_of(indexed : IndexedScript, id : NodeId) -> NodeId? {
  if indexed.node_at(id) is Some(node) {
    node.parent
  } else {
    None
  }
}

///|
/// Returns the immediate child ids of a node.
pub fn children_of(indexed : IndexedScript, id : NodeId) -> Array[NodeId] {
  if indexed.node_at(id) is Some(node) {
    copy_node_ids(node.children)
  } else {
    []
  }
}

///|
/// Returns all ancestors of a node, closest parent first.
pub fn find_ancestors(indexed : IndexedScript, id : NodeId) -> Array[NodeId] {
  let ancestors = []
  collect_ancestors(indexed, id, ancestors)
  ancestors
}

///|
fn collect_ancestors(
  indexed : IndexedScript,
  id : NodeId,
  ancestors : Array[NodeId],
) -> Unit {
  if parent_of(indexed, id) is Some(parent) {
    ancestors.push(parent)
    collect_ancestors(indexed, parent, ancestors)
  }
}

///|
/// Returns all descendants of a node in traversal order.
pub fn find_descendants(indexed : IndexedScript, id : NodeId) -> Array[NodeId] {
  let descendants = []
  collect_descendants(indexed, id, descendants)
  descendants
}

///|
fn collect_descendants(
  indexed : IndexedScript,
  id : NodeId,
  descendants : Array[NodeId],
) -> Unit {
  for child in children_of(indexed, id) {
    descendants.push(child)
    collect_descendants(indexed, child, descendants)
  }
}

///|
fn copy_node_ids(ids : Array[NodeId]) -> Array[NodeId] {
  let copied : Array[NodeId] = []
  for id in ids {
    copied.push(id)
  }
  copied
}

///|
/// Walks up the index until it finds the enclosing command node.
pub fn command_of(indexed : IndexedScript, id : NodeId) -> @parser.Command? {
  find_command(indexed, Some(id))
}

///|
fn find_command(indexed : IndexedScript, current : NodeId?) -> @parser.Command? {
  if current is Some(current) {
    if node_ref_of(indexed, current) is Some(node) {
      if node.exact_command() is Some(command) {
        Some(command)
      } else {
        find_command(indexed, parent_of(indexed, current))
      }
    } else {
      None
    }
  } else {
    None
  }
}

///|
/// Walks up the index until it finds the enclosing word node.
pub fn word_of(indexed : IndexedScript, id : NodeId) -> @parser.Word? {
  find_word(indexed, Some(id))
}

///|
fn find_word(indexed : IndexedScript, current : NodeId?) -> @parser.Word? {
  if current is Some(current) {
    if node_ref_of(indexed, current) is Some(node) {
      if node.exact_word() is Some(word) {
        Some(word)
      } else {
        find_word(indexed, parent_of(indexed, current))
      }
    } else {
      None
    }
  } else {
    None
  }
}

///|
priv struct IndexBuilder {
  nodes : Array[IndexedNode]
  stack : Array[NodeId]
}

///|
// CHECK THIS: THUNK
fn IndexBuilder::new() -> IndexBuilder {
  { nodes: [], stack: [] }
}

///|
fn IndexBuilder::start_node(
  self : IndexBuilder,
  node : NodeRef,
  enclosing_span : @parser.Span,
  span : @parser.Span?,
) -> NodeId {
  let id = node_id(self.nodes.length())
  let kind = node.kind()
  let parent = self.stack.last()
  self.nodes.push({ id, kind, span, enclosing_span, parent, children: [], node })
  if parent is Some(parent) {
    self.add_child(parent, id)
  }
  self.stack.push(id)
  id
}

///|
fn IndexBuilder::finish_node(self : IndexBuilder) -> Unit {
  let _ = self.stack.pop()
}

///|
fn IndexBuilder::add_child(
  self : IndexBuilder,
  parent : NodeId,
  child : NodeId,
) -> Unit {
  if self.nodes.get(parent.value) is Some(node) {
    let updated = node
    updated.children.push(child)
    self.nodes[parent.value] = updated
  } else {
    panic()
  }
}

///|
fn IndexBuilder::visit_script(
  self : IndexBuilder,
  script : @parser.Script,
) -> NodeId {
  let id = self.start_node(Script(script), script.span, Some(script.span))
  for annotation in script.annotations {
    let _ = self.visit_annotation(annotation, script.span)
  }
  for item in script.items {
    let _ = self.visit_list_item(item)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_annotation(
  self : IndexBuilder,
  annotation : @parser.Annotation,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(Annotation(annotation), fallback_span, None)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_list_item(
  self : IndexBuilder,
  item : @parser.ListItem,
) -> NodeId {
  let id = self.start_node(ListItem(item), item.span, Some(item.span))
  for annotation in item.annotations {
    let _ = self.visit_annotation(annotation, item.span)
  }
  let _ = self.visit_and_or_list(item.and_or)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_and_or_list(
  self : IndexBuilder,
  list : @parser.AndOrList,
) -> NodeId {
  let id = self.start_node(AndOrList(list), list.span, Some(list.span))
  let _ = self.visit_pipeline(list.head)
  for pair in list.tail {
    let (_, pipeline) = pair
    let _ = self.visit_pipeline(pipeline)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_pipeline(
  self : IndexBuilder,
  pipeline : @parser.Pipeline,
) -> NodeId {
  let id = self.start_node(
    Pipeline(pipeline),
    pipeline.span,
    Some(pipeline.span),
  )
  for segment in pipeline.segments {
    let _ = self.visit_pipeline_segment(segment)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_pipeline_segment(
  self : IndexBuilder,
  segment : @parser.PipelineSegment,
) -> NodeId {
  let id = self.start_node(
    PipelineSegment(segment),
    segment.span,
    Some(segment.span),
  )
  let _ = self.visit_command(segment.command)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_command(
  self : IndexBuilder,
  command : @parser.Command,
) -> NodeId {
  let id = self.start_node(Command(command), command.span, Some(command.span))
  self.visit_command_kind(command.kind, command.span)
  for redirect in command.redirects {
    let _ = self.visit_redirection(redirect)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_command_kind(
  self : IndexBuilder,
  kind : @parser.CommandKind,
  fallback_span : @parser.Span,
) -> Unit {
  match kind {
    Simple(simple) => {
      let _ = self.visit_simple_command(simple, fallback_span)
    }
    Source(source) => {
      let _ = self.visit_source_command(source, fallback_span)
    }
    Time(clause) => {
      let _ = self.visit_time_clause(clause, fallback_span)
    }
    Subshell(script) => {
      let _ = self.visit_script(script)
    }
    BraceGroup(script) => {
      let _ = self.visit_script(script)
    }
    If(clause) => {
      let _ = self.visit_if_clause(clause, fallback_span)
    }
    While(clause) => {
      let _ = self.visit_loop_clause(clause, fallback_span)
    }
    Until(clause) => {
      let _ = self.visit_loop_clause(clause, fallback_span)
    }
    ForIn(clause) => {
      let _ = self.visit_for_clause(clause, fallback_span)
    }
    ForArithmetic(clause) => {
      let _ = self.visit_arithmetic_for_clause(clause, fallback_span)
    }
    Select(clause) => {
      let _ = self.visit_select_clause(clause, fallback_span)
    }
    Case(clause) => {
      let _ = self.visit_case_clause(clause, fallback_span)
    }
    Condition(condition) => {
      let _ = self.visit_condition_command(condition, fallback_span)
    }
    Arithmetic(command) => {
      let _ = self.visit_arithmetic_command(command, fallback_span)
    }
    Function(function_def) => {
      let _ = self.visit_function_def(function_def, fallback_span)
    }
    CoProc(clause) => {
      let _ = self.visit_co_proc_clause(clause, fallback_span)
    }
    BatsTest(clause) => {
      let _ = self.visit_bats_test_clause(clause, fallback_span)
    }
  }
}

///|
fn IndexBuilder::visit_simple_command(
  self : IndexBuilder,
  simple : @parser.SimpleCommand,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(SimpleCommand(simple), fallback_span, None)
  for assignment in simple.assignments {
    let _ = self.visit_assignment(assignment)
  }
  for word in simple.words {
    let _ = self.visit_word(word)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_source_command(
  self : IndexBuilder,
  source : @parser.SourceCommand,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(SourceCommand(source), fallback_span, None)
  for assignment in source.assignments {
    let _ = self.visit_assignment(assignment)
  }
  for option in source.options {
    let _ = self.visit_word(option)
  }
  let _ = self.visit_word(source.path)
  for arg in source.args {
    let _ = self.visit_word(arg)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_time_clause(
  self : IndexBuilder,
  clause : @parser.TimeClause,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(TimeClause(clause), fallback_span, None)
  for flag in clause.flags {
    let _ = self.visit_word(flag)
  }
  let _ = self.visit_pipeline(clause.body)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_assignment(
  self : IndexBuilder,
  assignment : @parser.Assignment,
) -> NodeId {
  let id = self.start_node(
    Assignment(assignment),
    assignment.span,
    Some(assignment.span),
  )
  for index in assignment.indexes {
    let _ = self.visit_array_index(index, assignment.span)
  }
  self.visit_assignment_value(assignment.value, assignment.span)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_assignment_value(
  self : IndexBuilder,
  value : @parser.AssignmentValue,
  fallback_span : @parser.Span,
) -> Unit {
  match value {
    Empty => ()
    Word(word) => {
      let _ = self.visit_word(word)
    }
    ArrayLiteral(elements) =>
      for element in elements {
        let _ = self.visit_array_element(element, fallback_span)
      }
  }
}

///|
fn IndexBuilder::visit_array_element(
  self : IndexBuilder,
  element : @parser.ArrayElement,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(ArrayElement(element), fallback_span, None)
  for index in element.indexes {
    let _ = self.visit_array_index(index, fallback_span)
  }
  self.visit_assignment_value(element.value, fallback_span)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_if_clause(
  self : IndexBuilder,
  clause : @parser.IfClause,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(IfClause(clause), fallback_span, None)
  for arm in clause.arms {
    let _ = self.visit_if_arm(arm, fallback_span)
  }
  if clause.else_body is Some(script) {
    let _ = self.visit_script(script)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_if_arm(
  self : IndexBuilder,
  arm : @parser.IfArm,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(IfArm(arm), fallback_span, None)
  let _ = self.visit_script(arm.condition)
  let _ = self.visit_script(arm.body)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_loop_clause(
  self : IndexBuilder,
  clause : @parser.LoopClause,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(LoopClause(clause), fallback_span, None)
  let _ = self.visit_script(clause.condition)
  let _ = self.visit_script(clause.body)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_for_clause(
  self : IndexBuilder,
  clause : @parser.ForClause,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(ForClause(clause), fallback_span, None)
  for value in clause.values {
    let _ = self.visit_word(value)
  }
  let _ = self.visit_script(clause.body)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_arithmetic_for_clause(
  self : IndexBuilder,
  clause : @parser.ArithmeticForClause,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(ArithmeticForClause(clause), fallback_span, None)
  let _ = self.visit_arithmetic_expr(clause.init, fallback_span)
  let _ = self.visit_arithmetic_expr(clause.condition, fallback_span)
  let _ = self.visit_arithmetic_expr(clause.step, fallback_span)
  let _ = self.visit_script(clause.body)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_select_clause(
  self : IndexBuilder,
  clause : @parser.SelectClause,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(SelectClause(clause), fallback_span, None)
  for value in clause.values {
    let _ = self.visit_word(value)
  }
  let _ = self.visit_script(clause.body)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_case_clause(
  self : IndexBuilder,
  clause : @parser.CaseClause,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(CaseClause(clause), fallback_span, None)
  let _ = self.visit_word(clause.word)
  for item in clause.items {
    let _ = self.visit_case_item(item, fallback_span)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_case_item(
  self : IndexBuilder,
  item : @parser.CaseItem,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(CaseItem(item), fallback_span, None)
  for pattern in item.patterns {
    let _ = self.visit_word(pattern)
  }
  let _ = self.visit_script(item.body)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_condition_command(
  self : IndexBuilder,
  condition : @parser.ConditionCommand,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(ConditionCommand(condition), fallback_span, None)
  let _ = self.visit_condition_expr(condition.expr, fallback_span)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_condition_expr(
  self : IndexBuilder,
  expr : @parser.ConditionExpr,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(ConditionExpr(expr), fallback_span, None)
  match expr {
    Empty => ()
    Word(word) => {
      let _ = self.visit_word(word)
    }
    Unary(_, _, word) => {
      let _ = self.visit_word(word)
    }
    Binary(_, _, lhs, rhs) => {
      let _ = self.visit_word(lhs)
      let _ = self.visit_word(rhs)
    }
    Group(inner) => {
      let _ = self.visit_condition_expr(inner, fallback_span)
    }
    Not(inner) => {
      let _ = self.visit_condition_expr(inner, fallback_span)
    }
    And(_, lhs, rhs) => {
      let _ = self.visit_condition_expr(lhs, fallback_span)
      let _ = self.visit_condition_expr(rhs, fallback_span)
    }
    Or(_, lhs, rhs) => {
      let _ = self.visit_condition_expr(lhs, fallback_span)
      let _ = self.visit_condition_expr(rhs, fallback_span)
    }
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_arithmetic_command(
  self : IndexBuilder,
  command : @parser.ArithmeticCommand,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(ArithmeticCommand(command), fallback_span, None)
  let _ = self.visit_arithmetic_expr(command.expr, fallback_span)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_co_proc_clause(
  self : IndexBuilder,
  clause : @parser.CoProcClause,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(CoProcClause(clause), fallback_span, None)
  if clause.name is Some(name) {
    let _ = self.visit_word(name)
  }
  let _ = self.visit_command(clause.body)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_bats_test_clause(
  self : IndexBuilder,
  clause : @parser.BatsTestClause,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(BatsTestClause(clause), fallback_span, None)
  let _ = self.visit_script(clause.body)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_function_def(
  self : IndexBuilder,
  function_def : @parser.FunctionDef,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(FunctionDef(function_def), fallback_span, None)
  let _ = self.visit_command(function_def.body)
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_redirection(
  self : IndexBuilder,
  redirect : @parser.Redirection,
) -> NodeId {
  let id = self.start_node(
    Redirection(redirect),
    redirect.span,
    Some(redirect.span),
  )
  match redirect.target {
    Word(word) => {
      let _ = self.visit_word(word)
    }
    HereDoc(doc) => {
      let _ = self.visit_here_doc(doc, redirect.span)
    }
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_here_doc(
  self : IndexBuilder,
  doc : @parser.HereDoc,
  fallback_span : @parser.Span,
) -> NodeId {
  let id = self.start_node(HereDoc(doc), fallback_span, None)
  if doc.parts is Some(parts) {
    for part in parts {
      let _ = self.visit_word_part(part, fallback_span)
    }
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_word(self : IndexBuilder, word : @parser.Word) -> NodeId {
  self.visit_word_with_mode(word, word.span, true)
}

///|
fn IndexBuilder::visit_word_with_mode(
  self : IndexBuilder,
  word : @parser.Word,
  fallback_span : @parser.Span,
  exact_spans : Bool,
) -> NodeId {
  let enclosing_span = if exact_spans { word.span } else { fallback_span }
  let id = self.start_node(
    Word(word),
    enclosing_span,
    if exact_spans {
      Some(word.span)
    } else {
      None
    },
  )
  for part in word.parts {
    let _ = self.visit_word_part_with_mode(part, enclosing_span, exact_spans)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_word_part(
  self : IndexBuilder,
  part : @parser.WordPart,
  fallback_span : @parser.Span,
) -> NodeId {
  self.visit_word_part_with_mode(part, fallback_span, true)
}

///|
fn IndexBuilder::visit_word_part_with_mode(
  self : IndexBuilder,
  part : @parser.WordPart,
  fallback_span : @parser.Span,
  exact_spans : Bool,
) -> NodeId {
  let id = self.start_node(WordPart(part), fallback_span, None)
  match part {
    Literal(_) => ()
    SingleQuoted(_) => ()
    DoubleQuoted(parts) =>
      for part in parts {
        let _ = self.visit_word_part_with_mode(part, fallback_span, exact_spans)
      }
    DollarDoubleQuoted(parts) =>
      for part in parts {
        let _ = self.visit_word_part_with_mode(part, fallback_span, exact_spans)
      }
    DollarSingleQuoted(_) => ()
    Parameter(_) => ()
    SpecialParameter(_) => ()
    BracedParameter(expansion) => {
      let _ = if exact_spans {
        self.visit_parameter_expansion(expansion, fallback_span)
      } else {
        self.visit_parameter_expansion_with_mode(
          expansion, fallback_span, exact_spans,
        )
      }
    }
    BraceCommandSubstitution(_, script) => {
      let _ = self.visit_script(script)
    }
    CommandSubstitution(script) => {
      let _ = self.visit_script(script)
    }
    BackQuoted(script) => {
      let _ = self.visit_script(script)
    }
    ArithmeticExpansion(expr) => {
      let _ = if exact_spans {
        self.visit_arithmetic_expr(expr, fallback_span)
      } else {
        self.visit_arithmetic_expr_with_mode(expr, fallback_span, exact_spans)
      }
    }
    DollarBracket(expr) => {
      let _ = if exact_spans {
        self.visit_arithmetic_expr(expr, fallback_span)
      } else {
        self.visit_arithmetic_expr_with_mode(expr, fallback_span, exact_spans)
      }
    }
    ExtGlob(pattern) => {
      let _ = if exact_spans {
        self.visit_extglob_pattern(pattern, fallback_span)
      } else {
        self.visit_extglob_pattern_with_mode(
          pattern, fallback_span, exact_spans,
        )
      }
    }
    ProcessSubstitution(_, script) => {
      let _ = self.visit_script(script)
    }
    BraceExpansion(expansion) => {
      let _ = if exact_spans {
        self.visit_brace_expansion(expansion, fallback_span)
      } else {
        self.visit_brace_expansion_with_mode(
          expansion, fallback_span, exact_spans,
        )
      }
    }
    Glob(_) => ()
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_parameter_expansion(
  self : IndexBuilder,
  expansion : @parser.ParameterExpansion,
  fallback_span : @parser.Span,
) -> NodeId {
  self.visit_parameter_expansion_with_mode(expansion, fallback_span, true)
}

///|
fn IndexBuilder::visit_parameter_expansion_with_mode(
  self : IndexBuilder,
  expansion : @parser.ParameterExpansion,
  fallback_span : @parser.Span,
  exact_spans : Bool,
) -> NodeId {
  let id = self.start_node(ParameterExpansion(expansion), fallback_span, None)
  if expansion.index is Some(index) {
    let _ = self.visit_array_index_with_mode(index, fallback_span, exact_spans)
  }
  if exact_spans {
    self.visit_parameter_operator(expansion.operator, fallback_span)
  } else {
    self.visit_parameter_operator_with_mode(expansion.operator, fallback_span)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_parameter_operator(
  self : IndexBuilder,
  operator : @parser.ParameterOperator?,
  fallback_span : @parser.Span,
) -> Unit {
  self.visit_parameter_operator_with_mode(operator, fallback_span)
}

///|
fn IndexBuilder::visit_parameter_operator_with_mode(
  self : IndexBuilder,
  operator : @parser.ParameterOperator?,
  fallback_span : @parser.Span,
) -> Unit {
  match operator {
    Some(Slice(offset, length)) => {
      let _ = self.visit_arithmetic_expr_with_mode(
        @parser.parse_arithmetic_expr(offset),
        fallback_span,
        false,
      )
      if length is Some(length) {
        ignore(
          self.visit_arithmetic_expr_with_mode(
            @parser.parse_arithmetic_expr(length),
            fallback_span,
            false,
          ),
        )
      }
    }
    Some(Replace(_, pattern, replacement)) => {
      let _ = self.visit_word_with_mode(
        @parser.parse_text_as_word(pattern),
        fallback_span,
        false,
      )
      if replacement is Some(replacement) {
        ignore(
          self.visit_word_with_mode(
            @parser.parse_text_as_word(replacement),
            fallback_span,
            false,
          ),
        )
      }
    }
    Some(CaseModify(_, Some(pattern))) => {
      let _ = self.visit_word_with_mode(
        @parser.parse_text_as_word(pattern),
        fallback_span,
        false,
      )
    }
    Some(DefaultValue(text))
    | Some(AssignDefault(text))
    | Some(ErrorValue(text))
    | Some(AlternateValue(text))
    | Some(RemoveShortestPrefix(text))
    | Some(RemoveLongestPrefix(text))
    | Some(RemoveShortestSuffix(text))
    | Some(RemoveLongestSuffix(text))
    | Some(Transform(text))
    | Some(Raw(text)) => {
      let _ = self.visit_word_with_mode(
        @parser.parse_text_as_word(text),
        fallback_span,
        false,
      )
    }
    Some(Names(_)) | Some(CaseModify(_, None)) | None => ()
  }
}

///|
fn IndexBuilder::visit_extglob_pattern(
  self : IndexBuilder,
  pattern : @parser.ExtGlobPattern,
  fallback_span : @parser.Span,
) -> NodeId {
  self.visit_extglob_pattern_with_mode(pattern, fallback_span, true)
}

///|
fn IndexBuilder::visit_extglob_pattern_with_mode(
  self : IndexBuilder,
  pattern : @parser.ExtGlobPattern,
  fallback_span : @parser.Span,
  exact_spans : Bool,
) -> NodeId {
  let id = self.start_node(ExtGlobPattern(pattern), fallback_span, None)
  for alternative in pattern.alternatives {
    let _ = self.visit_word_with_mode(alternative, fallback_span, exact_spans)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_brace_expansion(
  self : IndexBuilder,
  expansion : @parser.BraceExpansion,
  fallback_span : @parser.Span,
) -> NodeId {
  self.visit_brace_expansion_with_mode(expansion, fallback_span, true)
}

///|
fn IndexBuilder::visit_brace_expansion_with_mode(
  self : IndexBuilder,
  expansion : @parser.BraceExpansion,
  fallback_span : @parser.Span,
  exact_spans : Bool,
) -> NodeId {
  let id = self.start_node(BraceExpansion(expansion), fallback_span, None)
  for element in expansion.elements {
    let _ = self.visit_word_with_mode(element, fallback_span, exact_spans)
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_array_index(
  self : IndexBuilder,
  index : @parser.ArrayIndex,
  fallback_span : @parser.Span,
) -> NodeId {
  self.visit_array_index_with_mode(index, fallback_span, true)
}

///|
fn IndexBuilder::visit_array_index_with_mode(
  self : IndexBuilder,
  index : @parser.ArrayIndex,
  fallback_span : @parser.Span,
  exact_spans : Bool,
) -> NodeId {
  let id = self.start_node(ArrayIndex(index), fallback_span, None)
  for part in index.parts {
    let _ = self.visit_word_part_with_mode(part, fallback_span, exact_spans)
  }
  if index.arithmetic is Some(expr) {
    let _ = self.visit_arithmetic_expr_with_mode(
      expr, fallback_span, exact_spans,
    )
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_arithmetic_expr(
  self : IndexBuilder,
  expr : @parser.ArithmeticExpr,
  fallback_span : @parser.Span,
) -> NodeId {
  self.visit_arithmetic_expr_with_mode(expr, fallback_span, true)
}

///|
fn IndexBuilder::visit_arithmetic_expr_with_mode(
  self : IndexBuilder,
  expr : @parser.ArithmeticExpr,
  fallback_span : @parser.Span,
  exact_spans : Bool,
) -> NodeId {
  let id = self.start_node(ArithmeticExpr(expr), fallback_span, None)
  for token in expr.tokens {
    let _ = if exact_spans {
      self.visit_arithmetic_token(token, fallback_span)
    } else {
      self.visit_arithmetic_token_with_mode(token, fallback_span, exact_spans)
    }
  }
  self.finish_node()
  id
}

///|
fn IndexBuilder::visit_arithmetic_token(
  self : IndexBuilder,
  token : @parser.ArithmeticToken,
  fallback_span : @parser.Span,
) -> NodeId {
  self.visit_arithmetic_token_with_mode(token, fallback_span, true)
}

///|
fn IndexBuilder::visit_arithmetic_token_with_mode(
  self : IndexBuilder,
  token : @parser.ArithmeticToken,
  fallback_span : @parser.Span,
  exact_spans : Bool,
) -> NodeId {
  let id = self.start_node(ArithmeticToken(token), fallback_span, None)
  match token {
    Literal(_) => ()
    Operator(_) => ()
    Variable(_, indexes) =>
      for index in indexes {
        let _ = self.visit_array_index_with_mode(
          index, fallback_span, exact_spans,
        )
      }
    Expansion(word) => {
      let _ = self.visit_word_with_mode(word, fallback_span, exact_spans)
    }
    Group(expr) => {
      let _ = self.visit_arithmetic_expr_with_mode(
        expr, fallback_span, exact_spans,
      )
    }
  }
  self.finish_node()
  id
}
