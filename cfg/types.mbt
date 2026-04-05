///|
/// Identifier for an AST node tracked by the CFG layer.
pub struct CfgAstId {
  priv value : Int
} derive(Eq, Compare, Hash, Debug)

///|
/// Returns the raw integer value of a CFG AST id.
pub fn CfgAstId::to_int(self : CfgAstId) -> Int {
  self.value
}

///|
/// Identifier for a graph node in the lowered control-flow graph.
pub struct CfgNodeId {
  priv value : Int
} derive(Eq, Compare, Hash, Debug)

///|
/// Returns the raw integer value of a CFG node id.
pub fn CfgNodeId::to_int(self : CfgNodeId) -> Int {
  self.value
}

///|
/// Variable properties tracked by CFG dataflow.
pub enum CfgVariableProp {
  Export
  Array
  Associative
  Integer
} derive(Eq, Debug)

///|
/// Scope used when a CFG effect reads or writes a variable.
pub enum CfgScope {
  Global
  Local
  Prefix
} derive(Eq, Debug)

///|
/// A coarse-grained model of string content derived during dataflow.
pub enum CfgStringPart {
  Literal(String)
  Variable(String)
  Integer
  Unknown
} derive(Eq, Debug)

///|
/// The abstract value domain used by CFG effects.
pub(all) enum CfgValue {
  Uninitialized
  Array
  String
  Integer
  Computed(CfgAstId, Array[CfgStringPart])
} derive(Eq, Debug)

///|
/// A side effect attached to a CFG node.
pub enum CfgEffect {
  SetProps(CfgScope?, String, Array[CfgVariableProp])
  UnsetProps(CfgScope?, String, Array[CfgVariableProp])
  ReadVariable(String)
  WriteVariable(String, CfgValue)
  WriteGlobal(String, CfgValue)
  WriteLocal(String, CfgValue)
  WritePrefix(String, CfgValue)
  DefineFunction(String, CfgAstId, CfgNodeId, CfgNodeId)
  Undefine(String)
  UndefineVariable(String)
  UndefineFunction(String)
  UndefineNameref(String)
  HintArray(String)
  HintDefined(String)
} derive(Eq, Debug)

///|
/// Associates one effect with the AST node that produced it.
pub struct CfgTaggedEffect {
  ast_id : CfgAstId
  effect : CfgEffect
} derive(Eq, Debug)

///|
/// Kinds of nodes that may appear in the lowered control-flow graph.
pub enum CfgNodeKind {
  Structural
  EntryPoint(String)
  DropPrefixAssignments
  ApplyEffects(Array[CfgTaggedEffect])
  ExecuteCommand(String?)
  ExecuteSubshell(String, CfgNodeId, CfgNodeId)
  SetExitCode(CfgAstId)
  ImpliedExit
  ResolvedExit
  UnresolvedExit
  Unreachable
  SetBackgroundPid(CfgAstId)
} derive(Eq, Debug)

///|
/// A single node in the control-flow graph.
pub struct CfgNode {
  id : CfgNodeId
  kind : CfgNodeKind
} derive(Eq, Debug)

///|
/// The meaning of a directed CFG edge.
pub enum CfgEdgeKind {
  Flow
  FalseFlow
  Exit
} derive(Eq, Debug)

///|
/// A directed edge in the control-flow graph.
pub struct CfgEdge {
  from : CfgNodeId
  to : CfgNodeId
  kind : CfgEdgeKind
} derive(Eq, Debug)

///|
/// Build-time switches that affect how pipelines are lowered into CFG nodes.
pub struct CfgParameters {
  lastpipe : Bool
  pipefail : Bool
} derive(Eq, Debug)

///|
/// Constructs CFG lowering parameters.
pub fn CfgParameters::new(lastpipe : Bool, pipefail : Bool) -> CfgParameters {
  { lastpipe, pipefail }
}
