///|
fn run_quote_safe_variables_optional_check(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let cfg = @cfg.build_cfg(
    script,
    @cfg.CfgParameters::new(
      @semantics.has_lastpipe(script, shell),
      @semantics.has_pipefail(script),
    ),
  )
  let analysis = @cfg.analyze_control_flow(cfg)
  for id in @cfg.ast_ids(cfg) {
    match @cfg.ast_ref_of(cfg, id) {
      Some(@semantics.NodeRef::Word(word)) =>
        match word_unquoted_single_variable_name(word) {
          Some(name) =>
            if quote_safe_word_context_allows(cfg, id, word) &&
              variable_state_is_quote_safe(analysis, id, name) {
              push_diagnostic_with_fix(
                diagnostics,
                word.span,
                CheckSeverity::Style,
                2248,
                "Prefer double quoting even when variables don't contain special characters.",
                replace_span_fix(word.span, "\"" + word.source + "\""),
              )
            }
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn word_unquoted_single_variable_name(word : @parser.Word) -> String? {
  match word.parts {
    [@parser.WordPart::Parameter(name)] =>
      if is_identifier_name(name) {
        Some(name)
      } else {
        None
      }
    [
      @parser.WordPart::BracedParameter(
        {
          length_prefix: false,
          indirect: false,
          name: Some(name),
          index: None,
          operator: None,
          ..,
        }
      ),
    ] => if is_identifier_name(name) { Some(name) } else { None }
    _ => None
  }
}

///|
fn quote_safe_word_context_allows(
  cfg : @cfg.CFG,
  id : @cfg.CfgAstId,
  word : @parser.Word,
) -> Bool {
  let mut current = Some(id)
  while current is Some(_) {
    match current {
      Some(node_id) =>
        match @cfg.ast_ref_of(cfg, node_id) {
          Some(@semantics.NodeRef::Assignment(_))
          | Some(@semantics.NodeRef::ArrayElement(_))
          | Some(@semantics.NodeRef::ArrayIndex(_))
          | Some(@semantics.NodeRef::ArithmeticExpr(_))
          | Some(@semantics.NodeRef::ArithmeticToken(_))
          | Some(@semantics.NodeRef::ForClause(_))
          | Some(@semantics.NodeRef::SelectClause(_))
          | Some(@semantics.NodeRef::CaseClause(_))
          | Some(@semantics.NodeRef::CaseItem(_)) => return false
          Some(@semantics.NodeRef::ConditionCommand(condition)) =>
            match condition.kind {
              @parser.ConditionKind::DoubleBracket => return false
              _ => ()
            }
          Some(@semantics.NodeRef::Command(command)) =>
            if word_is_effective_command_name(command, word) {
              return false
            }
          _ => ()
        }
      None => ()
    }
    current = match current {
      Some(node_id) => @cfg.ast_parent_of(cfg, node_id)
      None => None
    }
  }
  true
}

///|
fn word_is_effective_command_name(
  command : @parser.Command,
  word : @parser.Word,
) -> Bool {
  match @semantics.effective_command_words(command).get(0) {
    Some(first) => first == word
    None => false
  }
}

///|
fn variable_state_is_quote_safe(
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  name : String,
) -> Bool {
  match @cfg.incoming_state_of_ast(analysis, id) {
    Some(state) if state.state_is_reachable &&
      !@cfg.variable_may_be_unset(state, name) =>
      match state.variables_in_scope.get(name) {
        Some(variable) =>
          match variable.variable_value.space_status {
            @cfg.SpaceStatus::Dirty => false
            @cfg.SpaceStatus::Clean | @cfg.SpaceStatus::Empty => true
          }
        None => false
      }
    _ => false
  }
}

///|
fn run_avoid_nullary_conditions_optional_check(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        match condition.expr {
          @parser.ConditionExpr::Word(word) =>
            match word_single_top_level_substitution_script(word) {
              Some(_) =>
                push_diagnostic_with_fix(
                  diagnostics,
                  word.span,
                  CheckSeverity::Style,
                  2243,
                  "Prefer explicit -n to check for output (or run command without [/[[ to check for success).",
                  insert_after_position_fix(word.span.start, "-n ", 7),
                )
              None =>
                if word_is_pure_dynamic_expansion(word) {
                  push_diagnostic_with_fix(
                    diagnostics,
                    word.span,
                    CheckSeverity::Style,
                    2244,
                    "Prefer explicit -n to check non-empty string (or use =/-ne to check boolean/integer).",
                    insert_before_position_fix(word.span.start, "-n "),
                  )
                }
            }
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn word_is_pure_dynamic_expansion(word : @parser.Word) -> Bool {
  word.parts.length() > 0 && word.parts.all(word_part_is_pure_dynamic_expansion)
}

///|
fn word_part_is_pure_dynamic_expansion(part : @parser.WordPart) -> Bool {
  match part {
    @parser.WordPart::Parameter(_)
    | @parser.WordPart::SpecialParameter(_)
    | @parser.WordPart::BracedParameter(_) => true
    @parser.WordPart::CommandSubstitution(script)
    | @parser.WordPart::BraceCommandSubstitution(_, script)
    | @parser.WordPart::BackQuoted(script) => script.items.length() > 0
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      parts.length() > 0 && parts.all(word_part_is_pure_dynamic_expansion)
    _ => false
  }
}

///|
fn run_avoid_negated_conditions_optional_check(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        check_unnecessarily_inverted_condition_expr(
          condition.kind,
          condition.expr,
          command.span,
          diagnostics,
        )
      _ => ()
    }
  })
  visit_script_pipelines(script, fn(pipeline) {
    for segment in pipeline.segments {
      if segment.bangs % 2 == 0 {
        continue
      }
      match segment.command.kind {
        @parser.CommandKind::Condition(condition) =>
          check_unnecessarily_inverted_banged_condition(
            condition.kind,
            condition.expr,
            span_prefix(segment.span, 1),
            diagnostics,
          )
        _ => ()
      }
    }
  })
}

///|
fn insert_after_position_fix(
  position : @parser.Position,
  text : String,
  precedence : Int,
) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      position,
      position,
      text,
      precedence,
      @fixer.InsertionPoint::after(),
    ),
  ])
}

