///|
fn append_analytics_batch_d_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_d_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_d_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2032,
      severity: Info,
      category: "analytics",
      summary: "Shell functions and aliases cannot be dispatched by external commands.",
    },
    {
      code: 2033,
      severity: Warning,
      category: "analytics",
      summary: "Shell functions and aliases cannot be passed to external commands as commands.",
    },
    {
      code: 2119,
      severity: Info,
      category: "analytics",
      summary: "Calls without arguments should pass \"$@\" when the function reads positional parameters.",
    },
    {
      code: 2096,
      severity: Error,
      category: "analytics",
      summary: "Most shebang implementations only allow one interpreter argument.",
    },
    {
      code: 2104,
      severity: Error,
      category: "analytics",
      summary: "Functions should use return instead of break/continue outside loops.",
    },
    {
      code: 2105,
      severity: Error,
      category: "analytics",
      summary: "break and continue are only valid in loops.",
    },
    {
      code: 2106,
      severity: Warning,
      category: "analytics",
      summary: "break/continue in subshell-like contexts only affect that subshell.",
    },
    {
      code: 2111,
      severity: Error,
      category: "analytics",
      summary: "ksh does not allow the function keyword together with parentheses.",
    },
    {
      code: 2112,
      severity: Warning,
      category: "analytics",
      summary: "The function keyword is non-standard when used with parentheses.",
    },
    {
      code: 2113,
      severity: Warning,
      category: "analytics",
      summary: "The function keyword is non-standard without parentheses.",
    },
    {
      code: 2118,
      severity: Error,
      category: "analytics",
      summary: "ksh does not support |& pipelines.",
    },
    {
      code: 2120,
      severity: Warning,
      category: "analytics",
      summary: "Function references positional parameters but is only invoked without arguments.",
    },
    {
      code: 2127,
      severity: Error,
      category: "analytics",
      summary: "Shell-specific syntax needs an explicit shell that supports it.",
    },
    {
      code: 2103,
      severity: Info,
      category: "analytics",
      summary: "Prefer a subshell over manually cd'ing back afterward.",
    },
    {
      code: 2164,
      severity: Warning,
      category: "analytics",
      summary: "cd/pushd/popd should be guarded with || exit/return unless failure is already handled.",
    },
    {
      code: 2165,
      severity: Warning,
      category: "analytics",
      summary: "Nested loops should not reuse a parent loop variable.",
    },
    {
      code: 2167,
      severity: Warning,
      category: "analytics",
      summary: "Parent loop variable is overridden by a nested loop.",
    },
    {
      code: 2262,
      severity: Warning,
      category: "analytics",
      summary: "Aliases defined in a parsing unit are not available later in that same parsing unit.",
    },
    {
      code: 2263,
      severity: Info,
      category: "analytics",
      summary: "This command does not see the alias defined earlier in the same parsing unit.",
    },
    {
      code: 2302,
      severity: Warning,
      category: "analytics",
      summary: "Looping over array values should not be combined with using those values as array keys.",
    },
    {
      code: 2303,
      severity: Warning,
      category: "analytics",
      summary: "Array values are not array keys.",
    },
  ]
}

///|
fn run_analytics_batch_d_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_shebang_parameters_d(script, diagnostics)
  check_loop_keyword_scope(script, shell, diagnostics)
  check_function_declarations(script, shell, diagnostics)
  check_stderr_pipe_ksh(script, shell, diagnostics)
  check_unsupported_features_d(script, shell, diagnostics)
  check_functions_used_externally(script, diagnostics)
  check_unpassed_in_functions(script, diagnostics)
  check_cd_and_back(script, diagnostics)
  check_unchecked_cd_pushd_popd(script, diagnostics)
  check_loop_variable_reassignment(script, diagnostics)
  check_alias_used_in_same_parsing_unit(script, diagnostics)
  check_array_value_used_as_index(script, diagnostics)
}

///|
priv struct AnalyticsFunctionInfo {
  declaration_span : @parser.Span
}

///|
priv enum DLoopKeywordScopeKind {
  Loop
  Function
  Subshell(String)
}

///|
fn check_shebang_parameters_d(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match script.shebang {
    Some(shebang) =>
      if d_shebang_has_multiple_parameters(shebang) {
        push_diagnostic(
          diagnostics,
          d_shebang_span(script, shebang),
          Error,
          2096,
          "On most OS, shebangs can only specify a single parameter.",
        )
      }
    None => ()
  }
}

///|
fn d_shebang_has_multiple_parameters(shebang : String) -> Bool {
  let words = d_split_shell_words(d_shebang_command_text(shebang))
  words.length() > 2 && !d_shebang_uses_env_split_string(words)
}

///|
fn d_shebang_uses_env_split_string(words : Array[String]) -> Bool {
  match words.get(0) {
    Some(first) if analytics_path_basename(d_unquote_shebang_word(first)) ==
      "env" => {
      let mut i = 1
      while i < words.length() {
        let arg = d_unquote_shebang_word(words[i])
        if arg == "-S" ||
          arg == "--split-string" ||
          arg.has_prefix("--split-string=") {
          return true
        }
        i += 1
      }
      false
    }
    _ => false
  }
}

///|
fn d_shebang_span(script : @parser.Script, shebang : String) -> @parser.Span {
  let start = if script.has_bom {
    @parser.Position::new(1, 1, 2)
  } else {
    @parser.Position::new(0, 1, 1)
  }
  @parser.Span::new(
    start,
    @parser.Position::new(
      start.offset + shebang.length(),
      1,
      start.column + shebang.length(),
    ),
  )
}

///|
fn d_shebang_command_text(shebang : String) -> String {
  if shebang.has_prefix("#!") {
    d_trim_ascii_space(shebang.view(start_offset=2).to_owned())
  } else {
    d_trim_ascii_space(shebang)
  }
}

///|
fn d_trim_ascii_space(text : String) -> String {
  let view = text[:]
  let mut start = 0
  while start < view.length() &&
        (view[start] == ' ' || view[start] == '\t' || view[start] == '\r') {
    start += 1
  }
  let mut end_ = view.length()
  while end_ > start &&
        (
          view[end_ - 1] == ' ' ||
          view[end_ - 1] == '\t' ||
          view[end_ - 1] == '\r'
        ) {
    end_ -= 1
  }
  text.view(start_offset=start, end_offset=end_).to_owned()
}

///|
fn d_split_shell_words(text : String) -> Array[String] {
  let values : Array[String] = []
  let current = StringBuilder::new()
  let view = text[:]
  let mut i = 0
  let mut quote : UInt16? = None
  while i < view.length() {
    let ch = view[i]
    match quote {
      Some(current_quote) => {
        current.write_char(ch.unsafe_to_char())
        if ch == '\\' && current_quote == '"' && i + 1 < view.length() {
          i += 1
          current.write_char(view[i].unsafe_to_char())
        } else if ch == current_quote {
          quote = None
        }
      }
      None =>
        if ch == ' ' || ch == '\t' {
          let item = current.to_string()
          if item != "" {
            values.push(item)
            current.reset()
          }
        } else {
          current.write_char(ch.unsafe_to_char())
          if ch == '\\' && i + 1 < view.length() {
            i += 1
            current.write_char(view[i].unsafe_to_char())
          } else if ch == '\'' || ch == '"' {
            quote = Some(ch)
          }
        }
    }
    i += 1
  }
  let tail = current.to_string()
  if tail != "" {
    values.push(tail)
  }
  values
}

