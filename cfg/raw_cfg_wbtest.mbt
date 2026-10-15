///|
fn build_cfg_unoptimized(
  script : @parser.Script,
  params : CfgParameters,
) -> CFG {
  let collector = AstCollector::new()
  let root = collector.copy_script(script, None)
  let builder = GraphBuilder::new(root, collector.entries, params)
  builder.build_raw()
}