///|
fn check_unnecessarily_inverted_condition_expr(
  kind : @parser.ConditionKind,
  expr : @parser.ConditionExpr,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match expr {
    @parser.ConditionExpr::Not(@parser.ConditionExpr::Unary(op, _, _)) =>
      match op {
        "-n" =>
          push_diagnostic(
            diagnostics,
            span,
            CheckSeverity::Style,
            2236,
            "Use -z instead of ! -n.",
          )
        "-z" =>
          push_diagnostic(
            diagnostics,
            span,
            CheckSeverity::Style,
            2236,
            "Use -n instead of ! -z.",
          )
        _ => ()
      }
    @parser.ConditionExpr::Not(@parser.ConditionExpr::Binary(op, _, _, _)) =>
      match inverted_condition_operator(op) {
        Some(new_op) =>
          push_diagnostic(
            diagnostics,
            span,
            CheckSeverity::Style,
            2335,
            "Use a " + new_op + " b instead of ! a " + op + " b.",
          )
        None => ()
      }
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      check_unnecessarily_inverted_condition_expr(
        kind, inner, span, diagnostics,
      )
    @parser.ConditionExpr::And(_, lhs, rhs)
    | @parser.ConditionExpr::Or(_, lhs, rhs) => {
      check_unnecessarily_inverted_condition_expr(kind, lhs, span, diagnostics)
      check_unnecessarily_inverted_condition_expr(kind, rhs, span, diagnostics)
    }
    _ => ()
  }
  ignore(kind)
}

///|
fn check_unnecessarily_inverted_banged_condition(
  kind : @parser.ConditionKind,
  expr : @parser.ConditionExpr,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match expr {
    @parser.ConditionExpr::Unary(op, _, _) =>
      match op {
        "-n" =>
          push_diagnostic(
            diagnostics,
            span,
            CheckSeverity::Style,
            2237,
            "Use [ -z .. ] instead of ! [ -n .. ].",
          )
        "-z" =>
          push_diagnostic(
            diagnostics,
            span,
            CheckSeverity::Style,
            2237,
            "Use [ -n .. ] instead of ! [ -z .. ].",
          )
        _ => ()
      }
    @parser.ConditionExpr::Binary(op, _, _, _) =>
      match inverted_condition_operator(op) {
        Some(new_op) =>
          push_diagnostic(
            diagnostics,
            span,
            CheckSeverity::Style,
            2335,
            "Use " +
            condition_example(kind, "a " + new_op + " b") +
            " instead of ! " +
            condition_example(kind, "a " + op + " b") +
            ".",
          )
        None => ()
      }
    _ => ()
  }
}

