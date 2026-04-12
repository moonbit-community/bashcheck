///|
fn append_analytics_batch_a_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_a_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_a_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2016,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Expressions don't expand in single quotes.",
    },
    {
      code: 2034,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Assigned variables should be used or exported intentionally.",
    },
    {
      code: 2050,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "This test expression is constant and may be missing $.",
    },
    {
      code: 2086,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Unquoted parameter expansions may split words or trigger globs.",
    },
    {
      code: 2088,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Tilde does not expand inside quotes.",
    },
    {
      code: 2140,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "A quoted-literal-quoted word likely needs escaping or merging.",
    },
    {
      code: 2296,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Parameter expansions can't start with invalid syntax.",
    },
    {
      code: 2297,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Double quotes must be outside parameter expansions.",
    },
    {
      code: 2298,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Nested ${${x}}-style expansions are invalid.",
    },
    {
      code: 2299,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Parameter expansions can't start by nesting another expansion.",
    },
    {
      code: 2300,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Parameter expansion can't be applied to command substitutions.",
    },
    {
      code: 2301,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Parameter expansions can't start with unexpected syntax.",
    },
    {
      code: 2153,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Possible uppercase variable misspelling with a close assigned match.",
    },
    {
      code: 2258,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "A trailing comma in for-values is part of the word, not a separator.",
    },
  ]
}

///|
fn run_analytics_batch_a_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_single_quoted_variables(script, diagnostics)
  check_unused_assignments(script, diagnostics)
  check_bad_parameter_substitutions(script, diagnostics)
  check_uppercase_variable_misspellings(script, diagnostics)
  check_constant_conditions(script, diagnostics)
  check_unquoted_parameter_expansions(script, shell, diagnostics)
  check_tilde_in_quotes(script, diagnostics)
  check_inexplicably_unquoted_literals(script, diagnostics)
  check_for_in_trailing_commas(script, diagnostics)
}

///|
fn check_single_quoted_variables(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    let context = analytics_single_quoted_context_name(command)
    match command.kind {
      @parser.CommandKind::Simple(simple) => {
        for assignment in simple.assignments {
          match assignment.value {
            @parser.AssignmentValue::Word(word) =>
              maybe_push_single_quoted_variable_diagnostic(
                word,
                Some(assignment.name),
                context,
                diagnostics,
              )
            _ => ()
          }
        }
        let mut i = 1
        while i < simple.words.length() {
          maybe_push_single_quoted_variable_diagnostic(
            simple.words[i],
            None,
            context,
            diagnostics,
          )
          i += 1
        }
      }
      @parser.CommandKind::Source(source) => {
        for assignment in source.assignments {
          match assignment.value {
            @parser.AssignmentValue::Word(word) =>
              maybe_push_single_quoted_variable_diagnostic(
                word,
                Some(assignment.name),
                context,
                diagnostics,
              )
            _ => ()
          }
        }
        for option in source.options {
          maybe_push_single_quoted_variable_diagnostic(
            option,
            None,
            context,
            diagnostics,
          )
        }
        maybe_push_single_quoted_variable_diagnostic(
          source.path,
          None,
          context,
          diagnostics,
        )
        for arg in source.args {
          maybe_push_single_quoted_variable_diagnostic(
            arg,
            None,
            context,
            diagnostics,
          )
        }
      }
      _ => ()
    }
  })
}

///|
fn maybe_push_single_quoted_variable_diagnostic(
  word : @parser.Word,
  assignment_name : String?,
  context : String,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard word.parts.length() == 1 else { return }
  let text = match word.parts[0] {
    @parser.WordPart::SingleQuoted(text) => text
    _ => return
  }
  guard analytics_single_quoted_has_expression(text) else { return }
  guard !analytics_single_quoted_assignment_is_exempt(assignment_name) else {
    return
  }
  guard !analytics_single_quoted_context_is_exempt(context) else { return }
  guard !(context == "sed" && analytics_single_quoted_is_sed_exception(text)) else {
    return
  }
  push_diagnostic(
    diagnostics,
    word.span,
    CheckSeverity::Info,
    2016,
    "Expressions don't expand in single quotes, use double quotes for that.",
  )
}

///|
fn analytics_single_quoted_context_name(command : @parser.Command) -> String {
  let effective_name = match @semantics.effective_command_name(command) {
    Some(name) => name
    None => return ""
  }
  let arguments = @semantics.effective_command_arguments(command)
  match effective_name {
    "find" => analytics_find_exec_context_name(arguments)
    "git" => analytics_git_context_name(arguments)
    "mumps" => analytics_mumps_context_name(arguments)
    "busybox" =>
      match arguments.get(0) {
        Some(word) =>
          match @semantics.literal_text(word) {
            Some(name) => "busybox " + name
            None => effective_name
          }
        None => effective_name
      }
    _ => effective_name
  }
}

///|
fn analytics_find_exec_context_name(arguments : Array[@parser.Word]) -> String {
  let mut i = 0
  while i + 1 < arguments.length() {
    let flag = match @semantics.literal_text(arguments[i]) {
      Some(text) => text
      None => ""
    }
    if ["-exec", "-execdir", "-ok", "-okdir"].contains(flag) {
      match @semantics.literal_text(arguments[i + 1]) {
        Some(name) => return name
        None => return "find"
      }
    }
    i += 1
  }
  "find"
}

///|
fn analytics_git_context_name(arguments : Array[@parser.Word]) -> String {
  match arguments.get(0) {
    Some(word) =>
      match @semantics.literal_text(word) {
        Some("filter-branch") => "git filter-branch"
        _ => "git"
      }
    None => "git"
  }
}

