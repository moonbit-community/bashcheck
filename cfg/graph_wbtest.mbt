///|
fn[A] cfg_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn parse_cfg_ok(source : String) -> @parser.Script {
  match @parser.parse_script(source) {
    Ok(script) => script
    Err(error) => cfg_fail(error.to_string())
  }
}

///|
fn parse_cfg_with_options(
  source : String,
  options : @parser.ParseOptions,
) -> @parser.Script {
  let report = @parser.parse_script_with_options(source, options)
  match report.script {
    Some(script) => script
    None => cfg_fail("expected script")
  }
}

///|
fn root_nodes(cfg : CFG) -> Array[CfgNodeId] {
  id_to_nodes(cfg, root_ast_id(cfg))
}

///|
fn count_execute_subshells(cfg : CFG) -> Int {
  let mut count = 0
  for id in root_nodes(cfg) {
    match node_of(cfg, id) {
      Some({ kind: CfgNodeKind::ExecuteSubshell(_, _, _), .. }) => count += 1
      _ => ()
    }
  }
  count
}

///|
fn has_execute_command(cfg : CFG, name : String) -> Bool {
  for id in root_nodes(cfg) {
    match node_of(cfg, id) {
      Some({ kind: CfgNodeKind::ExecuteCommand(Some(current)), .. }) =>
        if current == name {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn has_background_pid(cfg : CFG) -> Bool {
  for id in root_nodes(cfg) {
    match node_of(cfg, id) {
      Some({ kind: CfgNodeKind::SetBackgroundPid(_), .. }) => return true
      _ => ()
    }
  }
  false
}

///|
fn has_define_function(cfg : CFG, name : String) -> Bool {
  for id in root_nodes(cfg) {
    match node_of(cfg, id) {
      Some({ kind: CfgNodeKind::ApplyEffects(effects), .. }) =>
        for tagged in effects {
          match tagged.effect {
            CfgEffect::DefineFunction(current, _, _, _) if current == name =>
              return true
            _ => ()
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn has_read_variable_effect(cfg : CFG, name : String) -> Bool {
  for id in root_nodes(cfg) {
    match node_of(cfg, id) {
      Some({ kind: CfgNodeKind::ApplyEffects(effects), .. }) =>
        for tagged in effects {
          match tagged.effect {
            CfgEffect::ReadVariable(current) if current == name => return true
            _ => ()
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn has_integer_write_effect(cfg : CFG, name : String) -> Bool {
  for id in root_nodes(cfg) {
    match node_of(cfg, id) {
      Some({ kind: CfgNodeKind::ApplyEffects(effects), .. }) =>
        for tagged in effects {
          match tagged.effect {
            CfgEffect::WriteVariable(current, value) =>
              if current == name && value == CfgValue::Integer {
                return true
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn has_string_write_effect(cfg : CFG, name : String) -> Bool {
  for id in root_nodes(cfg) {
    match node_of(cfg, id) {
      Some({ kind: CfgNodeKind::ApplyEffects(effects), .. }) =>
        for tagged in effects {
          match tagged.effect {
            CfgEffect::WriteVariable(current, value) =>
              if current == name && value == CfgValue::String {
                return true
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn has_undefine_variable_effect(cfg : CFG, name : String) -> Bool {
  for id in root_nodes(cfg) {
    match node_of(cfg, id) {
      Some({ kind: CfgNodeKind::ApplyEffects(effects), .. }) =>
        for tagged in effects {
          match tagged.effect {
            CfgEffect::UndefineVariable(current) if current == name =>
              return true
            _ => ()
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn has_hint_defined_effect(cfg : CFG, name : String) -> Bool {
  for node in cfg.nodes {
    match node.kind {
      CfgNodeKind::ApplyEffects(effects) =>
        for tagged in effects {
          match tagged.effect {
            CfgEffect::HintDefined(current) if current == name => return true
            _ => ()
          }
        }
      _ => ()
    }
  }
  false
}

///|
fn find_command_ast_id(cfg : CFG, name : String) -> CfgAstId {
  for entry in cfg.ast_entries {
    match entry.node_ref {
      @semantics.NodeRef::Command(command) =>
        match @semantics.command_name(command) {
          Some(current) if current == name => return entry.id
          _ => ()
        }
      _ => ()
    }
  }
  cfg_fail("missing command ast id")
}

///|
fn find_source_ast_id(cfg : CFG) -> CfgAstId {
  for entry in cfg.ast_entries {
    match entry.node_ref {
      @semantics.NodeRef::SourceCommand(_) => return entry.id
      _ => ()
    }
  }
  cfg_fail("missing source command")
}

///|
fn find_pipeline_ast_id(cfg : CFG) -> CfgAstId {
  for entry in cfg.ast_entries {
    match entry.node_ref {
      @semantics.NodeRef::Pipeline(_) => return entry.id
      _ => ()
    }
  }
  cfg_fail("missing pipeline ast id")
}

///|
fn incoming_edge_count(
  cfg : CFG,
  target : CfgNodeId,
  kind : CfgEdgeKind,
) -> Int {
  let mut count = 0
  for edge in edges(cfg) {
    if edge.to == target && edge.kind == kind {
      count += 1
    }
  }
  count
}

///|
test "cfg keeps included source scripts under the source command" {
  let options = @parser.ParseOptions::new(
    true,
    false,
    false,
    true,
    Some("/tmp/main.sh"),
    [],
    [("lib.sh", "echo inside\n")],
  )
  let script = parse_cfg_with_options(". lib.sh\n", options)
  let cfg = build_cfg(script, CfgParameters::new(false, false))

  let source_id = find_source_ast_id(cfg)
  let source_entry = cfg.ast_entries[source_id.to_int()]
  let mut script_children = 0
  for child in source_entry.children {
    if cfg.ast_entries[child.to_int()].kind == AstTag::Script {
      script_children += 1
    }
  }

  assert_eq(script_children, 1)
  assert_true(has_execute_command(cfg, "."))
  assert_true(has_execute_command(cfg, "echo"))
}

///|
test "cfg models background items and lastpipe-dependent pipelines" {
  let background = build_cfg(
    parse_cfg_ok("echo a &\necho b\n"),
    CfgParameters::new(false, false),
  )
  assert_true(has_background_pid(background))

  let pipeline = parse_cfg_ok("printf x | cat\n")
  let detached = build_cfg(pipeline, CfgParameters::new(false, false))
  let lastpipe = build_cfg(pipeline, CfgParameters::new(true, false))
  assert_eq(count_execute_subshells(detached), 2)
  assert_eq(count_execute_subshells(lastpipe), 1)
}

///|
test "cfg resolves builtin and command wrappers without treating flags as commands" {
  let builtin_cfg = build_cfg(
    parse_cfg_ok("builtin -- printf -v out '%s' foo\n"),
    CfgParameters::new(false, false),
  )
  assert_true(has_string_write_effect(builtin_cfg, "out"))
  assert_true(!has_execute_command(builtin_cfg, "--"))

  let command_cfg = build_cfg(
    parse_cfg_ok(
      "command -- printf '%s' foo\ncommand -p printf '%s' foo\ncommand -v printf\n",
    ),
    CfgParameters::new(false, false),
  )
  assert_true(has_execute_command(command_cfg, "printf"))
  assert_true(has_execute_command(command_cfg, "command"))
  assert_true(!has_execute_command(command_cfg, "--"))
  assert_true(!has_execute_command(command_cfg, "-p"))
  assert_true(!has_execute_command(command_cfg, "-v"))
}

///|
test "cfg pipefail promotes leading pipeline exits into real flow" {
  let script = parse_cfg_ok("false | true\n")
  let detached = build_cfg(script, CfgParameters::new(false, false))
  let pipefail = build_cfg(script, CfgParameters::new(false, true))

  let detached_pipeline = find_pipeline_ast_id(detached)
  let pipefail_pipeline = find_pipeline_ast_id(pipefail)
  let detached_end = match id_to_range(detached, detached_pipeline) {
    Some((_, end_)) => end_
    None => cfg_fail("missing detached pipeline range")
  }
  let pipefail_end = match id_to_range(pipefail, pipefail_pipeline) {
    Some((_, end_)) => end_
    None => cfg_fail("missing pipefail pipeline range")
  }

  assert_eq(
    incoming_edge_count(detached, detached_end, CfgEdgeKind::FalseFlow),
    2,
  )
  assert_eq(
    incoming_edge_count(pipefail, pipefail_end, CfgEdgeKind::FalseFlow),
    0,
  )
  assert_eq(incoming_edge_count(detached, detached_end, CfgEdgeKind::Flow), 1)
  assert_eq(incoming_edge_count(pipefail, pipefail_end, CfgEdgeKind::Flow), 3)
}

///|
test "cfg separates function definition effects from later calls" {
  let cfg = build_cfg(
    parse_cfg_ok("f() { echo hi; }\nf\n"),
    CfgParameters::new(false, false),
  )

  assert_true(has_define_function(cfg, "f"))
  assert_true(has_execute_command(cfg, "f"))
  assert_true(has_execute_command(cfg, "echo"))
}

///|
test "cfg models named fd redirections as variable writes and close reads" {
  let cfg = build_cfg(
    parse_cfg_ok("exec {fd}>out\nexec {fd}>&-\n"),
    CfgParameters::new(false, false),
  )

  assert_true(has_integer_write_effect(cfg, "fd"))
  assert_true(has_read_variable_effect(cfg, "fd"))
}

///|
test "cfg models DEFINE builtins and clustered unset options" {
  let cfg = build_cfg(
    parse_cfg_ok("DEFINE_string foo '' ''\nunset -vf foo\n"),
    CfgParameters::new(false, false),
  )

  assert_true(has_string_write_effect(cfg, "FLAGS_foo"))
  assert_true(has_undefine_variable_effect(cfg, "foo"))
}

///|
test "cfg records definition hints for variable existence tests" {
  let cfg = build_cfg(
    parse_cfg_ok("if [[ -v foo ]]; then echo \"$foo\"; fi\n"),
    CfgParameters::new(false, false),
  )

  assert_true(has_hint_defined_effect(cfg, "foo"))
}

///|
test "cfg traverses parameter expansion operator contents" {
  let cfg = build_cfg(
    parse_cfg_ok(": \"${x:=$(printf hi)}\" \"${y:-$z}\"\n"),
    CfgParameters::new(false, false),
  )

  assert_eq(count_execute_subshells(cfg), 1)
  assert_true(has_read_variable_effect(cfg, "z"))
}

///|
test "cfg models arithmetic assignments and increments as integer writes" {
  let cfg = build_cfg(
    parse_cfg_ok("(( x = 1 ))\n(( ++y ))\n"),
    CfgParameters::new(false, false),
  )

  assert_true(has_integer_write_effect(cfg, "x"))
  assert_true(has_integer_write_effect(cfg, "y"))
}

///|
test "cfg post dominators work for simple linear scripts" {
  let cfg = build_cfg(
    parse_cfg_ok("echo a\nprintf b\n"),
    CfgParameters::new(false, false),
  )
  let first = find_command_ast_id(cfg, "echo")
  let second = find_command_ast_id(cfg, "printf")

  assert_true(post_dominates(cfg, second, first))
  assert_true(!post_dominates(cfg, first, second))
}