///|
fn inverted_condition_operator(op : String) -> String? {
  match op {
    "=" | "==" => Some("!=")
    "!=" => Some("=")
    "-eq" => Some("-ne")
    "-ne" => Some("-eq")
    "-le" => Some("-gt")
    "-gt" => Some("-le")
    "-ge" => Some("-lt")
    "-lt" => Some("-ge")
    _ => None
  }
}

///|
fn condition_example(kind : @parser.ConditionKind, body : String) -> String {
  match kind {
    @parser.ConditionKind::SingleBracket => "[ " + body + " ]"
    @parser.ConditionKind::DoubleBracket => "[[ " + body + " ]]"
  }
}

///|
fn run_require_variable_braces_optional_check(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, place) {
      if place == WordPlace::CommandName {
        return
      }
      match first_unbraced_named_parameter(word) {
        Some(name) => {
          let fix = match word.parts {
            [@parser.WordPart::Parameter(single)] if single == name =>
              Some(replace_span_fix(word.span, "${" + name + "}"))
            _ => None
          }
          match fix {
            Some(fix) =>
              push_diagnostic_with_fix(
                diagnostics,
                word.span,
                CheckSeverity::Style,
                2250,
                "Prefer putting braces around variable references even when not strictly required.",
                fix,
              )
            None =>
              push_diagnostic(
                diagnostics,
                word.span,
                CheckSeverity::Style,
                2250,
                "Prefer putting braces around variable references even when not strictly required.",
              )
          }
        }
        None => ()
      }
    })
  })
}

///|
fn first_unbraced_named_parameter(word : @parser.Word) -> String? {
  for part in word.parts {
    match part {
      @parser.WordPart::Parameter(name) if is_identifier_name(name) =>
        return Some(name)
      _ => ()
    }
  }
  None
}

///|
fn run_require_double_brackets_optional_check(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell_is_one_of(shell, [
    @semantics.ShellDialect::Bash,
    @semantics.ShellDialect::Ksh,
    @semantics.ShellDialect::BusyboxSh,
  ]) else {
    return
  }
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(
        { kind: @parser.ConditionKind::SingleBracket, .. }
      ) =>
        push_diagnostic(
          diagnostics,
          command.span,
          CheckSeverity::Style,
          2292,
          "Prefer [[ ]] over [ ] for tests in Bash/Ksh/Busybox.",
        )
      _ => ()
    }
  })
}

///|
fn run_set_e_suppressed_optional_check(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard @semantics.has_set_e(script) else { return }
  let indexed = @semantics.build_index(script)
  let function_names : Array[String] = []
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Function(function_) =>
        push_unique_string(function_names, function_.name)
      _ => ()
    }
  })
  let inherit_errexit = @semantics.has_inherit_errexit(script, shell)
  for id in indexed_all_node_ids(indexed) {
    match @semantics.node_ref_of(indexed, id) {
      Some(@semantics.NodeRef::Command(command)) =>
        if command_is_function_invocation(command, function_names) &&
          !indexed_command_has_function_ancestor(indexed, id) {
          check_set_e_suppressed_context(
            indexed, id, command, inherit_errexit, diagnostics,
          )
        }
      _ => ()
    }
  }
}

///|
fn indexed_all_node_ids(
  indexed : @semantics.IndexedScript,
) -> Array[@semantics.NodeId] {
  let ids : Array[@semantics.NodeId] = [@semantics.root_id(indexed)]
  for id in @semantics.find_descendants(indexed, @semantics.root_id(indexed)) {
    ids.push(id)
  }
  ids
}

///|
fn command_is_function_invocation(
  command : @parser.Command,
  function_names : Array[String],
) -> Bool {
  match command.kind {
    @parser.CommandKind::Simple(_) =>
      match @semantics.command_name(command) {
        Some(name) => function_names.contains(name)
        None => false
      }
    _ => false
  }
}

///|
fn indexed_command_has_function_ancestor(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
) -> Bool {
  for ancestor in @semantics.find_ancestors(indexed, id) {
    match @semantics.node_ref_of(indexed, ancestor) {
      Some(@semantics.NodeRef::FunctionDef(_)) => return true
      _ => ()
    }
  }
  false
}