///|
fn analytics_mumps_context_name(arguments : Array[@parser.Word]) -> String {
  if arguments.length() >= 2 &&
    @semantics.literal_text(arguments[0]) == Some("-run") {
    match @semantics.literal_text(arguments[1]) {
      Some("%XCMD") => "mumps -run %XCMD"
      Some("LOOP%XCMD") => "mumps -run LOOP%XCMD"
      _ => "mumps"
    }
  } else {
    "mumps"
  }
}

///|
fn analytics_single_quoted_has_expression(text : String) -> Bool {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch == '$' && i + 1 < view.length() {
      let next = view[i + 1]
      if next == '{' ||
        next == '(' ||
        analytics_is_ascii_alpha(next) ||
        analytics_is_ascii_digit(next) ||
        next == '_' {
        return true
      }
    }
    if ch == '`' {
      let mut j = i + 1
      while j < view.length() && view[j] != '`' {
        j += 1
      }
      if j < view.length() && j > i + 1 {
        return true
      }
    }
    i += 1
  }
  false
}

///|
fn analytics_single_quoted_assignment_is_exempt(
  assignment_name : String?,
) -> Bool {
  match assignment_name {
    Some("PS1")
    | Some("PS2")
    | Some("PS3")
    | Some("PS4")
    | Some("PROMPT_COMMAND") => true
    _ => false
  }
}

///|
fn analytics_single_quoted_context_is_exempt(context : String) -> Bool {
  [
    "trap", "sh", "bash", "ksh", "zsh", "ssh", "eval", "xprop", "alias", "sudo",
    "doas", "run0", "docker", "podman", "oc", "dpkg-query", "jq", "rename", "rg",
    "unset", "git filter-branch", "mumps -run %XCMD", "mumps -run LOOP%XCMD",
  ].contains(context) ||
  context.has_suffix("awk") ||
  context.has_prefix("perl")
}

///|
fn analytics_single_quoted_is_sed_exception(text : String) -> Bool {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    if view[i] == '$' {
      let next = if i + 1 < view.length() { Some(view[i + 1]) } else { None }
      let after = if i + 2 < view.length() { Some(view[i + 2]) } else { None }
      match next {
        Some('{')
        | Some('d')
        | Some('p')
        | Some('s')
        | Some('a')
        | Some('i')
        | Some('c') =>
          match after {
            Some(ch) if analytics_is_ascii_alpha(ch) => ()
            _ => return true
          }
        _ => ()
      }
    }
    i += 1
  }
  false
}

///|
fn check_unused_assignments(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let candidates : Array[(String, @parser.Span)] = []
  let references : Array[String] = []
  visit_script_commands(script, fn(command) {
    analytics_collect_unused_assignment_candidates(command, candidates)
    analytics_collect_command_reference_names(command, references)
  })
  for candidate in candidates {
    let (name, span) = candidate
    if references.contains(name) || @semantics.is_internal_variable(name) {
      continue
    }
    push_diagnostic(
      diagnostics,
      span,
      CheckSeverity::Warning,
      2034,
      "\{name} appears unused. Verify use (or export if used externally).",
    )
  }
}

///|
fn analytics_collect_unused_assignment_candidates(
  command : @parser.Command,
  candidates : Array[(String, @parser.Span)],
) -> Unit {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      if simple.words.length() == 0 {
        for assignment in simple.assignments {
          analytics_maybe_push_unused_assignment_candidate(
            candidates,
            assignment.name,
            assignment_name_span(assignment),
          )
        }
      } else {
        analytics_collect_declared_unused_candidates(command, candidates)
      }
    _ => ()
  }
}

///|
fn analytics_collect_declared_unused_candidates(
  command : @parser.Command,
  candidates : Array[(String, @parser.Span)],
) -> Unit {
  let command_name = match @semantics.effective_command_name(command) {
    Some(name) => name
    None => return
  }
  if !analytics_unused_assignment_command_names().contains(command_name) {
    return
  }
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      for assignment in simple.assignments {
        analytics_maybe_push_unused_assignment_candidate(
          candidates,
          assignment.name,
          assignment_name_span(assignment),
        )
      }
    _ => ()
  }
  for word in @semantics.effective_command_arguments(command) {
    match analytics_declared_name(word) {
      Some(name) =>
        analytics_maybe_push_unused_assignment_candidate(
          candidates,
          name,
          analytics_span_for_word_text(word, name),
        )
      None => ()
    }
  }
}

///|
fn analytics_unused_assignment_command_names() -> Array[String] {
  ["declare", "local", "readonly", "typeset"]
}

///|
fn analytics_maybe_push_unused_assignment_candidate(
  candidates : Array[(String, @parser.Span)],
  name : String,
  span : @parser.Span,
) -> Unit {
  guard analytics_is_identifier_name(name) else { return }
  if !candidates.any(fn(candidate) {
      candidate.0 == name && candidate.1 == span
    }) {
    candidates.push((name, span))
  }
}

///|
fn analytics_collect_command_reference_names(
  command : @parser.Command,
  references : Array[String],
) -> Unit {
  visit_direct_words_in_command(command, fn(word, _) {
    collect_word_reference_names(word, references)
  })
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      for assignment in simple.assignments {
        for index in assignment.indexes {
          collect_word_part_reference_names(index.parts, references)
        }
        collect_assignment_value_reference_names(assignment.value, references)
      }
    @parser.CommandKind::Source(source) =>
      for assignment in source.assignments {
        for index in assignment.indexes {
          collect_word_part_reference_names(index.parts, references)
        }
        collect_assignment_value_reference_names(assignment.value, references)
      }
    @parser.CommandKind::Arithmetic(arithmetic) =>
      analytics_collect_arithmetic_reference_names(arithmetic.expr, references)
    @parser.CommandKind::ForArithmetic(clause) => {
      analytics_collect_arithmetic_reference_names(clause.init, references)
      analytics_collect_arithmetic_reference_names(clause.condition, references)
      analytics_collect_arithmetic_reference_names(clause.step, references)
    }
    _ => ()
  }
}

