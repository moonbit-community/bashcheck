///|
/// Returns the abstract state flowing out of one CFG node.
fn outgoing_state_of_node(
  analysis : CfgAnalysis,
  node : CfgNodeId,
) -> ProgramState? {
  match node_state_at(analysis, node) {
    Some((_, outgoing)) => Some(outgoing)
    None => None
  }
}

///|
/// Returns the abstract state flowing out of the CFG range for one AST id.
fn outgoing_state_of_ast(
  analysis : CfgAnalysis,
  id : CfgAstId,
) -> ProgramState? {
  match id_to_range(analysis.cfg, id) {
    Some((_, end_)) => outgoing_state_of_node(analysis, end_)
    None => None
  }
}

///|
/// Returns a copy of all directed CFG edges.
fn edges(cfg : CFG) -> Array[CfgEdge] {
  copy_cfg_edges(cfg.graph_edges)
}