///|
fn d_unquote_shebang_word(raw : String) -> String {
  let view = raw[:]
  if view.length() >= 2 &&
    (
      (view[0] == '\'' && view[view.length() - 1] == '\'') ||
      (view[0] == '"' && view[view.length() - 1] == '"')
    ) {
    raw.view(start_offset=1, end_offset=view.length() - 1).to_owned()
  } else {
    raw
  }
}

///|
fn check_loop_keyword_scope(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let indexed = @semantics.build_index(script)
  let lastpipe = @semantics.has_lastpipe(script, shell)
  for id in indexed_all_node_ids(indexed) {
    match @semantics.node_ref_of(indexed, id) {
      Some(Command(command)) =>
        match d_loop_keyword_name(command) {
          Some(name) =>
            d_check_loop_keyword_command(
              indexed, id, command, name, lastpipe, diagnostics,
            )
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn d_loop_keyword_name(command : @parser.Command) -> String? {
  match command.kind {
    Simple(simple) =>
      match simple.words.get(0) {
        Some(word) =>
          match word_single_literal_text(word) {
            Some(name) if name == "break" || name == "continue" => Some(name)
            _ => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn d_check_loop_keyword_command(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
  command : @parser.Command,
  name : String,
  lastpipe : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let scopes = d_collect_loop_keyword_scopes(indexed, id, lastpipe)
  if d_loop_keyword_scopes_have_loop(scopes) {
    match d_first_loop_keyword_subshell_scope(scopes) {
      Some(reason) =>
        push_diagnostic(
          diagnostics,
          command.span,
          Warning,
          2106,
          "This only exits the subshell caused by the \{reason}.",
        )
      None => ()
    }
    return
  }

  match scopes.get(0) {
    Some(Function) =>
      push_diagnostic(
        diagnostics,
        command.span,
        Error,
        2104,
        "In functions, use return instead of \{name}.",
      )
    _ =>
      push_diagnostic(
        diagnostics,
        command.span,
        Error,
        2105,
        "\{name} is only valid in loops.",
      )
  }
}

///|
fn d_collect_loop_keyword_scopes(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
  lastpipe : Bool,
) -> Array[DLoopKeywordScopeKind] {
  let scopes : Array[DLoopKeywordScopeKind] = []
  for ancestor in @semantics.find_ancestors(indexed, id) {
    match d_loop_keyword_scope_kind_for_ancestor(indexed, ancestor, lastpipe) {
      Some(scope) => scopes.push(scope)
      None => ()
    }
  }
  scopes
}

///|
fn d_loop_keyword_scope_kind_for_ancestor(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
  lastpipe : Bool,
) -> DLoopKeywordScopeKind? {
  match @semantics.node_ref_of(indexed, id) {
    Some(ListItem(item)) =>
      match item.terminator {
        Some(Background) => Some(Subshell("backgrounding &"))
        _ => None
      }
    Some(FunctionDef(_)) => Some(Function)
    Some(LoopClause(_))
    | Some(ForClause(_))
    | Some(ArithmeticForClause(_))
    | Some(SelectClause(_)) => Some(Loop)
    Some(CoProcClause(_)) => Some(Subshell("coproc"))
    Some(BatsTestClause(_)) => Some(Subshell("@bats test"))
    Some(Command(command)) =>
      match command.kind {
        Function(_) => Some(Function)
        While(_) | Until(_) | ForIn(_) | ForArithmetic(_) | Select(_) =>
          Some(Loop)
        Subshell(_) => Some(Subshell("(..) group"))
        BatsTest(_) => Some(Subshell("@bats test"))
        _ =>
          if d_command_is_coproc_body(indexed, id) {
            Some(Subshell("coproc"))
          } else if d_command_is_pipeline_subshell(indexed, id, lastpipe) {
            Some(Subshell("pipeline"))
          } else {
            None
          }
      }
    Some(WordPart(CommandSubstitution(_)))
    | Some(WordPart(BraceCommandSubstitution(_, _))) =>
      Some(Subshell("$(..) expansion"))
    Some(WordPart(BackQuoted(_))) => Some(Subshell("`..` expansion"))
    _ => None
  }
}

///|
fn d_loop_keyword_scopes_have_loop(
  scopes : Array[DLoopKeywordScopeKind],
) -> Bool {
  scopes.any(fn(scope) {
    match scope {
      Loop => true
      _ => false
    }
  })
}

///|
fn d_first_loop_keyword_subshell_scope(
  scopes : Array[DLoopKeywordScopeKind],
) -> String? {
  for scope in scopes {
    match scope {
      Subshell(reason) => return Some(reason)
      _ => ()
    }
  }
  None
}

///|
fn d_command_is_coproc_body(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
) -> Bool {
  match @semantics.parent_of(indexed, id) {
    Some(parent) =>
      match @semantics.node_ref_of(indexed, parent) {
        Some(CoProcClause(_)) => true
        _ => false
      }
    None => false
  }
}

///|
fn d_command_is_pipeline_subshell(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
  lastpipe : Bool,
) -> Bool {
  let segment_id = match @semantics.parent_of(indexed, id) {
    Some(parent) =>
      match @semantics.node_ref_of(indexed, parent) {
        Some(PipelineSegment(_)) => parent
        _ => return false
      }
    None => return false
  }
  let pipeline_id = match @semantics.parent_of(indexed, segment_id) {
    Some(parent) =>
      match @semantics.node_ref_of(indexed, parent) {
        Some(Pipeline(pipeline)) =>
          if pipeline.segments.length() > 1 {
            parent
          } else {
            return false
          }
        _ => return false
      }
    None => return false
  }
  if !lastpipe {
    return true
  }
  let segment_ids = d_pipeline_segment_ids(indexed, pipeline_id)
  match segment_ids.get(segment_ids.length() - 1) {
    Some(last_segment) => last_segment != segment_id
    None => false
  }
}

///|
fn d_pipeline_segment_ids(
  indexed : @semantics.IndexedScript,
  pipeline_id : @semantics.NodeId,
) -> Array[@semantics.NodeId] {
  let ids : Array[@semantics.NodeId] = []
  for child in @semantics.children_of(indexed, pipeline_id) {
    match @semantics.node_ref_of(indexed, child) {
      Some(PipelineSegment(_)) => ids.push(child)
      _ => ()
    }
  }
  ids
}

///|
fn check_function_declarations(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      Function(function_) =>
        d_maybe_warn_function_declaration(
          command, function_, shell, diagnostics,
        )
      _ => ()
    }
  })
}

///|
fn d_maybe_warn_function_declaration(
  command : @parser.Command,
  function_ : @parser.FunctionDef,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if !function_.uses_keyword {
    return
  }
  if shell == Ksh {
    if function_.has_parentheses {
      push_diagnostic(
        diagnostics,
        command.span,
        Error,
        2111,
        "ksh does not allow 'function' keyword and '()' at the same time.",
      )
    }
    return
  }
  if !shell_is_posix_sh(shell) {
    return
  }
  if function_.has_parentheses {
    push_diagnostic(
      diagnostics,
      command.span,
      Warning,
      2112,
      "'function' keyword is non-standard. Delete it.",
    )
  } else {
    push_diagnostic(
      diagnostics,
      command.span,
      Warning,
      2113,
      "'function' keyword is non-standard. Use 'foo()' instead of 'function foo'.",
    )
  }
}

///|
fn check_stderr_pipe_ksh(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard shell == Ksh else { return }
  visit_script_pipelines(script, fn(pipeline) {
    let mut i = 0
    while i < pipeline.operators.length() {
      match pipeline.operators[i] {
        PipeAndStderr =>
          push_diagnostic(
            diagnostics,
            pipe_operator_span(pipeline, i, 2),
            Error,
            2118,
            "Ksh does not support |&. Use 2>&1 |.",
          )
        _ => ()
      }
      i += 1
    }
  })
}

///|
fn check_functions_used_externally(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let definitions : Map[String, AnalyticsFunctionInfo] = Map([])
  collect_function_and_alias_definitions(script, definitions)
  visit_script_commands(script, fn(command) {
    let effective_name = match @semantics.effective_command_name(command) {
      Some(name) => analytics_path_basename(name)
      None => return
    }
    let candidates = analytics_external_command_candidate_words(
      effective_name,
      @semantics.effective_command_arguments(command),
    )
    for candidate in candidates {
      match word_single_literal_text(candidate) {
        Some(name) =>
          match definitions.get(name) {
            Some(info) => {
              push_diagnostic(
                diagnostics,
                candidate.span,
                Warning,
                2033,
                "Shell functions can't be passed to external commands. Use separate script or sh -c.",
              )
              push_diagnostic(
                diagnostics,
                info.declaration_span,
                Info,
                2032,
                "This function can't be invoked via \{effective_name}\{analytics_line_context(command.span.start.line)}",
              )
            }
            None => ()
          }
        None => ()
      }
    }
  })
}

///|
fn collect_function_and_alias_definitions(
  script : @parser.Script,
  definitions : Map[String, AnalyticsFunctionInfo],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      Function(function_) =>
        if !definitions.contains(function_.name) {
          definitions.set(function_.name, {
            declaration_span: function_definition_report_span(
              command, function_,
            ),
          })
        }
      Simple(_) =>
        if @semantics.effective_command_name(command) == Some("alias") {
          for argument in @semantics.effective_command_arguments(command) {
            match analytics_alias_definition_name(argument) {
              Some(name) =>
                if !definitions.contains(name) {
                  definitions.set(name, { declaration_span: argument.span })
                }
              None => ()
            }
          }
        }
      _ => ()
    }
  })
}

///|
fn function_definition_report_span(
  command : @parser.Command,
  function_ : @parser.FunctionDef,
) -> @parser.Span {
  if function_.uses_keyword {
    command_keyword_span(command, "function")
  } else {
    span_prefix(command.span, function_.name[:].length())
  }
}

///|
fn analytics_alias_definition_name(word : @parser.Word) -> String? {
  let view = word.source[:]
  let mut i = 0
  while i < view.length() && view[i] != '=' {
    i += 1
  }
  guard i > 0 && i < view.length() else { return None }
  let name = word.source.view(end_offset=i).to_owned()
  if analytics_is_identifier_name(name) {
    Some(name)
  } else {
    None
  }
}

///|
fn analytics_external_command_candidate_words(
  command_name : String,
  arguments : Array[@parser.Word],
) -> Array[@parser.Word] {
  let candidates : Array[@parser.Word] = []
  let start = analytics_drop_flag_words(arguments)
  match command_name {
    "chroot" | "doas" | "run0" | "screen" | "sudo" | "tmux" | "xargs" =>
      analytics_push_word_at(arguments, start, candidates)
    "timeout" | "ssh" =>
      analytics_push_word_at(arguments, start + 1, candidates)
    "find" => {
      let mut i = 0
      while i + 1 < arguments.length() {
        let flag = match @semantics.literal_text(arguments[i]) {
          Some(text) => text
          None => ""
        }
        if ["-exec", "-execdir", "-ok", "-okdir"].contains(flag) {
          candidates.push(arguments[i + 1])
          break
        }
        i += 1
      }
    }
    _ => ()
  }
  candidates
}

///|
fn analytics_drop_flag_words(arguments : Array[@parser.Word]) -> Int {
  let mut i = 0
  while i < arguments.length() {
    match @semantics.literal_text(arguments[i]) {
      Some(text) if text.has_prefix("-") => i += 1
      _ => return i
    }
  }
  i
}

///|
fn analytics_push_word_at(
  values : Array[@parser.Word],
  index : Int,
  out : Array[@parser.Word],
) -> Unit {
  match values.get(index) {
    Some(value) => out.push(value)
    None => ()
  }
}

///|
fn analytics_path_basename(path : String) -> String {
  let view = path[:]
  let mut start = 0
  let mut i = 0
  while i < view.length() {
    if view[i] == '/' {
      start = i + 1
    }
    i += 1
  }
  path.view(start_offset=start).to_owned()
}

///|
fn analytics_line_context(line : Int) -> String {
  " on line \{line}."
}

///|
priv struct AnalyticsUnpassedCall {
  span : @parser.Span
  argless : Bool
}

///|
fn check_unpassed_in_functions(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let functions : Map[String, AnalyticsFunctionInfo] = Map([])
  collect_unpassed_function_candidates(script, functions)

  let calls : Map[String, Array[AnalyticsUnpassedCall]] = Map([])
  visit_script_commands(script, fn(command) {
    let name = match direct_simple_command_name(command) {
      Some(name) => name
      None => return
    }
    guard functions.contains(name) else { return }
    let group = match calls.get(name) {
      Some(existing) => existing
      None => {
        let created : Array[AnalyticsUnpassedCall] = []
        calls.set(name, created)
        created
      }
    }
    group.push({
      span: effective_command_span(command),
      argless: @semantics.command_arguments(command).length() == 0,
    })
  })

  functions.each(fn(name, info) {
    match calls.get(name) {
      Some(group) if group.length() > 0 &&
        group.all(fn(call) { call.argless }) &&
        !annotations_disable_code_at_position(
          script,
          info.declaration_span.start,
          2120,
        ) => {
        for call in group {
          push_diagnostic(
            diagnostics,
            call.span,
            Info,
            2119,
            "Use \{name} \"$@\" if function's $1 should mean script's $1.",
          )
        }
        push_diagnostic(
          diagnostics,
          info.declaration_span,
          Warning,
          2120,
          "\{name} references arguments, but none are ever passed.",
        )
      }
      _ => ()
    }
  })
}

///|
fn collect_unpassed_function_candidates(
  script : @parser.Script,
  functions : Map[String, AnalyticsFunctionInfo],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      Function(function_) =>
        if !functions.contains(function_.name) &&
          function_directly_references_positional_arguments(function_.body) &&
          !function_sets_positional_arguments(function_.body) {
          functions.set(function_.name, {
            declaration_span: function_definition_report_span(
              command, function_,
            ),
          })
        }
      _ => ()
    }
  })
}