///|
fn analytics_collect_arithmetic_reference_names(
  expr : @parser.ArithmeticExpr,
  references : Array[String],
) -> Unit {
  let mut i = 0
  while i < expr.tokens.length() {
    match expr.tokens[i] {
      @parser.ArithmeticToken::Variable(name, indexes) => {
        if analytics_arithmetic_token_needs_read(expr.tokens, i) {
          push_unique_reference_name(references, name)
        }
        for index in indexes {
          collect_word_part_reference_names(index.parts, references)
        }
      }
      @parser.ArithmeticToken::Expansion(word) =>
        collect_word_reference_names(word, references)
      @parser.ArithmeticToken::Group(inner) =>
        analytics_collect_arithmetic_reference_names(inner, references)
      _ => ()
    }
    i += 1
  }
}

///|
fn analytics_arithmetic_token_needs_read(
  tokens : Array[@parser.ArithmeticToken],
  index : Int,
) -> Bool {
  match tokens[index] {
    @parser.ArithmeticToken::Variable(_, _) =>
      match analytics_arithmetic_next_operator(tokens, index) {
        Some("=") => false
        _ => true
      }
    _ => true
  }
}

///|
fn analytics_arithmetic_next_operator(
  tokens : Array[@parser.ArithmeticToken],
  index : Int,
) -> String? {
  let mut i = index + 1
  while i < tokens.length() {
    match tokens[i] {
      @parser.ArithmeticToken::Operator(op) => return Some(op)
      _ => ()
    }
    i += 1
  }
  None
}

///|
fn check_bad_parameter_substitutions(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      walk_word_deep(word, fn(part) {
        match part {
          @parser.WordPart::BracedParameter(expansion) =>
            maybe_push_bad_parameter_substitution_diagnostic(
              word, expansion, diagnostics,
            )
          _ => ()
        }
      })
    })
  })
}

///|
fn check_unquoted_parameter_expansions(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let quote_safe_target_spans = analytics_collect_quote_safe_word_spans(
    script, shell,
  )
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, place) {
      if !analytics_word_place_checks_2086(place) {
        return
      }
      if analytics_declaration_argument_skips_2086(command, word, place) {
        return
      }
      for target in analytics_quote_targets_2086(word) {
        if quote_safe_target_spans.any(fn(span) { span == target.span }) {
          continue
        }
        push_diagnostic_with_fix(
          diagnostics,
          target.span,
          CheckSeverity::Info,
          2086,
          "Double quote to prevent globbing and word splitting.",
          analytics_quote_span_fix(target.span),
        )
      }
    })
  })
}

///|
fn analytics_collect_quote_safe_word_spans(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
) -> Array[@parser.Span] {
  let cfg = @cfg.build_cfg(
    script,
    @cfg.CfgParameters::new(
      @semantics.has_lastpipe(script, shell),
      @semantics.has_pipefail(script),
    ),
  )
  let analysis = @cfg.analyze_control_flow(cfg)
  let spans : Array[@parser.Span] = []
  for id in @cfg.ast_ids(cfg) {
    match @cfg.ast_ref_of(cfg, id) {
      Some(@semantics.NodeRef::Word(word)) =>
        for target in analytics_quote_safe_targets(word) {
          if quote_safe_word_context_allows(cfg, id, word) &&
            variable_state_is_quote_safe(analysis, id, target.name) {
            spans.push(target.span)
          }
        }
      _ => ()
    }
  }
  spans
}

///|
fn analytics_word_place_checks_2086(place : WordPlace) -> Bool {
  if place == WordPlace::CaseWord {
    return false
  }
  word_place_checks_unquoted_expansions(place)
}

///|
fn analytics_declaration_argument_skips_2086(
  command : @parser.Command,
  word : @parser.Word,
  place : WordPlace,
) -> Bool {
  guard place == WordPlace::CommandArgument else { return false }
  let command_name = match @semantics.effective_command_name(command) {
    Some(name) => name
    None => return false
  }
  @semantics.is_declaring_command(command_name) &&
  analytics_declared_name(word) is Some(_)
}

///|
priv struct Analytics2086Target {
  span : @parser.Span
}

///|
priv struct AnalyticsQuoteSafeTarget {
  span : @parser.Span
  name : String
}

///|
fn analytics_quote_targets_2086(
  word : @parser.Word,
) -> Array[Analytics2086Target] {
  let targets : Array[Analytics2086Target] = []
  let mut offset = 0
  for part in word.parts {
    let remaining = word.source.view(start_offset=offset).to_string()
    let fragment = analytics_bad_parameter_part_fragment(part, remaining)
    let fragment_offset = match analytics_string_offset(remaining, fragment) {
      Some(inner) => offset + inner
      None => offset
    }
    let remaining_width = word.source.length() - fragment_offset
    let fragment_width = if fragment.length() <= remaining_width {
      fragment.length()
    } else {
      remaining_width
    }
    if analytics_part_needs_2086(part) {
      targets.push({
        span: analytics_span_offset(word.span, fragment_offset, fragment_width),
      })
    }
    offset = fragment_offset + fragment_width
  }
  targets
}

