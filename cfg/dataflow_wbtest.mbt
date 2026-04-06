///|
fn[A] dataflow_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn parse_dataflow_ok(source : String) -> @parser.Script {
  match @parser.parse_script(source) {
    Ok(script) => script
    Err(error) => dataflow_fail(error.to_string())
  }
}

///|
fn parse_dataflow_with_options(
  source : String,
  options : @parser.ParseOptions,
) -> @parser.Script {
  let report = @parser.parse_script_with_options(source, options)
  match report.script {
    Some(script) => script
    None => dataflow_fail("expected script")
  }
}

///|
fn build_analysis_ok(source : String) -> (CFG, CfgAnalysis) {
  let cfg = build_cfg(
    parse_dataflow_ok(source),
    CfgParameters::new(false, false),
  )
  (cfg, analyze_control_flow(cfg))
}

///|
fn build_analysis_with_options(
  source : String,
  options : @parser.ParseOptions,
) -> (CFG, CfgAnalysis) {
  let cfg = build_cfg(
    parse_dataflow_with_options(source, options),
    CfgParameters::new(false, false),
  )
  (cfg, analyze_control_flow(cfg))
}

///|
fn nth_command_ast_id(cfg : CFG, name : String, nth : Int) -> CfgAstId {
  let mut seen = 0
  for entry in cfg.ast_entries {
    match entry.node_ref {
      @semantics.NodeRef::Command(command) =>
        match @semantics.command_name(command) {
          Some(current) if current == name =>
            if seen == nth {
              return entry.id
            } else {
              seen += 1
            }
          _ => ()
        }
      _ => ()
    }
  }
  dataflow_fail("missing command ast id")
}

///|
fn outgoing_ast_state(analysis : CfgAnalysis, id : CfgAstId) -> ProgramState {
  match outgoing_state_of_ast(analysis, id) {
    Some(state) => state
    None => dataflow_fail("missing outgoing state")
  }
}

///|
fn incoming_ast_state(analysis : CfgAnalysis, id : CfgAstId) -> ProgramState {
  match incoming_state_of_ast(analysis, id) {
    Some(state) => state
    None => dataflow_fail("missing incoming state")
  }
}

///|
fn expect_literal(
  state : ProgramState,
  name : String,
  literal : String,
) -> Unit {
  match state.variables_in_scope.get(name) {
    Some(variable) =>
      if variable.variable_value.literal_value != Some(literal) {
        dataflow_fail("unexpected literal value")
      }
    None => dataflow_fail("missing variable")
  }
}

///|
test "dataflow tracks builtin-driven variable properties and kinds" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|declare -i n
      #|wait -p pid
      #|mapfile arr
      #|unset -v arr
      #|
    ),
  )

  let declare_cmd = nth_command_ast_id(cfg, "declare", 0)
  let wait_cmd = nth_command_ast_id(cfg, "wait", 0)
  let mapfile_cmd = nth_command_ast_id(cfg, "mapfile", 0)
  let unset_cmd = nth_command_ast_id(cfg, "unset", 0)

  assert_true(
    variable_may_be_declared_integer(
      outgoing_ast_state(analysis, declare_cmd),
      "n",
    ),
  )
  assert_true(
    variable_may_be_assigned_integer(
      outgoing_ast_state(analysis, wait_cmd),
      "pid",
    ),
  )
  assert_true(
    variable_may_be_array(outgoing_ast_state(analysis, mapfile_cmd), "arr"),
  )
  assert_true(
    variable_may_be_unset(outgoing_ast_state(analysis, unset_cmd), "arr"),
  )
}

///|
test "dataflow does not infer arrays from indexed parameter reads" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|x=scalar
      #|printf '%s' "${x[0]}"
      #|
    ),
  )
  let printf_cmd = nth_command_ast_id(cfg, "printf", 0)

  assert_true(
    !variable_may_be_array(outgoing_ast_state(analysis, printf_cmd), "x"),
  )
}

///|
test "dataflow does not infer arrays from indexed arithmetic reads" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|x=7
      #|i=0
      #|echo $((x[i]))
      #|
    ),
  )
  let echo_cmd = nth_command_ast_id(cfg, "echo", 0)

  assert_true(
    !variable_may_be_array(outgoing_ast_state(analysis, echo_cmd), "x"),
  )
}

///|
test "dataflow preserves scalar append assignment values" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|x=old
      #|x+=new
      #|echo "$x"
      #|
    ),
  )
  let echo_cmd = nth_command_ast_id(cfg, "echo", 0)

  expect_literal(incoming_ast_state(analysis, echo_cmd), "x", "oldnew")
}

