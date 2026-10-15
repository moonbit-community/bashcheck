# bashcheck/semantics

`build_index`, `node_ref_of`, `span_of`, `enclosing_span_of`, `parent_of` and `children_of` support structural rule queries. Command helpers and shell inference serve the CLI analysis pipeline. Library-only query wrappers and unused knowledge tables have been removed; tests use the remaining index and resolver entry points directly.

```mbt check
///|
test "doc semantics production entry point" {
  let script = @parser.parse_script_report("echo hi\n").script.unwrap()
  let indexed = @semantics.build_index(script)
  let root = @semantics.root_id(indexed)
  assert_true(@semantics.node_ref_of(indexed, root) is Some(Script(_)))
  assert_true(@semantics.children_of(indexed, root).length() > 0)
}
```