///|
fn analytics_quote_safe_targets(
  word : @parser.Word,
) -> Array[AnalyticsQuoteSafeTarget] {
  let targets : Array[AnalyticsQuoteSafeTarget] = []
  let mut offset = 0
  for part in word.parts {
    let remaining = word.source.view(start_offset=offset).to_string()
    let fragment = analytics_bad_parameter_part_fragment(part, remaining)
    let fragment_offset = match analytics_string_offset(remaining, fragment) {
      Some(inner) => offset + inner
      None => offset
    }
    let remaining_width = word.source.length() - fragment_offset
    let fragment_width = if fragment.length() <= remaining_width {
      fragment.length()
    } else {
      remaining_width
    }
    match analytics_quote_safe_part_name(part) {
      Some(name) =>
        targets.push({
          span: analytics_span_offset(
            word.span,
            fragment_offset,
            fragment_width,
          ),
          name,
        })
      None => ()
    }
    offset = fragment_offset + fragment_width
  }
  targets
}

///|
fn analytics_quote_safe_part_name(part : @parser.WordPart) -> String? {
  match part {
    @parser.WordPart::Parameter(name) =>
      if is_identifier_name(name) {
        Some(name)
      } else {
        None
      }
    @parser.WordPart::BracedParameter(
      {
        length_prefix: false,
        indirect: false,
        name: Some(name),
        index: None,
        operator: None,
        ..,
      }
    ) => if is_identifier_name(name) { Some(name) } else { None }
    _ => None
  }
}

///|
fn analytics_part_needs_2086(part : @parser.WordPart) -> Bool {
  match part {
    @parser.WordPart::Parameter(_) => true
    @parser.WordPart::SpecialParameter(name) =>
      analytics_special_parameter_needs_2086(name)
    @parser.WordPart::BracedParameter(expansion) =>
      analytics_braced_parameter_needs_2086(expansion)
    _ => false
  }
}

///|
fn analytics_special_parameter_needs_2086(name : String) -> Bool {
  if name == "*" {
    return true
  }
  let view = name[:]
  view.length() == 1 && analytics_is_ascii_digit(view[0])
}

///|
fn analytics_braced_parameter_needs_2086(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  if expansion.length_prefix ||
    parameter_index_is(expansion, "@") ||
    expansion.name == Some("@") {
    return false
  }
  match expansion.operator {
    Some(@parser.ParameterOperator::AlternateValue(_)) => false
    _ => true
  }
}

///|
fn analytics_quote_span_fix(span : @parser.Span) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      span.start,
      span.start,
      "\"",
      7,
      @fixer.InsertionPoint::after(),
    ),
    @fixer.Replacement::new(
      "",
      span.end,
      span.end,
      "\"",
      7,
      @fixer.InsertionPoint::before(),
    ),
  ])
}

///|
fn maybe_push_bad_parameter_substitution_diagnostic(
  word : @parser.Word,
  expansion : @parser.ParameterExpansion,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let raw_word = @parser.parse_text_as_word(expansion.raw)
  guard raw_word.parts.length() > 0 else { return }
  guard !analytics_parameter_parts_are_indirection(raw_word.parts) else {
    return
  }
  match analytics_bad_parameter_substitution(raw_word.parts[0], expansion.raw) {
    Some((code, fragment, message)) =>
      push_diagnostic(
        diagnostics,
        analytics_span_for_nested_word_text(
          word,
          "${\{expansion.raw}}",
          fragment,
        ),
        CheckSeverity::Error,
        code,
        message,
      )
    None => ()
  }
}

///|
fn analytics_bad_parameter_substitution(
  part : @parser.WordPart,
  raw : String,
) -> (Int, String, String)? {
  match part {
    @parser.WordPart::Literal(text) | @parser.WordPart::Glob(text) =>
      if analytics_parameter_literal_has_valid_start(text) {
        None
      } else {
        Some(
          (
            2296,
            text,
            "Parameter expansions can't start with \{text.view(end_offset=1).to_string()}. Double check syntax.",
          ),
        )
      }
    @parser.WordPart::DoubleQuoted(parts) =>
      match analytics_double_quoted_variable_name(parts) {
        Some(name) =>
          Some(
            (
              2297,
              "\"" + name + "\"",
              "Double quotes must be outside ${}: ${\"invalid\"} vs \"${valid}\".",
            ),
          )
        None =>
          Some(
            (
              2301,
              analytics_bad_parameter_part_fragment(part, raw),
              "Parameter expansion starts with unexpected quotes. Double check syntax.",
            ),
          )
      }
    @parser.WordPart::SingleQuoted(_)
    | @parser.WordPart::DollarSingleQuoted(_)
    | @parser.WordPart::DollarDoubleQuoted(_) =>
      Some(
        (
          2301,
          analytics_bad_parameter_part_fragment(part, raw),
          "Parameter expansion starts with unexpected quotes. Double check syntax.",
        ),
      )
    @parser.WordPart::BracedParameter(expansion) =>
      if analytics_is_unmodified_parameter_expansion(expansion) {
        Some(
          (
            2298,
            analytics_bad_parameter_part_fragment(part, raw),
            "${${x}} is invalid. For expansion, use ${x}. For indirection, use arrays, ${!x} or (for sh) eval.",
          ),
        )
      } else {
        Some(
          (
            2299,
            analytics_bad_parameter_part_fragment(part, raw),
            "Parameter expansions can't be nested. Use temporary variables.",
          ),
        )
      }
    @parser.WordPart::CommandSubstitution(_)
    | @parser.WordPart::BraceCommandSubstitution(_, _)
    | @parser.WordPart::BackQuoted(_) =>
      Some(
        (
          2300,
          analytics_bad_parameter_part_fragment(part, raw),
          "Parameter expansion can't be applied to command substitutions. Use temporary variables.",
        ),
      )
    _ =>
      Some(
        (
          2301,
          analytics_bad_parameter_part_fragment(part, raw),
          "Parameter expansion starts with unexpected syntax. Double check syntax.",
        ),
      )
  }
}