///|
fn check_set_e_suppressed_context(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
  command : @parser.Command,
  inherit_errexit : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut child = id
  let mut current = @semantics.parent_of(indexed, id)
  while current is Some(_) {
    let parent = match current {
      Some(parent) => parent
      None => break
    }
    match @semantics.node_ref_of(indexed, parent) {
      Some(@semantics.NodeRef::PipelineSegment(segment)) =>
        if segment.bangs % 2 != 0 && segment.command == command {
          push_diagnostic(
            diagnostics,
            effective_command_span(command),
            CheckSeverity::Info,
            2310,
            "This function is invoked in a ! condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.",
          )
          return
        }
      Some(@semantics.NodeRef::AndOrList(list)) =>
        match and_or_condition_type_for_span(list, command.span) {
          Some(cond_type) => {
            push_diagnostic(
              diagnostics,
              effective_command_span(command),
              CheckSeverity::Info,
              2310,
              "This function is invoked in " +
              cond_type +
              " so set -e will be disabled. Invoke separately if failures should cause the script to exit.",
            )
            return
          }
          None => ()
        }
      Some(@semantics.NodeRef::IfArm(arm)) =>
        if span_contains(arm.condition.span, command.span) {
          push_diagnostic(
            diagnostics,
            effective_command_span(command),
            CheckSeverity::Info,
            2310,
            "This function is invoked in an 'if' condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.",
          )
          return
        }
      Some(@semantics.NodeRef::LoopClause(clause)) =>
        if span_contains(clause.condition.span, command.span) {
          match @semantics.parent_of(indexed, parent) {
            Some(grandparent) =>
              match @semantics.node_ref_of(indexed, grandparent) {
                Some(
                  @semantics.NodeRef::Command(
                    { kind: @parser.CommandKind::While(_), .. }
                  )
                ) => {
                  push_diagnostic(
                    diagnostics,
                    effective_command_span(command),
                    CheckSeverity::Info,
                    2310,
                    "This function is invoked in a 'while' condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.",
                  )
                  return
                }
                Some(
                  @semantics.NodeRef::Command(
                    { kind: @parser.CommandKind::Until(_), .. }
                  )
                ) => {
                  push_diagnostic(
                    diagnostics,
                    effective_command_span(command),
                    CheckSeverity::Info,
                    2310,
                    "This function is invoked in an 'until' condition so set -e will be disabled. Invoke separately if failures should cause the script to exit.",
                  )
                  return
                }
                _ => ()
              }
            None => ()
          }
        }
      Some(
        @semantics.NodeRef::WordPart(@parser.WordPart::CommandSubstitution(_))
      )
      | Some(
        @semantics.NodeRef::WordPart(
          @parser.WordPart::BraceCommandSubstitution(_, _)
        )
      )
      | Some(@semantics.NodeRef::WordPart(@parser.WordPart::BackQuoted(_))) =>
        if !inherit_errexit &&
          substitution_child_needs_inherit_errexit(indexed, child) {
          push_diagnostic(
            diagnostics,
            effective_command_span(command),
            CheckSeverity::Info,
            2311,
            "Bash implicitly disabled set -e for this function invocation because it's inside a command substitution. Add set -e; before it or enable inherit_errexit.",
          )
          return
        }
      _ => ()
    }
    child = parent
    current = @semantics.parent_of(indexed, parent)
  }
}

///|
fn and_or_condition_type_for_span(
  list : @parser.AndOrList,
  span : @parser.Span,
) -> String? {
  if list.tail.length() == 0 {
    return None
  }
  if span_contains(list.head.span, span) {
    return Some(and_or_condition_label(list.tail[0].0))
  }
  let mut i = 0
  while i + 1 < list.tail.length() {
    let (_, pipeline) = list.tail[i]
    if span_contains(pipeline.span, span) {
      return Some(and_or_condition_label(list.tail[i + 1].0))
    }
    i += 1
  }
  None
}

///|
fn and_or_condition_label(op : @parser.AndOrOperator) -> String {
  match op {
    @parser.AndOrOperator::AndIf => "an && condition"
    @parser.AndOrOperator::OrIf => "an || condition"
  }
}

///|
fn substitution_child_needs_inherit_errexit(
  indexed : @semantics.IndexedScript,
  child : @semantics.NodeId,
) -> Bool {
  match @semantics.node_ref_of(indexed, child) {
    Some(@semantics.NodeRef::Script(script)) => !@semantics.has_set_e(script)
    _ => true
  }
}

///|
fn run_extra_masked_returns_optional_check(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_masked_pipeline_returns(script, diagnostics)
  visit_script_commands(script, fn(command) {
    check_masked_embedded_returns(command, diagnostics)
  })
}