///|
fn direct_simple_command_name(command : @parser.Command) -> String? {
  match command.kind {
    Simple(simple) =>
      match simple.words.get(0) {
        Some(word) => word_single_literal_text(word)
        None => None
      }
    _ => None
  }
}

///|
fn function_directly_references_positional_arguments(
  body : @parser.Command,
) -> Bool {
  let mut found = false
  analytics_walk_command_ignoring_nested_functions(body, fn(command) {
    if found {
      return
    }
    visit_direct_words_in_command(command, fn(word, _) {
      if found {
        return
      }
      if word_contains_direct_positional_reference(word) {
        found = true
      }
    })
  })
  found
}

///|
fn function_sets_positional_arguments(body : @parser.Command) -> Bool {
  let mut found = false
  analytics_walk_command_ignoring_nested_functions(body, fn(command) {
    if found {
      return
    }
    if command_sets_positional_arguments(command) {
      found = true
    }
  })
  found
}

///|
fn analytics_walk_command_ignoring_nested_functions(
  command : @parser.Command,
  visit : (@parser.Command) -> Unit,
) -> Unit {
  visit(command)
  match command.kind {
    Time(clause) =>
      analytics_walk_pipeline_ignoring_nested_functions(clause.body, visit)
    Subshell(script) | BraceGroup(script) =>
      analytics_walk_script_ignoring_nested_functions(script, visit)
    If(clause) => {
      for arm in clause.arms {
        analytics_walk_script_ignoring_nested_functions(arm.condition, visit)
        analytics_walk_script_ignoring_nested_functions(arm.body, visit)
      }
      match clause.else_body {
        Some(body) =>
          analytics_walk_script_ignoring_nested_functions(body, visit)
        None => ()
      }
    }
    While(clause) | Until(clause) => {
      analytics_walk_script_ignoring_nested_functions(clause.condition, visit)
      analytics_walk_script_ignoring_nested_functions(clause.body, visit)
    }
    ForIn(clause) =>
      analytics_walk_script_ignoring_nested_functions(clause.body, visit)
    ForArithmetic(clause) =>
      analytics_walk_script_ignoring_nested_functions(clause.body, visit)
    Select(clause) =>
      analytics_walk_script_ignoring_nested_functions(clause.body, visit)
    Case(clause) =>
      for item in clause.items {
        analytics_walk_script_ignoring_nested_functions(item.body, visit)
      }
    Function(_)
    | BatsTest(_)
    | Simple(_)
    | Source(_)
    | Condition(_)
    | Arithmetic(_) => ()
    CoProc(clause) =>
      analytics_walk_command_ignoring_nested_functions(clause.body, visit)
  }
}