///|
fn analytics_parameter_literal_has_valid_start(text : String) -> Bool {
  if text == "" {
    return false
  }
  let first = text[:][0]
  analytics_is_ascii_alpha(first) ||
  analytics_is_ascii_digit(first) ||
  first == '_' ||
  analytics_is_special_parameter_char(first)
}

///|
fn analytics_double_quoted_variable_name(
  parts : Array[@parser.WordPart],
) -> String? {
  match parts {
    [@parser.WordPart::Literal(name)] if analytics_parameter_like_name(name) =>
      Some(name)
    _ => None
  }
}

///|
fn analytics_parameter_like_name(name : String) -> Bool {
  let view = name[:]
  if view.length() == 0 {
    return false
  }
  if view.length() == 1 {
    let first = view[0]
    return analytics_is_ascii_alpha(first) ||
      first == '_' ||
      analytics_is_ascii_digit(first) ||
      analytics_is_special_parameter_char(first)
  }
  analytics_is_identifier_name(name)
}

///|
fn analytics_is_unmodified_parameter_expansion(
  expansion : @parser.ParameterExpansion,
) -> Bool {
  expansion.name is Some(_) &&
  !expansion.length_prefix &&
  !expansion.indirect &&
  expansion.operator is None
}

///|
fn analytics_parameter_parts_are_indirection(
  parts : Array[@parser.WordPart],
) -> Bool {
  let mut saw = false
  for part in parts {
    match analytics_parameter_indirection_part(part) {
      Some(true) => saw = true
      Some(false) => return false
      None => ()
    }
  }
  saw
}

///|
fn analytics_parameter_indirection_part(part : @parser.WordPart) -> Bool? {
  match part {
    @parser.WordPart::Parameter(_)
    | @parser.WordPart::SpecialParameter(_)
    | @parser.WordPart::BracedParameter(_)
    | @parser.WordPart::CommandSubstitution(_)
    | @parser.WordPart::BraceCommandSubstitution(_, _)
    | @parser.WordPart::BackQuoted(_)
    | @parser.WordPart::ArithmeticExpansion(_)
    | @parser.WordPart::DollarBracket(_) => Some(true)
    @parser.WordPart::Literal(text) | @parser.WordPart::Glob(text) =>
      if analytics_literal_has_only_variable_chars(text) {
        None
      } else {
        Some(false)
      }
    _ => Some(false)
  }
}

///|
fn analytics_literal_has_only_variable_chars(text : String) -> Bool {
  let view = text[:]
  if view.length() == 0 {
    return false
  }
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if !analytics_is_ascii_alpha(ch) &&
      !analytics_is_ascii_digit(ch) &&
      ch != '_' {
      return false
    }
    i += 1
  }
  true
}

///|
fn analytics_bad_parameter_part_fragment(
  part : @parser.WordPart,
  raw : String,
) -> String {
  match part {
    @parser.WordPart::Literal(text) | @parser.WordPart::Glob(text) => text
    @parser.WordPart::SingleQuoted(text) => "'" + text + "'"
    @parser.WordPart::DollarSingleQuoted(text) => "$'" + text + "'"
    @parser.WordPart::DoubleQuoted(parts) =>
      "\"" +
      analytics_word_parts_raw_text(parts, raw.view(start_offset=1).to_string()) +
      "\""
    @parser.WordPart::DollarDoubleQuoted(parts) =>
      "$\"" +
      analytics_word_parts_raw_text(parts, raw.view(start_offset=2).to_string()) +
      "\""
    @parser.WordPart::Parameter(name)
    | @parser.WordPart::SpecialParameter(name) => "$" + name
    @parser.WordPart::BracedParameter(expansion) => "${\{expansion.raw}}"
    @parser.WordPart::CommandSubstitution(_) =>
      raw.view(end_offset=analytics_command_substitution_width(raw)).to_string()
    @parser.WordPart::BackQuoted(_) =>
      raw.view(end_offset=analytics_backquoted_width(raw)).to_string()
    @parser.WordPart::BraceCommandSubstitution(_, _) =>
      raw
      .view(end_offset=analytics_prefixed_balanced_width(raw, "${", '{', '}'))
      .to_string()
    @parser.WordPart::ArithmeticExpansion(expr) => "$((" + expr.raw + "))"
    @parser.WordPart::DollarBracket(expr) => "$[" + expr.raw + "]"
    _ => raw
  }
}

///|
fn analytics_word_parts_raw_text(
  parts : Array[@parser.WordPart],
  fallback : String,
) -> String {
  match parts {
    [@parser.WordPart::Literal(text)] => text
    _ => fallback
  }
}

///|
fn analytics_command_substitution_width(raw : String) -> Int {
  analytics_prefixed_balanced_width(raw, "$(", '(', ')')
}

///|
fn analytics_backquoted_width(raw : String) -> Int {
  let view = raw[:]
  if view.length() == 0 || view[0] != '`' {
    return raw.length()
  }
  let mut i = 1
  while i < view.length() {
    if view[i] == '\\' && i + 1 < view.length() {
      i += 2
      continue
    }
    if view[i] == '`' {
      return i + 1
    }
    i += 1
  }
  raw.length()
}