///|
test "dataflow propagates function globals and drops function locals" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|x=base
      #|f() { local y=tmp; x=next; }
      #|f
      #|
    ),
  )
  let call_cmd = nth_command_ast_id(cfg, "f", 0)
  let state = outgoing_ast_state(analysis, call_cmd)

  expect_literal(state, "x", "next")
  assert_true(!state.variables_in_scope.contains("y"))
  assert_true(command_is_reachable(analysis, call_cmd))
}

///|
test "dataflow keeps subshell writes isolated from the parent shell" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|x=outer
      #|( x=inner )
      #|echo "$x"
      #|
    ),
  )
  let echo_cmd = nth_command_ast_id(cfg, "echo", 0)
  let state = incoming_ast_state(analysis, echo_cmd)

  expect_literal(state, "x", "outer")
}

///|
test "dataflow keeps declare assignments with expansions in scope" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|y=value
      #|declare x=$y
      #|
    ),
  )
  let declare_cmd = nth_command_ast_id(cfg, "declare", 0)
  let state = outgoing_ast_state(analysis, declare_cmd)

  assert_true(state.variables_in_scope.contains("x"))
}

///|
test "dataflow decodes dollar single quoted assignment literals" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|x=$'a\nb'
      #|printf '%s' "$x"
      #|
    ),
  )
  let printf_cmd = nth_command_ast_id(cfg, "printf", 0)

  expect_literal(
    incoming_ast_state(analysis, printf_cmd),
    "x",
    (
      #|a
      #|b
    ),
  )
}

///|
test "dataflow parses declare flags without treating operands as options" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|declare data
      #|declare -i x
      #|declare +i x
      #|
    ),
  )
  let plain_declare = nth_command_ast_id(cfg, "declare", 0)
  let integer_declare = nth_command_ast_id(cfg, "declare", 1)
  let clear_integer = nth_command_ast_id(cfg, "declare", 2)

  assert_true(
    !variable_may_be_array(outgoing_ast_state(analysis, plain_declare), "data"),
  )
  assert_true(
    variable_may_be_declared_integer(
      outgoing_ast_state(analysis, integer_declare),
      "x",
    ),
  )
  assert_true(
    !variable_may_be_declared_integer(
      outgoing_ast_state(analysis, clear_integer),
      "x",
    ),
  )
}

///|
test "dataflow parses clustered wait -p options" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|wait -np pid
      #|
    ),
  )
  let wait_cmd = nth_command_ast_id(cfg, "wait", 0)

  assert_true(
    variable_may_be_assigned_integer(
      outgoing_ast_state(analysis, wait_cmd),
      "pid",
    ),
  )
}

///|
test "dataflow keeps wait -p targets after nonliteral operands" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|wait "$job" -np pid
      #|
    ),
  )
  let wait_cmd = nth_command_ast_id(cfg, "wait", 0)

  assert_true(
    variable_may_be_assigned_integer(
      outgoing_ast_state(analysis, wait_cmd),
      "pid",
    ),
  )
}

///|
test "dataflow excludes read option arguments from assignment targets" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|read -d delim target
      #|
    ),
  )
  let read_cmd = nth_command_ast_id(cfg, "read", 0)
  let state = outgoing_ast_state(analysis, read_cmd)

  assert_true(!state.variables_in_scope.contains("delim"))
  assert_true(state.variables_in_scope.contains("target"))
}

///|
test "dataflow keeps read -a targets after trailing nonliteral operands" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|read -a arr "$rest"
      #|
    ),
  )
  let read_cmd = nth_command_ast_id(cfg, "read", 0)

  assert_true(
    variable_may_be_array(outgoing_ast_state(analysis, read_cmd), "arr"),
  )
}

///|
test "dataflow keeps DEFINE builtins and clustered unset effects visible" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|DEFINE_string foo '' ''
      #|unset -vf foo
      #|
    ),
  )
  let define_cmd = nth_command_ast_id(cfg, "DEFINE_string", 0)
  let unset_cmd = nth_command_ast_id(cfg, "unset", 0)

  assert_true(
    outgoing_ast_state(analysis, define_cmd).variables_in_scope.contains(
      "FLAGS_foo",
    ),
  )
  assert_true(
    variable_may_be_unset(outgoing_ast_state(analysis, unset_cmd), "foo"),
  )
}

