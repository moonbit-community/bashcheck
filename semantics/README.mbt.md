# bashcheck/semantics

`semantics` layers reusable AST queries and shell-environment inference on top
of `parser`. It roughly maps to `ShellCheck.ASTLib` plus the shell-selection
helpers that later analysis stages need.

## Build A Navigable Index Over The Parser AST

`build_index` converts a `parser.Script` into an `IndexedScript` with stable
`NodeId`s, `NodeKind`s, and `NodeRef`s. That index is the right starting point
when later analysis wants parent/child traversal, nearest enclosing spans, or a
quick way to recover the command or word that owns some nested node.

```mbt check
///|
test "doc semantics builds an index that keeps node kinds and spans" {
  let script = match
    @parser.parse_script("command -- printf '%s' \"$x\" >out\n") {
    Ok(script) => script
    Err(err) => abort(err.to_string())
  }
  let indexed = @semantics.build_index(script)
  let root = @semantics.root_id(indexed)

  assert_eq(root.to_int(), 0)
  assert_true(
    match @semantics.node_kind_of(indexed, root) {
      Some(@semantics.NodeKind::Script) => true
      _ => false
    },
  )
  assert_true(@semantics.span_of(indexed, root) is Some(_))
  assert_true(@semantics.children_of(indexed, root).length() > 0)
  assert_true(@semantics.command_of(indexed, root) is None)
}
```

## Ask Command-Level Questions Without Re-Parsing Syntax

Once you already have parser nodes, helpers such as `command_name`,
`effective_command_name`, `command_arguments`, `effective_command_arguments`,
`all_redirections`, `literal_text`, `leading_unquoted_text`,
`is_assignment_only`, `is_glob_word`, and `oversimplify_command` let later
checks reason about shell syntax in a higher-level way. The traversal helpers
`walk_script`, `walk_command`, `walk_word`, and friends exist for package code
that needs to scan nested nodes without rebuilding its own visitors.

```mbt check
///|
test "doc semantics exposes command-oriented helpers" {
  let script = match
    @parser.parse_script("command -- printf '%s' \"$x\" >out\n") {
    Ok(script) => script
    Err(err) => abort(err.to_string())
  }
  let command = script.items[0].and_or.head.segments[0].command

  assert_eq(@semantics.command_name(command), Some("command"))
  assert_eq(@semantics.effective_command_name(command), Some("printf"))
  assert_eq(@semantics.effective_command_arguments(command).length(), 2)
  assert_eq(@semantics.oversimplify_command(command), [
    "command", "--", "printf", "%s", "${VAR}",
  ])
  assert_eq(@semantics.all_redirections(command).length(), 1)
}
```

## Infer Shell Context And Script-Level Directives

The shell helpers are what later packages use to decide whether the current
input should behave like `sh`, `bash`, `dash`, or another supported dialect.
`determine_shell`, `determine_shell_with_fallback`, `shell_from_shebang`,
`shell_from_annotation`, `shell_from_filename`, and
`suppresses_unknown_shell_warning` answer that question; `has_set_e`,
`has_pipefail`, `has_lastpipe`, `has_inherit_errexit`, `has_execfail`, and
`effective_execution_mode` explain how the script is expected to run. For
lower-level heuristics, the package also exports command/operator/variable
tables such as `common_command_names`, `binary_test_operators`, and
`read_flag_takes_argument`.

```mbt check
///|
test "doc semantics infers shell settings and directives" {
  let script = match
    @parser.parse_script(
      "#!/usr/bin/env bash -e\n# shellcheck shell=dash disable=SC2000 enable=quote-check\nset -o pipefail\n",
    ) {
    Ok(script) => script
    Err(err) => abort(err.to_string())
  }

  assert_eq(@semantics.determine_shell(script), @semantics.ShellDialect::Dash)
  assert_true(@semantics.has_set_e(script))
  assert_true(@semantics.has_pipefail(script))
  assert_eq(@semantics.extract_disable_directives(script), ["SC2000"])
  assert_eq(@semantics.extract_enable_directives(script), ["quote-check"])
  assert_eq(
    @semantics.effective_execution_mode(sourced=true),
    @semantics.ExecutionMode::Sourced,
  )
}
```
