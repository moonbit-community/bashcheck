# bashcheck/cfg

`cfg` lowers parsed shell scripts into a control-flow graph and computes
lightweight dataflow snapshots. It roughly corresponds to `ShellCheck.CFG`
plus the state queries used by `ShellCheck.CFGAnalysis`.

## Lower Parser AST Into A Control-Flow Graph

`build_cfg` is the entry point for CFG construction. It takes a parsed script
plus `CfgParameters` and produces a `CFG` whose public ids (`CfgAstId` and
`CfgNodeId`) let callers move between AST nodes, CFG nodes, spans, and edges.
Use `root_ast_id`, `ast_ref_of`, `node_kind_of`, `id_to_range`, `id_to_nodes`,
`node_of`, and `edges` when you need to explain how one parser node was lowered.

```mbt check
///|
test "doc cfg exposes the lowered graph and AST-to-node mapping" {
  let script = match @parser.parse_script("x=1\necho \"$x\"\n") {
    Ok(script) => script
    Err(err) => abort(err.to_string())
  }
  let cfg = @cfg.build_cfg(script, @cfg.CfgParameters::new(false, false))
  let root = @cfg.root_ast_id(cfg)
  let root_nodes = @cfg.id_to_nodes(cfg, root)

  assert_true(
    match @cfg.node_kind_of(cfg, root) {
      Some(@semantics.NodeKind::Script) => true
      _ => false
    },
  )
  assert_true(@cfg.ast_ref_of(cfg, root) is Some(@semantics.NodeRef::Script(_)))
  assert_true(@cfg.id_to_range(cfg, root) is Some(_))
  assert_true(root_nodes.length() > 0)
  assert_true(@cfg.node_of(cfg, root_nodes[0]) is Some(_))
  assert_true(@cfg.edges(cfg).length() > 0)
}
```

## Read Abstract Program State After Dataflow

`analyze_control_flow` derives a `CfgAnalysis` from the graph. The usual
consumer path is: find the AST or CFG node you care about, ask for
`incoming_state_of_node`, `outgoing_state_of_node`, `incoming_state_of_ast`, or
`outgoing_state_of_ast`, and then inspect `ProgramState`, `VariableState`, and
`VariableValue`. Convenience helpers such as `command_is_reachable`,
`variable_may_be_declared_integer`, `variable_may_be_assigned_integer`,
`variable_may_be_array`, and `variable_may_be_unset` cover the most common
queries.

```mbt check
///|
test "doc cfg exposes incoming and outgoing abstract state" {
  let script = match @parser.parse_script("x=1\necho \"$x\"\n") {
    Ok(script) => script
    Err(err) => abort(err.to_string())
  }
  let cfg = @cfg.build_cfg(script, @cfg.CfgParameters::new(false, false))
  let analysis = @cfg.analyze_control_flow(cfg)
  let root_nodes = @cfg.id_to_nodes(cfg, @cfg.root_ast_id(cfg))
  let mut echo_node : @cfg.CfgNodeId? = None
  for id in root_nodes {
    match @cfg.node_of(cfg, id) {
      Some({ kind: @cfg.CfgNodeKind::ExecuteCommand(Some("echo")), .. }) =>
        echo_node = Some(id)
      _ => ()
    }
  }
  let echo_node = match echo_node {
    Some(id) => id
    None => abort("expected execute node")
  }
  let incoming = match @cfg.incoming_state_of_node(analysis, echo_node) {
    Some(state) => state
    None => abort("expected incoming state")
  }
  let outgoing = match @cfg.outgoing_state_of_node(analysis, echo_node) {
    Some(state) => state
    None => abort("expected outgoing state")
  }

  assert_true(incoming.variables_in_scope.contains("x"))
  match incoming.variables_in_scope.get("x") {
    Some(variable) => {
      assert_eq(variable.variable_value.literal_value, Some("1"))
      assert_true(!@cfg.variable_may_be_unset(incoming, "x"))
    }
    None => abort("expected tracked variable")
  }
  assert_true(outgoing.state_is_reachable)
}
```

## Adjust Lowering Rules And Ask Control-Flow Questions

`CfgParameters` controls shell-specific lowering decisions such as `lastpipe`
and `pipefail`, while `compute_post_dominators`, `post_dominates`, and
`does_post_dominate` support control-flow reasoning on top of the constructed
graph.

```mbt check
///|
test "doc cfg parameters influence how pipelines are lowered" {
  let pipeline = match @parser.parse_script("printf x | cat\n") {
    Ok(script) => script
    Err(err) => abort(err.to_string())
  }
  let detached = @cfg.build_cfg(pipeline, @cfg.CfgParameters::new(false, false))
  let lastpipe = @cfg.build_cfg(pipeline, @cfg.CfgParameters::new(true, false))
  let mut detached_subshells = 0
  let mut lastpipe_subshells = 0
  for id in @cfg.id_to_nodes(detached, @cfg.root_ast_id(detached)) {
    match @cfg.node_of(detached, id) {
      Some({ kind: @cfg.CfgNodeKind::ExecuteSubshell(_, _, _), .. }) =>
        detached_subshells += 1
      _ => ()
    }
  }
  for id in @cfg.id_to_nodes(lastpipe, @cfg.root_ast_id(lastpipe)) {
    match @cfg.node_of(lastpipe, id) {
      Some({ kind: @cfg.CfgNodeKind::ExecuteSubshell(_, _, _), .. }) =>
        lastpipe_subshells += 1
      _ => ()
    }
  }

  assert_true(detached_subshells > lastpipe_subshells)
}
```