///|
fn analytics_walk_script_ignoring_nested_functions(
  script : @parser.Script,
  visit : (@parser.Command) -> Unit,
) -> Unit {
  for item in script.items {
    analytics_walk_pipeline_ignoring_nested_functions(item.and_or.head, visit)
    for pair in item.and_or.tail {
      let (_, pipeline) = pair
      analytics_walk_pipeline_ignoring_nested_functions(pipeline, visit)
    }
  }
}

///|
fn analytics_walk_pipeline_ignoring_nested_functions(
  pipeline : @parser.Pipeline,
  visit : (@parser.Command) -> Unit,
) -> Unit {
  for segment in pipeline.segments {
    analytics_walk_command_ignoring_nested_functions(segment.command, visit)
  }
}

///|
fn word_contains_direct_positional_reference(word : @parser.Word) -> Bool {
  let mut found = false
  walk_word_deep(word, fn(part) {
    if found {
      return
    }
    match part {
      Parameter(name) | SpecialParameter(name) =>
        if analytics_is_positional_parameter(name) {
          found = true
        }
      BracedParameter(expansion) =>
        match expansion.name {
          Some(name) =>
            if analytics_is_positional_parameter(name) &&
              !parameter_expansion_allows_unset(expansion) {
              found = true
            }
          None => ()
        }
      _ => ()
    }
  })
  found
}

///|
fn analytics_is_positional_parameter(name : String) -> Bool {
  if name == "*" || name == "@" || name == "#" {
    return true
  }
  if name == "" || name == "0" {
    return false
  }
  let view = name[:]
  let mut i = 0
  while i < view.length() {
    if view[i] < '0' || view[i] > '9' {
      return false
    }
    i += 1
  }
  true
}

///|
fn command_sets_positional_arguments(command : @parser.Command) -> Bool {
  guard @semantics.effective_command_name(command) == Some("set") else {
    return false
  }
  for argument in @semantics.effective_command_arguments(command) {
    if word_single_literal_text(argument) == Some("--") {
      return true
    }
  }
  false
}

///|
fn check_unchecked_cd_pushd_popd(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if @semantics.has_set_e(script) {
    return
  }
  analytics_visit_script_for_cd_guards(script, false, diagnostics)
}

///|
priv struct AnalyticsCdBackCandidate {
  command : @parser.Command
  reverts : Bool
}

///|
fn check_cd_and_back(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if @semantics.has_set_e(script) {
    return
  }
  d_visit_script_for_cd_back(script, diagnostics)
}

///|
fn d_visit_script_for_cd_back(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let candidates : Array[AnalyticsCdBackCandidate] = []
  for item in script.items {
    match d_cd_back_candidate(item) {
      Some(candidate) => candidates.push(candidate)
      None => ()
    }
  }
  d_emit_cd_back_warning(candidates, diagnostics)

  for item in script.items {
    d_visit_and_or_for_cd_back(item.and_or, diagnostics)
  }
}

///|
fn d_cd_back_candidate(item : @parser.ListItem) -> AnalyticsCdBackCandidate? {
  guard item.and_or.tail.length() == 0 else { return None }
  let pipeline = item.and_or.head
  guard pipeline.segments.length() == 1 else { return None }
  let command = pipeline.segments[0].command
  guard @semantics.effective_command_name(command) == Some("cd") else {
    return None
  }
  Some({ command, reverts: d_cd_command_is_revert(command) })
}

///|
fn d_cd_command_is_revert(command : @parser.Command) -> Bool {
  let args = @semantics.effective_command_arguments(command)
  guard args.length() == 1 else { return false }
  match @semantics.literal_text(args[0]) {
    Some("..") | Some("-") => true
    _ => false
  }
}

///|
fn d_emit_cd_back_warning(
  candidates : Array[AnalyticsCdBackCandidate],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut i = 1
  while i < candidates.length() {
    if candidates[i].reverts && !candidates[i - 1].reverts {
      push_diagnostic(
        diagnostics,
        candidates[i].command.span,
        Info,
        2103,
        "Use a ( subshell ) to avoid having to cd back.",
      )
      return
    }
    i += 1
  }
}

///|
fn d_visit_and_or_for_cd_back(
  list : @parser.AndOrList,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  d_visit_pipeline_for_cd_back(list.head, diagnostics)
  for pair in list.tail {
    let (_, pipeline) = pair
    d_visit_pipeline_for_cd_back(pipeline, diagnostics)
  }
}

///|
fn d_visit_pipeline_for_cd_back(
  pipeline : @parser.Pipeline,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for segment in pipeline.segments {
    d_visit_command_for_cd_back(segment.command, diagnostics)
  }
}