///|
fn analytics_prefixed_balanced_width(
  raw : String,
  prefix : String,
  open_ch : Char,
  close_ch : Char,
) -> Int {
  let view = raw[:]
  let prefix_view = prefix[:]
  if view.length() < prefix_view.length() {
    return raw.length()
  }
  let mut i = 0
  while i < prefix_view.length() {
    if view[i] != prefix_view[i] {
      return raw.length()
    }
    i += 1
  }
  let mut depth = 1
  let mut in_single = false
  let mut in_double = false
  let mut in_backquote = false
  while i < view.length() {
    let ch = view[i].unsafe_to_char()
    if in_single {
      if ch == '\'' {
        in_single = false
      }
      i += 1
      continue
    }
    if in_double {
      if ch == '\\' && i + 1 < view.length() {
        i += 2
        continue
      }
      if ch == '"' {
        in_double = false
      }
      i += 1
      continue
    }
    if in_backquote {
      if ch == '`' {
        in_backquote = false
      }
      i += 1
      continue
    }
    if ch == '\'' {
      in_single = true
      i += 1
      continue
    }
    if ch == '"' {
      in_double = true
      i += 1
      continue
    }
    if ch == '`' {
      in_backquote = true
      i += 1
      continue
    }
    if ch == '\\' && i + 1 < view.length() {
      i += 2
      continue
    }
    if ch == open_ch {
      depth += 1
      i += 1
      continue
    }
    if ch == close_ch {
      depth -= 1
      i += 1
      if depth == 0 {
        return i
      }
      continue
    }
    i += 1
  }
  raw.length()
}

///|
fn analytics_is_special_parameter_char(ch : UInt16) -> Bool {
  ['-', '$', '?', '!', '#', '@', '*'].any(fn(candidate) {
    ch.unsafe_to_char() == candidate
  })
}

///|
fn check_uppercase_variable_misspellings(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let assigned_names : Array[String] = []
  let references : Array[(String, @parser.Span)] = []
  visit_script_commands(script, fn(command) {
    analytics_collect_written_names(command, assigned_names)
    visit_direct_words_in_command(command, fn(word, _) {
      analytics_collect_uppercase_word_references(word, references)
    })
  })
  for reference in references {
    let (name, span) = reference
    if assigned_names.contains(name) || @semantics.is_internal_variable(name) {
      continue
    }
    match analytics_best_assigned_name(name, assigned_names) {
      Some(match_name) =>
        push_diagnostic(
          diagnostics,
          span,
          CheckSeverity::Info,
          2153,
          "Possible misspelling: \{name} may not be assigned. Did you mean \{match_name}?",
        )
      None => ()
    }
  }
}

///|
fn analytics_collect_written_names(
  command : @parser.Command,
  names : Array[String],
) -> Unit {
  match command.kind {
    @parser.CommandKind::Simple(simple) => {
      for assignment in simple.assignments {
        analytics_push_unique_name(names, assignment.name)
      }
      analytics_collect_declared_names(command, names)
      analytics_collect_read_command_names(command, names)
    }
    @parser.CommandKind::Source(source) =>
      for assignment in source.assignments {
        analytics_push_unique_name(names, assignment.name)
      }
    @parser.CommandKind::ForIn(clause) =>
      analytics_push_unique_name(names, clause.name)
    @parser.CommandKind::Select(clause) =>
      analytics_push_unique_name(names, clause.name)
    _ => ()
  }
}

///|
fn analytics_collect_declared_names(
  command : @parser.Command,
  names : Array[String],
) -> Unit {
  let command_name = match @semantics.effective_command_name(command) {
    Some(name) => name
    None => return
  }
  if !@semantics.is_declaring_command(command_name) {
    return
  }
  for argument in @semantics.effective_command_arguments(command) {
    match analytics_declared_name(argument) {
      Some(name) => analytics_push_unique_name(names, name)
      None => ()
    }
  }
}

///|
fn analytics_declared_name(word : @parser.Word) -> String? {
  let text = match @semantics.literal_text(word) {
    Some(text) => text
    None => return None
  }
  if text == "" || text == "-" || text.has_prefix("-") {
    return None
  }
  let view = text[:]
  guard is_identifier_start(view[0].unsafe_to_char()) else { return None }
  let mut i = 1
  while i < view.length() && is_identifier_continue(view[i].unsafe_to_char()) {
    i += 1
  }
  if i == view.length() {
    return Some(text)
  }
  match view[i].unsafe_to_char() {
    '=' | '[' => Some(text.view(end_offset=i).to_string())
    _ => None
  }
}

///|
fn analytics_collect_read_command_names(
  command : @parser.Command,
  names : Array[String],
) -> Unit {
  guard command_matches_exact_name(command, "read") else { return }
  for
    word in read_variable_words(@semantics.effective_command_arguments(command)) {
    match @semantics.literal_text(word) {
      Some(name) if analytics_is_identifier_name(name) =>
        analytics_push_unique_name(names, name)
      _ => ()
    }
  }
}

///|
fn analytics_collect_uppercase_word_references(
  word : @parser.Word,
  references : Array[(String, @parser.Span)],
) -> Unit {
  analytics_collect_uppercase_word_parts(word, word.parts, references)
}

///|
fn analytics_collect_uppercase_word_parts(
  word : @parser.Word,
  parts : Array[@parser.WordPart],
  references : Array[(String, @parser.Span)],
) -> Unit {
  for part in parts {
    match part {
      @parser.WordPart::Parameter(name) =>
        analytics_maybe_push_uppercase_reference(
          references,
          name,
          analytics_span_for_word_text(word, "$" + name),
        )
      @parser.WordPart::BracedParameter(expansion) =>
        if !parameter_expansion_allows_unset(expansion) {
          match expansion.name {
            Some(name) =>
              analytics_maybe_push_uppercase_reference(
                references,
                name,
                analytics_span_for_word_text(word, "${\{expansion.raw}}"),
              )
            None => ()
          }
        }
      @parser.WordPart::DoubleQuoted(nested)
      | @parser.WordPart::DollarDoubleQuoted(nested) =>
        analytics_collect_uppercase_word_parts(word, nested, references)
      @parser.WordPart::ExtGlob(pattern) =>
        for alternative in pattern.alternatives {
          analytics_collect_uppercase_word_references(alternative, references)
        }
      @parser.WordPart::BraceExpansion(expansion) =>
        for element in expansion.elements {
          analytics_collect_uppercase_word_references(element, references)
        }
      _ => ()
    }
  }
}