///|
fn check_masked_pipeline_returns(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard !@semantics.has_pipefail(script) else { return }
  let indexed = @semantics.build_index(script)
  for id in indexed_all_node_ids(indexed) {
    match @semantics.node_ref_of(indexed, id) {
      Some(@semantics.NodeRef::Pipeline(pipeline)) =>
        if pipeline.segments.length() > 1 &&
          !pipeline_is_deliberately_ignored(indexed, id, pipeline) {
          let mut i = 0
          while i + 1 < pipeline.segments.length() {
            match single_maskable_command(pipeline.segments[i].command) {
              Some(command) =>
                maybe_push_masked_return_diagnostic(diagnostics, command)
              None => ()
            }
            i += 1
          }
        }
      _ => ()
    }
  }
}

///|
fn pipeline_is_deliberately_ignored(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
  pipeline : @parser.Pipeline,
) -> Bool {
  let mut current = @semantics.parent_of(indexed, id)
  while current is Some(_) {
    match current {
      Some(node_id) =>
        match @semantics.node_ref_of(indexed, node_id) {
          Some(@semantics.NodeRef::AndOrList(list)) =>
            if span_contains(list.head.span, pipeline.span) &&
              list.tail.length() > 0 &&
              list.tail[0].0 is @parser.AndOrOperator::OrIf &&
              pipeline_is_true_or_colon(list.tail[0].1) {
              return true
            } else {
              return false
            }
          _ => ()
        }
      None => ()
    }
    current = match current {
      Some(node_id) => @semantics.parent_of(indexed, node_id)
      None => None
    }
  }
  false
}

///|
fn pipeline_is_true_or_colon(pipeline : @parser.Pipeline) -> Bool {
  if pipeline.segments.length() != 1 {
    return false
  }
  match @semantics.command_name(pipeline.segments[0].command) {
    Some("true") | Some(":") => true
    _ => false
  }
}

///|
fn check_masked_embedded_returns(
  command : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match command.kind {
    @parser.CommandKind::Simple(simple) => {
      let masked : Array[@parser.Command] = []
      if simple.words.length() == 0 {
        collect_assignment_value_masked_commands(simple.assignments, masked)
        push_all_but_last_masked_commands(diagnostics, masked)
      } else {
        collect_assignment_value_masked_commands(simple.assignments, masked)
        collect_word_masked_commands(words_from(simple.words, 1), masked)
        collect_redirect_masked_commands(command.redirects, masked)
        push_all_masked_commands(diagnostics, masked)
      }
    }
    @parser.CommandKind::Source(source) => {
      let masked : Array[@parser.Command] = []
      collect_assignment_value_masked_commands(source.assignments, masked)
      collect_word_masked_commands(source.options, masked)
      collect_word_masked_commands([source.path], masked)
      collect_word_masked_commands(source.args, masked)
      collect_redirect_masked_commands(command.redirects, masked)
      push_all_masked_commands(diagnostics, masked)
    }
    @parser.CommandKind::Condition(condition) => {
      let masked : Array[@parser.Command] = []
      collect_condition_masked_commands(condition.expr, masked)
      push_all_masked_commands(diagnostics, masked)
    }
    _ => ()
  }
}

///|
fn collect_assignment_value_masked_commands(
  assignments : Array[@parser.Assignment],
  masked : Array[@parser.Command],
) -> Unit {
  for assignment in assignments {
    collect_assignment_value_embedded_commands(assignment.value, masked)
  }
}

///|
fn collect_assignment_value_embedded_commands(
  value : @parser.AssignmentValue,
  masked : Array[@parser.Command],
) -> Unit {
  match value {
    @parser.AssignmentValue::Empty => ()
    @parser.AssignmentValue::Word(word) =>
      collect_word_embedded_commands(word, masked)
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      for element in elements {
        collect_assignment_value_embedded_commands(element.value, masked)
      }
  }
}

///|
fn collect_word_masked_commands(
  words : Array[@parser.Word],
  masked : Array[@parser.Command],
) -> Unit {
  for word in words {
    collect_word_embedded_commands(word, masked)
  }
}

///|
fn collect_word_embedded_commands(
  word : @parser.Word,
  masked : Array[@parser.Command],
) -> Unit {
  walk_word_deep(word, fn(part) {
    match part {
      @parser.WordPart::CommandSubstitution(script)
      | @parser.WordPart::BraceCommandSubstitution(_, script)
      | @parser.WordPart::BackQuoted(script)
      | @parser.WordPart::ProcessSubstitution(_, script) =>
        match single_maskable_command_in_script(script) {
          Some(command) => masked.push(command)
          None => ()
        }
      _ => ()
    }
  })
}