///|
fn d_visit_command_for_cd_back(
  command : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match command.kind {
    Time(clause) => d_visit_pipeline_for_cd_back(clause.body, diagnostics)
    Subshell(script) | BraceGroup(script) | BatsTest({ body: script, .. }) =>
      d_visit_script_for_cd_back(script, diagnostics)
    If(clause) => {
      for arm in clause.arms {
        d_visit_script_for_cd_back(arm.condition, diagnostics)
        d_visit_script_for_cd_back(arm.body, diagnostics)
      }
      match clause.else_body {
        Some(body) => d_visit_script_for_cd_back(body, diagnostics)
        None => ()
      }
    }
    While(clause) | Until(clause) => {
      d_visit_script_for_cd_back(clause.condition, diagnostics)
      d_visit_script_for_cd_back(clause.body, diagnostics)
    }
    ForIn(clause) => d_visit_script_for_cd_back(clause.body, diagnostics)
    ForArithmetic(clause) =>
      d_visit_script_for_cd_back(clause.body, diagnostics)
    Select(clause) => d_visit_script_for_cd_back(clause.body, diagnostics)
    Case(clause) =>
      for item in clause.items {
        d_visit_script_for_cd_back(item.body, diagnostics)
      }
    Function(function_) =>
      d_visit_command_for_cd_back(function_.body, diagnostics)
    CoProc(clause) => d_visit_command_for_cd_back(clause.body, diagnostics)
    Simple(_) | Source(_) | Condition(_) | Arithmetic(_) => ()
  }
}

///|
fn analytics_visit_script_for_cd_guards(
  script : @parser.Script,
  in_condition : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for item in script.items {
    analytics_visit_and_or_for_cd_guards(item.and_or, in_condition, diagnostics)
  }
}

///|
fn analytics_visit_and_or_for_cd_guards(
  list : @parser.AndOrList,
  in_condition : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let pipelines : Array[@parser.Pipeline] = [list.head]
  for pair in list.tail {
    let (_, pipeline) = pair
    pipelines.push(pipeline)
  }
  let operators : Array[@parser.AndOrOperator] = []
  for pair in list.tail {
    let (op, _) = pair
    operators.push(op)
  }
  let mut i = 0
  while i < pipelines.length() {
    let guarded = analytics_pipeline_has_or_exit_guard(pipelines, operators, i)
    analytics_visit_pipeline_for_cd_guards(
      pipelines[i],
      in_condition,
      guarded,
      diagnostics,
    )
    i += 1
  }
}

///|
fn analytics_pipeline_has_or_exit_guard(
  pipelines : Array[@parser.Pipeline],
  operators : Array[@parser.AndOrOperator],
  index : Int,
) -> Bool {
  if index >= operators.length() {
    return false
  }
  match operators[index] {
    OrIf => ()
    _ => return false
  }
  match pipelines.get(index + 1) {
    Some(pipeline) => pipeline_is_exit_or_return_guard(pipeline)
    None => false
  }
}

///|
fn pipeline_is_exit_or_return_guard(pipeline : @parser.Pipeline) -> Bool {
  match pipeline.segments {
    [{ command, .. }] =>
      match @semantics.effective_command_name(command) {
        Some("exit") | Some("return") => true
        _ => false
      }
    _ => false
  }
}

///|
fn analytics_visit_pipeline_for_cd_guards(
  pipeline : @parser.Pipeline,
  in_condition : Bool,
  guarded : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for segment in pipeline.segments {
    analytics_visit_command_for_cd_guards(
      segment.command,
      in_condition,
      guarded,
      diagnostics,
    )
  }
}

///|
fn analytics_visit_command_for_cd_guards(
  command : @parser.Command,
  in_condition : Bool,
  guarded : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  analytics_maybe_warn_unchecked_dir_change(
    command, in_condition, guarded, diagnostics,
  )
  match command.kind {
    Time(clause) =>
      analytics_visit_pipeline_for_cd_guards(
        clause.body,
        in_condition,
        guarded,
        diagnostics,
      )
    Subshell(script) | BraceGroup(script) | BatsTest({ body: script, .. }) =>
      analytics_visit_script_for_cd_guards(script, in_condition, diagnostics)
    If(clause) => {
      for arm in clause.arms {
        analytics_visit_script_for_cd_guards(arm.condition, true, diagnostics)
        analytics_visit_script_for_cd_guards(arm.body, false, diagnostics)
      }
      match clause.else_body {
        Some(body) =>
          analytics_visit_script_for_cd_guards(body, false, diagnostics)
        None => ()
      }
    }
    While(clause) | Until(clause) => {
      analytics_visit_script_for_cd_guards(clause.condition, true, diagnostics)
      analytics_visit_script_for_cd_guards(clause.body, false, diagnostics)
    }
    ForIn(clause) =>
      analytics_visit_script_for_cd_guards(clause.body, false, diagnostics)
    ForArithmetic(clause) =>
      analytics_visit_script_for_cd_guards(clause.body, false, diagnostics)
    Select(clause) =>
      analytics_visit_script_for_cd_guards(clause.body, false, diagnostics)
    Case(clause) =>
      for item in clause.items {
        analytics_visit_script_for_cd_guards(item.body, false, diagnostics)
      }
    Function(function_) =>
      analytics_visit_command_for_cd_guards(
        function_.body,
        false,
        guarded,
        diagnostics,
      )
    CoProc(clause) =>
      analytics_visit_command_for_cd_guards(
        clause.body,
        false,
        guarded,
        diagnostics,
      )
    Simple(_) | Source(_) | Condition(_) | Arithmetic(_) => ()
  }
}

///|
fn analytics_maybe_warn_unchecked_dir_change(
  command : @parser.Command,
  in_condition : Bool,
  guarded : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard !in_condition && !guarded else { return }
  let name = match @semantics.effective_command_name(command) {
    Some(name) => name
    None => return
  }
  guard ["cd", "pushd", "popd"].contains(name) else { return }
  guard !analytics_dir_change_is_safe(command, name) else { return }
  guard !(["pushd", "popd"].contains(name) &&
    command_has_short_flag(command, 'n')) else {
    return
  }
  let diagnostic_span = effective_command_span(command)
  push_diagnostic_with_fix(
    diagnostics,
    diagnostic_span,
    Warning,
    2164,
    "Use '\{name} ... || exit' or '\{name} ... || return' in case \{name} fails.",
    analytics_unchecked_dir_change_fix(command.span),
  )
}

///|
fn analytics_unchecked_dir_change_fix(span : @parser.Span) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      span.end,
      span.end,
      " || exit",
      3,
      @fixer.InsertionPoint::before(),
    ),
  ])
}

///|
fn analytics_dir_change_is_safe(
  command : @parser.Command,
  name : String,
) -> Bool {
  let arguments = @semantics.effective_command_arguments(command)
  match arguments.get(0) {
    Some(argument) =>
      match @semantics.literal_text(argument) {
        Some(path) =>
          if path.has_prefix("-") {
            true
          } else {
            analytics_safe_directory_argument(path)
          }
        None => false
      }
    None => name == "cd" && false
  }
}

///|
fn analytics_safe_directory_argument(path : String) -> Bool {
  if path == "" {
    return false
  }
  let mut saw_segment = false
  let view = path[:]
  let mut i = 0
  let mut segment_start = 0
  while i <= view.length() {
    if i == view.length() || view[i] == '/' {
      if i > segment_start {
        let segment = path
          .view(start_offset=segment_start, end_offset=i)
          .to_owned()
        if segment != "." && segment != ".." {
          return false
        }
        saw_segment = true
      }
      segment_start = i + 1
    }
    i += 1
  }
  saw_segment || path.contains("/")
}

///|
fn command_has_short_flag(command : @parser.Command, flag : UInt16) -> Bool {
  for argument in @semantics.effective_command_arguments(command) {
    match word_single_literal_text(argument) {
      Some(text) if text == "--" => return false
      Some(text) if text.has_prefix("-") && !text.has_prefix("--") => {
        let view = text[:]
        let mut i = 1
        while i < view.length() {
          if view[i] == flag {
            return true
          }
          i += 1
        }
      }
      _ => return false
    }
  }
  false
}

