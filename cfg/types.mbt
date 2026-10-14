///|
/// Identifier for an AST node tracked by the CFG layer.
pub struct CfgAstId {
  priv value : Int32
} derive(Eq, Compare, Hash, Debug)

///|
#deprecated
#doc(hidden)
pub extend CfgAstId with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgAstId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated
#doc(hidden)
pub extend CfgAstId with Hash::{hash, hash_combine}

///|
#deprecated
#doc(hidden)
pub extend CfgAstId with Debug::{to_repr}

///|
/// Returns the raw integer value of a CFG AST id.
pub fn CfgAstId::to_int(self : CfgAstId) -> Int32 {
  self.value
}

///|
/// Identifier for a graph node in the lowered control-flow graph.
pub struct CfgNodeId {
  priv value : Int32
} derive(Eq, Compare, Hash, Debug)

///|
#deprecated
#doc(hidden)
pub extend CfgNodeId with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgNodeId with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated
#doc(hidden)
pub extend CfgNodeId with Hash::{hash, hash_combine}

///|
#deprecated
#doc(hidden)
pub extend CfgNodeId with Debug::{to_repr}

///|
/// Returns the raw integer value of a CFG node id.
pub fn CfgNodeId::to_int(self : CfgNodeId) -> Int32 {
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
#deprecated
#doc(hidden)
pub extend CfgVariableProp with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgVariableProp with Debug::{to_repr}

///|
/// Scope used when a CFG effect reads or writes a variable.
pub enum CfgScope {
  Global
  Local
  Prefix
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CfgScope with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgScope with Debug::{to_repr}

///|
/// A coarse-grained model of string content derived during dataflow.
pub enum CfgStringPart {
  Literal(String)
  Variable(String)
  Integer
  Unknown
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CfgStringPart with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgStringPart with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend CfgValue with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgValue with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend CfgEffect with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgEffect with Debug::{to_repr}

///|
/// Associates one effect with the AST node that produced it.
pub struct CfgTaggedEffect {
  ast_id : CfgAstId
  effect : CfgEffect
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CfgTaggedEffect with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgTaggedEffect with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend CfgNodeKind with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgNodeKind with Debug::{to_repr}

///|
/// A single node in the control-flow graph.
pub struct CfgNode {
  id : CfgNodeId
  kind : CfgNodeKind
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CfgNode with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgNode with Debug::{to_repr}

///|
/// The meaning of a directed CFG edge.
pub enum CfgEdgeKind {
  Flow
  FalseFlow
  Exit
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CfgEdgeKind with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgEdgeKind with Debug::{to_repr}

///|
/// A directed edge in the control-flow graph.
pub struct CfgEdge {
  from : CfgNodeId
  to : CfgNodeId
  kind : CfgEdgeKind
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CfgEdge with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgEdge with Debug::{to_repr}

///|
/// Build-time switches that affect how pipelines are lowered into CFG nodes.
pub struct CfgParameters {
  lastpipe : Bool
  pipefail : Bool
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CfgParameters with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CfgParameters with Debug::{to_repr}

///|
/// Constructs CFG lowering parameters.
pub fn CfgParameters::new(lastpipe : Bool, pipefail : Bool) -> CfgParameters {
  { lastpipe, pipefail, }
}
