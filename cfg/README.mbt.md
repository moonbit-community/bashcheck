# bashcheck/cfg

`build_cfg` lowers a parsed script into the optimized control-flow graph used by lint rules. AST and CFG spans retain their source identifiers. `analyze_control_flow` computes abstract state, and production queries expose the information consumed by rules. Raw graph construction and outgoing-state inspection are local test helpers, used to verify that optimization preserves dataflow behavior.

```mbt check
///|
test "doc cfg production entry point" {
  let script = @parser.parse_script_report("x=1\necho \"$x\"\n").script.unwrap()
  let graph = @cfg.build_cfg(script, @cfg.CfgParameters::new(false, false))
  assert_true(@cfg.id_to_nodes(graph, @cfg.root_ast_id(graph)).length() > 0)
}
```