///|
priv struct AnalyticsLoopBinding {
  name : String
  span : @parser.Span
}

///|
fn check_loop_variable_reassignment(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let stack : Array[AnalyticsLoopBinding] = []
  analytics_visit_script_for_loop_reassignment(script, stack, diagnostics)
}

///|
fn analytics_visit_script_for_loop_reassignment(
  script : @parser.Script,
  stack : Array[AnalyticsLoopBinding],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for item in script.items {
    analytics_visit_pipeline_for_loop_reassignment(
      item.and_or.head,
      stack,
      diagnostics,
    )
    for pair in item.and_or.tail {
      let (_, pipeline) = pair
      analytics_visit_pipeline_for_loop_reassignment(
        pipeline, stack, diagnostics,
      )
    }
  }
}

///|
fn analytics_visit_pipeline_for_loop_reassignment(
  pipeline : @parser.Pipeline,
  stack : Array[AnalyticsLoopBinding],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for segment in pipeline.segments {
    analytics_visit_command_for_loop_reassignment(
      segment.command,
      stack,
      diagnostics,
    )
  }
}

///|
fn analytics_visit_command_for_loop_reassignment(
  command : @parser.Command,
  stack : Array[AnalyticsLoopBinding],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let loop_name = analytics_loop_binding_name(command)
  let pushed = match loop_name {
    Some(name) if name != "_" => {
      match analytics_find_loop_binding(stack, name) {
        Some(parent) => {
          push_diagnostic(
            diagnostics,
            command_keyword_span(command, "for"),
            Warning,
            2165,
            "This nested loop overrides the index variable of its parent.",
          )
          push_diagnostic(
            diagnostics,
            parent.span,
            Warning,
            2167,
            "This parent loop has its index variable overridden.",
          )
        }
        None => ()
      }
      stack.push({ name, span: command_keyword_span(command, "for") })
      true
    }
    _ => false
  }

  match command.kind {
    Time(clause) =>
      analytics_visit_pipeline_for_loop_reassignment(
        clause.body,
        stack,
        diagnostics,
      )
    Subshell(script) | BraceGroup(script) | BatsTest({ body: script, .. }) =>
      analytics_visit_script_for_loop_reassignment(script, stack, diagnostics)
    If(clause) => {
      for arm in clause.arms {
        analytics_visit_script_for_loop_reassignment(
          arm.condition,
          stack,
          diagnostics,
        )
        analytics_visit_script_for_loop_reassignment(
          arm.body,
          stack,
          diagnostics,
        )
      }
      match clause.else_body {
        Some(body) =>
          analytics_visit_script_for_loop_reassignment(body, stack, diagnostics)
        None => ()
      }
    }
    While(clause) | Until(clause) => {
      analytics_visit_script_for_loop_reassignment(
        clause.condition,
        stack,
        diagnostics,
      )
      analytics_visit_script_for_loop_reassignment(
        clause.body,
        stack,
        diagnostics,
      )
    }
    ForIn(clause) =>
      analytics_visit_script_for_loop_reassignment(
        clause.body,
        stack,
        diagnostics,
      )
    ForArithmetic(clause) =>
      analytics_visit_script_for_loop_reassignment(
        clause.body,
        stack,
        diagnostics,
      )
    Select(clause) =>
      analytics_visit_script_for_loop_reassignment(
        clause.body,
        stack,
        diagnostics,
      )
    Case(clause) =>
      for item in clause.items {
        analytics_visit_script_for_loop_reassignment(
          item.body,
          stack,
          diagnostics,
        )
      }
    Function(function_) =>
      analytics_visit_command_for_loop_reassignment(
        function_.body,
        stack,
        diagnostics,
      )
    CoProc(clause) =>
      analytics_visit_command_for_loop_reassignment(
        clause.body,
        stack,
        diagnostics,
      )
    Simple(_) | Source(_) | Condition(_) | Arithmetic(_) => ()
  }

  if pushed {
    let _ = stack.pop()
  }
}

///|
fn analytics_loop_binding_name(command : @parser.Command) -> String? {
  match command.kind {
    ForIn(clause) => Some(clause.name)
    ForArithmetic(clause) =>
      match clause.init.tokens {
        [Variable(name, []), Operator("="), ..] => Some(name)
        _ => None
      }
    _ => None
  }
}

///|
fn analytics_find_loop_binding(
  stack : Array[AnalyticsLoopBinding],
  name : String,
) -> AnalyticsLoopBinding? {
  let mut i = stack.length()
  while i > 0 {
    i -= 1
    if stack[i].name == name {
      return Some(stack[i])
    }
  }
  None
}

///|
fn check_alias_used_in_same_parsing_unit(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for group in analytics_group_list_items_by_parsing_unit(script.items) {
    let aliases : Map[String, @parser.Span] = Map([])
    for item in group {
      visit_and_or_list_commands(item.and_or, fn(command) {
        match command.kind {
          Simple(simple) =>
            match simple.words.get(0) {
              Some(first) =>
                match word_single_literal_text(first) {
                  Some("alias") =>
                    for argument in @semantics.command_arguments(command) {
                      match analytics_alias_definition_name(argument) {
                        Some(name) =>
                          if !aliases.contains(name) {
                            aliases.set(name, argument.span)
                          }
                        None => ()
                      }
                    }
                  Some(name) => {
                    guard !name.contains("/") else { return }
                    match aliases.get(name) {
                      Some(alias_span) if !annotations_disable_code_at_position(
                          script,
                          alias_span.start,
                          2262,
                        ) => {
                        push_diagnostic(
                          diagnostics,
                          alias_span,
                          Warning,
                          2262,
                          "This alias can't be defined and used in the same parsing unit. Use a function instead.",
                        )
                        push_diagnostic(
                          diagnostics,
                          first.span,
                          Info,
                          2263,
                          "Since they're in the same parsing unit, this command will not refer to the previously mentioned alias.",
                        )
                      }
                      _ => ()
                    }
                  }
                  None => ()
                }
              None => ()
            }
          _ => ()
        }
      })
    }
  }
}

///|
fn analytics_group_list_items_by_parsing_unit(
  items : Array[@parser.ListItem],
) -> Array[Array[@parser.ListItem]] {
  let groups : Array[Array[@parser.ListItem]] = []
  guard items.length() > 0 else { return groups }
  let mut current : Array[@parser.ListItem] = [items[0]]
  let mut i = 1
  while i < items.length() {
    if items[i - 1].and_or.span.end.line == items[i].and_or.span.start.line {
      current.push(items[i])
    } else {
      groups.push(current)
      let next : Array[@parser.ListItem] = [items[i]]
      current = next
    }
    i += 1
  }
  groups.push(current)
  groups
}

///|
priv struct AnalyticsArrayLoopContext {
  index_name : String
  loop_values : Array[(@parser.Span, String)]
  active : Bool
}

///|
fn check_array_value_used_as_index(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let contexts : Array[AnalyticsArrayLoopContext] = []
  analytics_visit_script_for_array_loop_values(script, contexts, diagnostics)
}