///|
fn analytics_maybe_push_uppercase_reference(
  references : Array[(String, @parser.Span)],
  name : String,
  span : @parser.Span,
) -> Unit {
  if should_consider_variable_name(name, true) {
    references.push((name, span))
  }
}

///|
fn analytics_best_assigned_name(
  name : String,
  assigned_names : Array[String],
) -> String? {
  let mut best_name = ""
  let mut best_score = name.length() + 1
  for candidate in assigned_names {
    guard analytics_is_identifier_name(candidate) else { continue }
    let score = analytics_edit_distance(name, candidate)
    if score < best_score {
      best_score = score
      best_name = candidate
    }
  }
  if best_name != "" && analytics_good_match(best_name, best_score) {
    Some(best_name)
  } else {
    None
  }
}

///|
fn analytics_good_match(match_name : String, score : Int) -> Bool {
  let length = match_name.length()
  (length > 3 && score <= 1) || (length > 7 && score <= 2)
}

///|
fn analytics_edit_distance(lhs : String, rhs : String) -> Int {
  let lhs_view = lhs[:]
  let rhs_view = rhs[:]
  let width = rhs_view.length() + 1
  let dp = Array::make((lhs_view.length() + 1) * width, 0)
  let mut i = 0
  while i <= lhs_view.length() {
    dp[i * width] = i
    i += 1
  }
  let mut j = 0
  while j <= rhs_view.length() {
    dp[j] = j
    j += 1
  }
  i = 1
  while i <= lhs_view.length() {
    j = 1
    while j <= rhs_view.length() {
      let cost = if lhs_view[i - 1] == rhs_view[j - 1] { 0 } else { 1 }
      let deletion = dp[(i - 1) * width + j] + 1
      let insertion = dp[i * width + (j - 1)] + 1
      let substitution = dp[(i - 1) * width + (j - 1)] + cost
      dp[i * width + j] = analytics_min_int(
        deletion,
        analytics_min_int(insertion, substitution),
      )
      j += 1
    }
    i += 1
  }
  dp[lhs_view.length() * width + rhs_view.length()]
}

///|
fn analytics_push_unique_name(names : Array[String], name : String) -> Unit {
  if name != "" && !names.contains(name) {
    names.push(name)
  }
}

///|
fn analytics_min_int(lhs : Int, rhs : Int) -> Int {
  if lhs <= rhs {
    lhs
  } else {
    rhs
  }
}

///|
fn analytics_is_identifier_name(name : String) -> Bool {
  should_consider_variable_name(name, false) ||
  should_consider_variable_name(name, true)
}

///|
fn check_constant_conditions(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Condition(condition) =>
        visit_condition_binaries(condition.expr, fn(op, lhs, rhs) {
          if !analytics_condition_binary_operator_is_known(op) {
            return
          }
          if analytics_condition_binary_is_dynamic(condition.kind, op) {
            return
          }
          if analytics_condition_word_is_constant(lhs) &&
            analytics_condition_word_is_constant(rhs) {
            push_diagnostic(
              diagnostics,
              analytics_condition_operator_span(lhs, rhs),
              CheckSeverity::Warning,
              2050,
              "This expression is constant. Did you forget the $ on a variable?",
            )
          }
        })
      _ => ()
    }
  })
}

///|
fn analytics_condition_binary_operator_is_known(op : String) -> Bool {
  let normalized = if op.has_prefix("\\") {
    op.view(start_offset=1).to_string()
  } else {
    op
  }
  @semantics.binary_test_operators().contains(normalized)
}

///|
fn analytics_condition_binary_is_dynamic(
  kind : @parser.ConditionKind,
  op : String,
) -> Bool {
  (match kind {
    @parser.ConditionKind::DoubleBracket =>
      @semantics.arithmetic_binary_test_operators().contains(op)
    _ => false
  }) ||
  ["-nt", "-ot", "-ef"].contains(op)
}

///|
fn analytics_condition_word_is_constant(word : @parser.Word) -> Bool {
  @semantics.literal_text(word) is Some(_) &&
  !analytics_condition_parts_have_dynamic_content(word.parts) &&
  !@semantics.is_glob_word(word) &&
  !analytics_word_has_unquoted_tilde(word)
}

///|
fn analytics_condition_parts_have_dynamic_content(
  parts : Array[@parser.WordPart],
) -> Bool {
  for part in parts {
    match part {
      @parser.WordPart::Literal(_)
      | @parser.WordPart::SingleQuoted(_)
      | @parser.WordPart::DollarSingleQuoted(_) => ()
      @parser.WordPart::DoubleQuoted(nested)
      | @parser.WordPart::DollarDoubleQuoted(nested) =>
        if analytics_condition_parts_have_dynamic_content(nested) {
          return true
        }
      _ => return true
    }
  }
  false
}

///|
fn analytics_condition_operator_span(
  lhs : @parser.Word,
  rhs : @parser.Word,
) -> @parser.Span {
  let start = @parser.Position::new(
    lhs.span.end.offset + 1,
    lhs.span.end.line,
    lhs.span.end.column + 1,
  )
  let end_ = @parser.Position::new(
    rhs.span.start.offset - 1,
    rhs.span.start.line,
    rhs.span.start.column - 1,
  )
  @parser.Span::new(start, end_)
}