///|
test "dataflow tracks readonly and export assignment builtins" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|readonly foo=bar
      #|builtin export var=4
      #|f() { :; }
      #|export -f f
      #|echo "$foo $var"
      #|
    ),
  )
  let echo_cmd = nth_command_ast_id(cfg, "echo", 0)
  let state = incoming_ast_state(analysis, echo_cmd)

  expect_literal(state, "foo", "bar")
  expect_literal(state, "var", "4")
  assert_true(!state.variables_in_scope.contains("f"))
}

///|
test "dataflow keeps command wrapper targets conservative" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|command export var=4
      #|echo "$var"
      #|
    ),
  )
  let echo_cmd = nth_command_ast_id(cfg, "echo", 0)
  let state = incoming_ast_state(analysis, echo_cmd)

  assert_true(!state.variables_in_scope.contains("var"))
}

///|
test "dataflow does not unwrap busybox applets into builtin side effects" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|busybox printf -v foo %s value
      #|echo "$foo"
      #|
    ),
  )
  let echo_cmd = nth_command_ast_id(cfg, "echo", 0)
  let state = incoming_ast_state(analysis, echo_cmd)

  assert_true(!state.variables_in_scope.contains("foo"))
}

///|
test "dataflow parses printf -v with bsd-style options" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|printf -v 'array[0]' %s "$var"
      #|printf '%s' -v foo
      #|
    ),
  )
  let array_printf = nth_command_ast_id(cfg, "printf", 0)
  let positional_printf = nth_command_ast_id(cfg, "printf", 1)

  assert_true(
    outgoing_ast_state(analysis, array_printf).variables_in_scope.contains(
      "array[0]",
    ),
  )
  assert_true(
    !outgoing_ast_state(analysis, positional_printf).variables_in_scope.contains(
      "foo",
    ),
  )
}

///|
test "dataflow preserves clustered unset mode through mixed literal args" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|DEFINE_string foo '' ''
      #|unset -vf "$x" foo
      #|
    ),
  )
  let unset_cmd = nth_command_ast_id(cfg, "unset", 0)

  assert_true(
    variable_may_be_unset(outgoing_ast_state(analysis, unset_cmd), "foo"),
  )
}

///|
test "dataflow read fallback only keeps trailing contiguous literal targets" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|read foo "$bar"
      #|
    ),
  )
  let read_cmd = nth_command_ast_id(cfg, "read", 0)
  let state = outgoing_ast_state(analysis, read_cmd)

  assert_true(!state.variables_in_scope.contains("foo"))
}

///|
test "dataflow tracks named fd redirections as integer assignments" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|exec {fd}>out
      #|
    ),
  )
  let exec_cmd = nth_command_ast_id(cfg, "exec", 0)

  assert_true(
    variable_may_be_assigned_integer(
      outgoing_ast_state(analysis, exec_cmd),
      "fd",
    ),
  )
}

///|
test "dataflow marks commands after exit as unreachable" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|exit
      #|echo nope
      #|
    ),
  )
  let echo_cmd = nth_command_ast_id(cfg, "echo", 0)

  assert_true(!command_is_reachable(analysis, echo_cmd))
  match incoming_state_of_ast(analysis, echo_cmd) {
    Some(state) => assert_true(!state.state_is_reachable)
    None => dataflow_fail("missing incoming state for unreachable command")
  }
}

///|
test "dataflow does not treat straggler-only function bodies as entry reachable" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|f() { echo hidden; }
      #|echo live
      #|
    ),
  )
  let hidden = nth_command_ast_id(cfg, "echo", 0)
  let live = nth_command_ast_id(cfg, "echo", 1)

  assert_true(!command_is_reachable(analysis, hidden))
  assert_true(command_is_reachable(analysis, live))
}

///|
test "dataflow analyzes nested functions discovered from stragglers" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|outer() { inner() { echo nested; }; }
      #|echo live
      #|
    ),
  )
  let nested = nth_command_ast_id(cfg, "echo", 0)
  let live = nth_command_ast_id(cfg, "echo", 1)

  assert_true(!command_is_reachable(analysis, nested))
  assert_true(command_is_reachable(analysis, live))
  match incoming_state_of_ast(analysis, nested) {
    Some(state) => assert_true(state.state_is_reachable)
    None => dataflow_fail("missing incoming state for nested straggler")
  }
}