///|
fn analytics_visit_script_for_array_loop_values(
  script : @parser.Script,
  contexts : Array[AnalyticsArrayLoopContext],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for item in script.items {
    analytics_visit_pipeline_for_array_loop_values(
      item.and_or.head,
      contexts,
      diagnostics,
    )
    for pair in item.and_or.tail {
      let (_, pipeline) = pair
      analytics_visit_pipeline_for_array_loop_values(
        pipeline, contexts, diagnostics,
      )
    }
  }
}

///|
fn analytics_visit_pipeline_for_array_loop_values(
  pipeline : @parser.Pipeline,
  contexts : Array[AnalyticsArrayLoopContext],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for segment in pipeline.segments {
    analytics_visit_command_for_array_loop_values(
      segment.command,
      contexts,
      diagnostics,
    )
  }
}

///|
fn analytics_visit_command_for_array_loop_values(
  command : @parser.Command,
  contexts : Array[AnalyticsArrayLoopContext],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  analytics_check_array_loop_uses_in_command(command, contexts, diagnostics)

  let written : Array[String] = []
  analytics_collect_written_names(command, written)
  analytics_invalidate_array_loop_contexts(contexts, written)

  let pushed = match command.kind {
    ForIn(clause) => {
      let loop_values = analytics_collect_array_loop_values(clause.values)
      if loop_values.length() > 0 {
        contexts.push({ index_name: clause.name, loop_values, active: true })
        true
      } else {
        false
      }
    }
    _ => false
  }

  match command.kind {
    Time(clause) =>
      analytics_visit_pipeline_for_array_loop_values(
        clause.body,
        contexts,
        diagnostics,
      )
    Subshell(script) | BraceGroup(script) | BatsTest({ body: script, .. }) =>
      analytics_visit_script_for_array_loop_values(
        script, contexts, diagnostics,
      )
    If(clause) => {
      for arm in clause.arms {
        analytics_visit_script_for_array_loop_values(
          arm.condition,
          contexts,
          diagnostics,
        )
        analytics_visit_script_for_array_loop_values(
          arm.body,
          contexts,
          diagnostics,
        )
      }
      match clause.else_body {
        Some(body) =>
          analytics_visit_script_for_array_loop_values(
            body, contexts, diagnostics,
          )
        None => ()
      }
    }
    While(clause) | Until(clause) => {
      analytics_visit_script_for_array_loop_values(
        clause.condition,
        contexts,
        diagnostics,
      )
      analytics_visit_script_for_array_loop_values(
        clause.body,
        contexts,
        diagnostics,
      )
    }
    ForIn(clause) =>
      analytics_visit_script_for_array_loop_values(
        clause.body,
        contexts,
        diagnostics,
      )
    ForArithmetic(clause) =>
      analytics_visit_script_for_array_loop_values(
        clause.body,
        contexts,
        diagnostics,
      )
    Select(clause) =>
      analytics_visit_script_for_array_loop_values(
        clause.body,
        contexts,
        diagnostics,
      )
    Case(clause) =>
      for item in clause.items {
        analytics_visit_script_for_array_loop_values(
          item.body,
          contexts,
          diagnostics,
        )
      }
    Function(function_) =>
      analytics_visit_command_for_array_loop_values(
        function_.body,
        contexts,
        diagnostics,
      )
    CoProc(clause) =>
      analytics_visit_command_for_array_loop_values(
        clause.body,
        contexts,
        diagnostics,
      )
    Simple(_) | Source(_) | Condition(_) | Arithmetic(_) => ()
  }

  if pushed {
    let _ = contexts.pop()
  }
}

///|
fn analytics_collect_array_loop_values(
  values : Array[@parser.Word],
) -> Array[(@parser.Span, String)] {
  let arrays : Array[(@parser.Span, String)] = []
  for value in values {
    match analytics_word_iterates_array_values(value) {
      Some(name) => arrays.push((value.span, name))
      None => ()
    }
  }
  arrays
}

///|
fn analytics_word_iterates_array_values(word : @parser.Word) -> String? {
  match word.parts {
    [BracedParameter(expansion)] =>
      match expansion.name {
        Some(name) if !expansion.indirect && parameter_index_is(expansion, "@") =>
          Some(name)
        _ => None
      }
    _ => None
  }
}

///|
fn analytics_invalidate_array_loop_contexts(
  contexts : Array[AnalyticsArrayLoopContext],
  names : Array[String],
) -> Unit {
  let mut i = 0
  while i < contexts.length() {
    if contexts[i].active && names.contains(contexts[i].index_name) {
      contexts[i] = { ..contexts[i], active: false }
    }
    i += 1
  }
}

///|
fn analytics_check_array_loop_uses_in_command(
  command : @parser.Command,
  contexts : Array[AnalyticsArrayLoopContext],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_direct_words_in_command(command, fn(word, _) {
    analytics_check_array_loop_uses_in_word(word, contexts, diagnostics)
  })
  match command.kind {
    Arithmetic(arithmetic) =>
      analytics_check_array_loop_uses_in_arithmetic_expr(
        arithmetic.expr,
        command.span,
        contexts,
        diagnostics,
      )
    ForArithmetic(clause) => {
      analytics_check_array_loop_uses_in_arithmetic_expr(
        clause.init,
        command.span,
        contexts,
        diagnostics,
      )
      analytics_check_array_loop_uses_in_arithmetic_expr(
        clause.condition,
        command.span,
        contexts,
        diagnostics,
      )
      analytics_check_array_loop_uses_in_arithmetic_expr(
        clause.step,
        command.span,
        contexts,
        diagnostics,
      )
    }
    _ => ()
  }
}

///|
fn analytics_check_array_loop_uses_in_word(
  word : @parser.Word,
  contexts : Array[AnalyticsArrayLoopContext],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for part in word.parts {
    analytics_check_array_loop_word_part(part, word.span, contexts, diagnostics)
  }
}

///|
fn analytics_check_array_loop_word_part(
  part : @parser.WordPart,
  span : @parser.Span,
  contexts : Array[AnalyticsArrayLoopContext],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match part {
    DoubleQuoted(parts) | DollarDoubleQuoted(parts) =>
      for nested in parts {
        analytics_check_array_loop_word_part(
          nested, span, contexts, diagnostics,
        )
      }
    BracedParameter(expansion) => {
      analytics_maybe_report_array_loop_index_use(
        expansion.name,
        expansion.index,
        span,
        contexts,
        diagnostics,
      )
      walk_parameter_expansion_parts(expansion, fn(nested) {
        analytics_check_array_loop_word_part(
          nested, span, contexts, diagnostics,
        )
      })
    }
    ArithmeticExpansion(expr) | DollarBracket(expr) =>
      analytics_check_array_loop_uses_in_arithmetic_expr(
        expr, span, contexts, diagnostics,
      )
    ExtGlob(pattern) =>
      for alternative in pattern.alternatives {
        analytics_check_array_loop_uses_in_word(
          alternative, contexts, diagnostics,
        )
      }
    BraceExpansion(expansion) =>
      for element in expansion.elements {
        analytics_check_array_loop_uses_in_word(element, contexts, diagnostics)
      }
    _ => ()
  }
}

///|
fn analytics_check_array_loop_uses_in_arithmetic_expr(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  contexts : Array[AnalyticsArrayLoopContext],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for token in expr.tokens {
    match token {
      Variable(name, indexes) =>
        for index in indexes {
          analytics_maybe_report_array_loop_index_use(
            Some(name),
            Some(index),
            span,
            contexts,
            diagnostics,
          )
        }
      Expansion(word) =>
        analytics_check_array_loop_uses_in_word(word, contexts, diagnostics)
      Group(inner) =>
        analytics_check_array_loop_uses_in_arithmetic_expr(
          inner, span, contexts, diagnostics,
        )
      _ => ()
    }
  }
}