///|
fn collect_redirect_masked_commands(
  redirects : Array[@parser.Redirection],
  masked : Array[@parser.Command],
) -> Unit {
  for redirect in redirects {
    match redirect.target {
      @parser.RedirectionTarget::Word(word) =>
        collect_word_embedded_commands(word, masked)
      @parser.RedirectionTarget::HereDoc({ parts: Some(parts), .. }) =>
        for part in parts {
          match part {
            @parser.WordPart::CommandSubstitution(script)
            | @parser.WordPart::BraceCommandSubstitution(_, script)
            | @parser.WordPart::BackQuoted(script)
            | @parser.WordPart::ProcessSubstitution(_, script) =>
              match single_maskable_command_in_script(script) {
                Some(command) => masked.push(command)
                None => ()
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
}

///|
fn collect_condition_masked_commands(
  expr : @parser.ConditionExpr,
  masked : Array[@parser.Command],
) -> Unit {
  match expr {
    @parser.ConditionExpr::Empty => ()
    @parser.ConditionExpr::Word(word)
    | @parser.ConditionExpr::Unary(_, _, word) =>
      collect_word_embedded_commands(word, masked)
    @parser.ConditionExpr::Binary(_, _, lhs, rhs) => {
      collect_word_embedded_commands(lhs, masked)
      collect_word_embedded_commands(rhs, masked)
    }
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      collect_condition_masked_commands(inner, masked)
    @parser.ConditionExpr::And(_, lhs, rhs)
    | @parser.ConditionExpr::Or(_, lhs, rhs) => {
      collect_condition_masked_commands(lhs, masked)
      collect_condition_masked_commands(rhs, masked)
    }
  }
}

///|
fn single_maskable_command_in_script(
  script : @parser.Script,
) -> @parser.Command? {
  guard script.items.length() == 1 else { return None }
  let item = script.items[0]
  guard item.and_or.tail.length() == 0 else { return None }
  guard item.and_or.head.segments.length() == 1 else { return None }
  single_maskable_command(item.and_or.head.segments[0].command)
}

///|
fn single_maskable_command(command : @parser.Command) -> @parser.Command? {
  match command.kind {
    @parser.CommandKind::Time(clause) =>
      if clause.body.segments.length() == 1 {
        single_maskable_command(clause.body.segments[0].command)
      } else {
        None
      }
    _ =>
      if masked_return_command_is_harmless(command) {
        None
      } else {
        Some(command)
      }
  }
}

///|
fn masked_return_command_is_harmless(command : @parser.Command) -> Bool {
  match @semantics.command_name(command) {
    Some("echo")
    | Some("basename")
    | Some("dirname")
    | Some("printf")
    | Some("set")
    | Some("shopt")
    | Some(":") => true
    _ =>
      match @semantics.command_basename(command) {
        Some("echo")
        | Some("basename")
        | Some("dirname")
        | Some("printf")
        | Some("set")
        | Some("shopt") => true
        _ => false
      }
  }
}

///|
fn push_all_masked_commands(
  diagnostics : Array[CheckDiagnostic],
  masked : Array[@parser.Command],
) -> Unit {
  for command in masked {
    maybe_push_masked_return_diagnostic(diagnostics, command)
  }
}

///|
fn push_all_but_last_masked_commands(
  diagnostics : Array[CheckDiagnostic],
  masked : Array[@parser.Command],
) -> Unit {
  if masked.length() <= 1 {
    return
  }
  let mut i = 0
  while i + 1 < masked.length() {
    maybe_push_masked_return_diagnostic(diagnostics, masked[i])
    i += 1
  }
}

///|
fn maybe_push_masked_return_diagnostic(
  diagnostics : Array[CheckDiagnostic],
  command : @parser.Command,
) -> Unit {
  if diagnostics.any(fn(existing) {
      existing.code == 2312 && existing.span == effective_command_span(command)
    }) {
    return
  }
  push_diagnostic(
    diagnostics,
    effective_command_span(command),
    CheckSeverity::Info,
    2312,
    "Consider invoking this command separately to avoid masking its return value (or use '|| true' to ignore).",
  )
}

///|
fn words_from(words : Array[@parser.Word], start : Int) -> Array[@parser.Word] {
  let rest : Array[@parser.Word] = []
  let mut i = start
  while i < words.length() {
    rest.push(words[i])
    i += 1
  }
  rest
}