///|
test "dataflow keeps dead functions analyzable after explicit exit" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|f() { echo hidden; }
      #|exit
      #|
    ),
  )
  let hidden = nth_command_ast_id(cfg, "echo", 0)

  assert_true(!command_is_reachable(analysis, hidden))
  match incoming_state_of_ast(analysis, hidden) {
    Some(state) => assert_true(state.state_is_reachable)
    None => dataflow_fail("missing incoming state for dead function")
  }
}

///|
test "dataflow preserves outer values when branch-local variables shadow them" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|x=global
      #|f() { if maybe; then local x=local; fi; echo "$x"; }
      #|f
      #|
    ),
  )
  let echo_cmd = nth_command_ast_id(cfg, "echo", 0)
  let state = incoming_ast_state(analysis, echo_cmd)

  assert_true(state.variables_in_scope.contains("x"))
  assert_true(!variable_may_be_unset(state, "x"))
}

///|
test "dataflow keeps post-dominance and node lookups available" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|echo a
      #|printf b
      #|
    ),
  )
  let first = nth_command_ast_id(cfg, "echo", 0)
  let second = nth_command_ast_id(cfg, "printf", 0)

  assert_true(does_post_dominate(analysis, second, first))

  let nodes = id_to_nodes(cfg, second)
  guard nodes.length() > 0 else { dataflow_fail("missing cfg nodes") }
  assert_true(incoming_state_of_node(analysis, nodes[0]) is Some(_))
  assert_true(
    outgoing_state_of_node(analysis, nodes[nodes.length() - 1]) is Some(_),
  )
}

///|
test "dataflow keeps source prefix assignments visible inside sourced scripts" {
  let options = @parser.ParseOptions::new(
    true,
    false,
    false,
    true,
    Some("/tmp/main.sh"),
    [],
    [
      (
        "lib.sh",
        (
          #|echo "$x"
          #|
        ),
      ),
    ],
  )
  let (cfg, analysis) = build_analysis_with_options(
    (
      #|x=inner . lib.sh
      #|
    ),
    options,
  )
  let sourced_echo = nth_command_ast_id(cfg, "echo", 0)

  expect_literal(incoming_ast_state(analysis, sourced_echo), "x", "inner")
}

///|
test "dataflow tracks arithmetic assignments and increments as integer values" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|(( x = 1 ))
      #|(( x++ ))
      #|echo "$x"
      #|
    ),
  )
  let echo_cmd = nth_command_ast_id(cfg, "echo", 0)
  let state = incoming_ast_state(analysis, echo_cmd)

  assert_true(variable_may_be_assigned_integer(state, "x"))
  assert_true(!variable_may_be_unset(state, "x"))
}

///|
test "dataflow read fallback parses literal option suffixes conservatively" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|read "$opts" -na field
      #|
    ),
  )
  let read_cmd = nth_command_ast_id(cfg, "read", 0)
  let state = outgoing_ast_state(analysis, read_cmd)

  assert_true(!state.variables_in_scope.contains("-na"))
  assert_true(state.variables_in_scope.contains("field"))
  assert_true(!variable_may_be_array(state, "field"))
}

///|
test "dataflow drops source prefix assignments after the sourced script ends" {
  let options = @parser.ParseOptions::new(
    true,
    false,
    false,
    true,
    Some("/tmp/main.sh"),
    [],
    [
      (
        "lib.sh",
        (
          #|:
          #|
        ),
      ),
    ],
  )
  let (cfg, analysis) = build_analysis_with_options(
    (
      #|x=outer
      #|x=inner . lib.sh
      #|echo "$x"
      #|
    ),
    options,
  )
  let echo_cmd = nth_command_ast_id(cfg, "echo", 0)

  expect_literal(incoming_ast_state(analysis, echo_cmd), "x", "outer")
}

///|
test "dataflow treats commands after break in loops as unreachable" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|while maybe; do break; echo hidden; done
      #|echo live
      #|
    ),
  )
  let hidden = nth_command_ast_id(cfg, "echo", 0)
  let live = nth_command_ast_id(cfg, "echo", 1)

  assert_true(!command_is_reachable(analysis, hidden))
  assert_true(command_is_reachable(analysis, live))
}

///|
test "dataflow treats commands after continue in loops as unreachable" {
  let (cfg, analysis) = build_analysis_ok(
    (
      #|for x in a; do continue; echo hidden; done
      #|echo live
      #|
    ),
  )
  let hidden = nth_command_ast_id(cfg, "echo", 0)
  let live = nth_command_ast_id(cfg, "echo", 1)

  assert_true(!command_is_reachable(analysis, hidden))
  assert_true(command_is_reachable(analysis, live))
}