///|
fn analytics_maybe_report_array_loop_index_use(
  array_name : String?,
  index : @parser.ArrayIndex?,
  span : @parser.Span,
  contexts : Array[AnalyticsArrayLoopContext],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let array_name = match array_name {
    Some(name) => name
    None => return
  }
  let index = match index {
    Some(index) => index
    None => return
  }
  let mut i = contexts.length()
  while i > 0 {
    i -= 1
    let context = contexts[i]
    guard context.active &&
      analytics_array_index_uses_name(index, context.index_name) else {
      continue
    }
    match analytics_find_loop_array_value(context.loop_values, array_name) {
      Some(loop_span) => {
        push_diagnostic(
          diagnostics,
          loop_span,
          Warning,
          2302,
          "This loops over values. To loop over keys, use \"\\${!array[@]}\".",
        )
        push_diagnostic(
          diagnostics,
          span,
          Warning,
          2303,
          "\{context.index_name} is an array value, not a key. Use directly or loop over keys instead.",
        )
        return
      }
      None => ()
    }
  }
}

///|
fn analytics_find_loop_array_value(
  values : Array[(@parser.Span, String)],
  array_name : String,
) -> @parser.Span? {
  for value in values {
    let (span, name) = value
    if name == array_name {
      return Some(span)
    }
  }
  None
}

///|
fn analytics_array_index_uses_name(
  index : @parser.ArrayIndex,
  name : String,
) -> Bool {
  match index.parts {
    [Literal(text)] => analytics_trim_ascii_space(text) == name
    [Parameter(text)] | [SpecialParameter(text)] => text == name
    [
      BracedParameter(
        {
          name: Some(text),
          index: None,
          operator: None,
          indirect: false,
          length_prefix: false,
          ..,
        }
      ),
    ] => text == name
    _ => {
      let raw = analytics_trim_ascii_space(index.raw)
      raw == name || raw == "$" + name || raw == "${" + name + "}"
    }
  }
}

///|
fn analytics_trim_ascii_space(text : String) -> String {
  let view = text[:]
  let mut start = 0
  while start < view.length() &&
        (
          view[start] == ' ' ||
          view[start] == '\t' ||
          view[start] == '\r' ||
          view[start] == '\n'
        ) {
    start += 1
  }
  let mut end_ = view.length()
  while end_ > start &&
        (
          view[end_ - 1] == ' ' ||
          view[end_ - 1] == '\t' ||
          view[end_ - 1] == '\r' ||
          view[end_ - 1] == '\n'
        ) {
    end_ -= 1
  }
  text.view(start_offset=start, end_offset=end_).to_owned()
}

///|
fn check_unsupported_features_d(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    d_check_unsupported_case_feature(command, shell, diagnostics)
    d_check_unsupported_brace_command_expansions(command, shell, diagnostics)
  })
}

///|
fn d_check_unsupported_case_feature(
  command : @parser.Command,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match command.kind {
    Case(clause) =>
      match d_case_feature_support(clause.items) {
        Some((feature, supported)) =>
          if !d_shell_is_supported(shell, supported) {
            push_diagnostic(
              diagnostics,
              command.span,
              Error,
              2127,
              d_unsupported_feature_message(feature, supported),
            )
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn d_case_feature_support(
  items : Array[@parser.CaseItem],
) -> (String, Array[@semantics.ShellDialect])? {
  let mut has_continue = false
  let mut has_fallthrough = false
  for item in items {
    match item.separator {
      Continue => has_continue = true
      FallThrough => has_fallthrough = true
      Break => ()
    }
  }
  if has_continue {
    return Some(("cases with ;;&", [Bash]))
  }
  if has_fallthrough {
    return Some(("cases with ;&", [Bash, Ksh]))
  }
  None
}

///|
fn d_check_unsupported_brace_command_expansions(
  command : @parser.Command,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if d_shell_is_supported(shell, [Bash, Ksh]) {
    return
  }
  let message = d_unsupported_feature_message("${ ..; } command expansion", [
    Bash,
    Ksh,
  ])
  visit_direct_words_in_command(command, fn(word, _) {
    if d_word_has_brace_command_expansion(word) {
      push_diagnostic(
        diagnostics,
        d_brace_command_expansion_span(word),
        Error,
        2127,
        message,
      )
    }
  })
  for redirect in command.redirects {
    match redirect.target {
      HereDoc(doc) =>
        match doc.parts {
          Some(parts) =>
            if d_here_doc_has_brace_command_expansion(parts) {
              push_diagnostic(diagnostics, redirect.span, Error, 2127, message)
            }
          None => ()
        }
      _ => ()
    }
  }
}

///|
fn d_word_has_brace_command_expansion(word : @parser.Word) -> Bool {
  let mut found = false
  walk_word_deep(word, fn(part) {
    match part {
      BraceCommandSubstitution(_, _) => found = true
      _ => ()
    }
  })
  found
}

///|
fn d_here_doc_has_brace_command_expansion(
  parts : Array[@parser.WordPart],
) -> Bool {
  let mut found = false
  for part in parts {
    walk_word_part_deep(part, fn(nested) {
      match nested {
        BraceCommandSubstitution(_, _) => found = true
        _ => ()
      }
    })
  }
  found
}

///|
fn d_brace_command_expansion_span(word : @parser.Word) -> @parser.Span {
  match word.parts {
    [BraceCommandSubstitution(_, _)] => word.span
    [DoubleQuoted([BraceCommandSubstitution(_, _)])]
    | [DollarDoubleQuoted([BraceCommandSubstitution(_, _)])] =>
      d_span_offset(word.span, 1, word.source.length() - 2)
    _ => word.span
  }
}

///|
fn d_span_offset(
  span : @parser.Span,
  offset : Int,
  width : Int,
) -> @parser.Span {
  @parser.Span::new(
    @parser.Position::new(
      span.start.offset + offset,
      span.start.line,
      span.start.column + offset,
    ),
    @parser.Position::new(
      span.start.offset + offset + width,
      span.start.line,
      span.start.column + offset + width,
    ),
  )
}

///|
fn d_shell_is_supported(
  shell : @semantics.ShellDialect,
  supported : Array[@semantics.ShellDialect],
) -> Bool {
  supported.any(fn(current) { current == shell })
}

///|
fn d_unsupported_feature_message(
  feature : String,
  supported : Array[@semantics.ShellDialect],
) -> String {
  "To use \{feature}, specify #!/usr/bin/env \{d_supported_shell_names(supported)}"
}

///|
fn d_supported_shell_names(
  supported : Array[@semantics.ShellDialect],
) -> String {
  let builder = StringBuilder::new()
  let mut i = 0
  while i < supported.length() {
    if i > 0 {
      builder.write_string(" or ")
    }
    builder.write_string(d_shell_env_name(supported[i]))
    i += 1
  }
  builder.to_string()
}

///|
fn d_shell_env_name(shell : @semantics.ShellDialect) -> String {
  match shell {
    Sh => "sh"
    Bash => "bash"
    Dash => "dash"
    Ksh => "ksh"
    BusyboxSh => "busybox sh"
  }
}