///|
fn check_tilde_in_quotes(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      match analytics_quoted_tilde_text(word) {
        Some(text) =>
          push_diagnostic(
            diagnostics,
            analytics_span_for_word_text(word, text),
            CheckSeverity::Warning,
            2088,
            "Tilde does not expand in quotes. Use $HOME.",
          )
        None => ()
      }
    })
  })
}

///|
fn analytics_quoted_tilde_text(word : @parser.Word) -> String? {
  match word.parts {
    [@parser.WordPart::SingleQuoted(text)] =>
      if text.has_prefix("~/") {
        Some(text)
      } else {
        None
      }
    [@parser.WordPart::DoubleQuoted(parts)] =>
      match parts.get(0) {
        Some(@parser.WordPart::Literal(text)) if text.has_prefix("~/") =>
          Some(text)
        _ => None
      }
    _ => None
  }
}

///|
fn check_inexplicably_unquoted_literals(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, place) {
      if place == WordPlace::ConditionDoubleBracket {
        return
      }
      let mut i = 0
      while i + 2 < word.parts.length() {
        match (word.parts[i], word.parts[i + 1], word.parts[i + 2]) {
          (
            @parser.WordPart::DoubleQuoted(lhs),
            @parser.WordPart::Literal(text),
            @parser.WordPart::DoubleQuoted(rhs),
          ) =>
            if analytics_should_warn_inexplicably_unquoted(text, lhs, rhs) {
              push_diagnostic(
                diagnostics,
                analytics_span_for_word_text(word, text),
                CheckSeverity::Warning,
                2140,
                "Word is of the form \"A\"B\"C\" (B indicated). Did you mean \"ABC\" or \"A\\\"B\\\"C\"?",
              )
              return
            }
          _ => ()
        }
        i += 1
      }
    })
  })
}

///|
fn analytics_should_warn_inexplicably_unquoted(
  text : String,
  lhs : Array[@parser.WordPart],
  rhs : Array[@parser.WordPart],
) -> Bool {
  if text == "" || !analytics_string_is_alnum(text) {
    return false
  }
  if analytics_quotes_single_thing(lhs) && analytics_quotes_single_thing(rhs) {
    return false
  }
  !["=", ":", "/"].contains(text)
}

///|
fn analytics_quotes_single_thing(parts : Array[@parser.WordPart]) -> Bool {
  match parts {
    [@parser.WordPart::Parameter(_)]
    | [@parser.WordPart::BracedParameter(_)]
    | [@parser.WordPart::CommandSubstitution(_)]
    | [@parser.WordPart::BraceCommandSubstitution(_, _)]
    | [@parser.WordPart::BackQuoted(_)] => true
    _ => false
  }
}

///|
fn check_for_in_trailing_commas(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::ForIn(clause) if clause.values.length() > 1 =>
        for value in clause.values {
          if value.source.has_suffix(",") {
            push_diagnostic_with_fix(
              diagnostics,
              value.span,
              CheckSeverity::Warning,
              2258,
              "The trailing comma is part of the value, not a separator. Delete or quote it.",
              analytics_trailing_comma_fix(value),
            )
          }
        }
      _ => ()
    }
  })
}

///|
fn analytics_trailing_comma_fix(word : @parser.Word) -> @fixer.Fix {
  let start = @parser.Position::new(
    word.span.end.offset - 1,
    word.span.end.line,
    word.span.end.column - 1,
  )
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      start,
      word.span.end,
      "",
      7,
      @fixer.InsertionPoint::before(),
    ),
  ])
}

///|
fn analytics_word_has_unquoted_tilde(word : @parser.Word) -> Bool {
  match word.parts {
    [@parser.WordPart::Literal(text)] => text.has_prefix("~")
    [@parser.WordPart::Glob(text)] => text.has_prefix("~")
    _ => false
  }
}

///|
fn analytics_span_for_word_text(
  word : @parser.Word,
  text : String,
) -> @parser.Span {
  match analytics_string_offset(word.source, text) {
    Some(offset) => analytics_span_offset(word.span, offset, text.length())
    None => word.span
  }
}

///|
fn analytics_span_for_nested_word_text(
  word : @parser.Word,
  outer : String,
  inner : String,
) -> @parser.Span {
  match analytics_string_offset(word.source, outer) {
    Some(outer_offset) =>
      match analytics_string_offset(outer, inner) {
        Some(inner_offset) =>
          analytics_span_offset(
            word.span,
            outer_offset + inner_offset,
            inner.length(),
          )
        None => word.span
      }
    None => word.span
  }
}

///|
fn analytics_string_offset(text : String, needle : String) -> Int? {
  let view = text[:]
  let needle_view = needle[:]
  if needle_view.length() == 0 {
    return Some(0)
  }
  let mut i = 0
  while i + needle_view.length() <= view.length() {
    let mut j = 0
    while j < needle_view.length() && view[i + j] == needle_view[j] {
      j += 1
    }
    if j == needle_view.length() {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn analytics_span_offset(
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
fn analytics_string_is_alnum(text : String) -> Bool {
  let view = text[:]
  if view.length() == 0 {
    return false
  }
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if !analytics_is_ascii_alpha(ch) && !analytics_is_ascii_digit(ch) {
      return false
    }
    i += 1
  }
  true
}

///|
fn analytics_is_ascii_alpha(ch : UInt16) -> Bool {
  ('a' <= ch.unsafe_to_char() && ch.unsafe_to_char() <= 'z') ||
  ('A' <= ch.unsafe_to_char() && ch.unsafe_to_char() <= 'Z')
}

///|
fn analytics_is_ascii_digit(ch : UInt16) -> Bool {
  '0' <= ch.unsafe_to_char() && ch.unsafe_to_char() <= '9'
}
