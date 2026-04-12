///|
fn append_analytics_batch_l_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_l_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_l_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2321,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Array indices are already arithmetic contexts.",
    },
    {
      code: 2322,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "In arithmetic contexts, prefer only one layer of parentheses.",
    },
    {
      code: 2323,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Prefer not wrapping arithmetic contexts in extra parentheses.",
    },
    {
      code: 2324,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Append assignments with numeric values usually mean incrementing.",
    },
  ]
}

///|
fn run_analytics_batch_l_checks(
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
  check_unnecessary_arithmetic_expansion_index(script, diagnostics)
  check_unnecessary_parens(script, diagnostics)
  check_plus_equals_number(cfg, analysis, diagnostics)
}

///|
fn check_unnecessary_arithmetic_expansion_index(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        for assignment in simple.assignments {
          analytics_check_assignment_arithmetic_expansion_index(
            assignment, diagnostics,
          )
        }
      @parser.CommandKind::Source(source) =>
        for assignment in source.assignments {
          analytics_check_assignment_arithmetic_expansion_index(
            assignment, diagnostics,
          )
        }
      _ => ()
    }
  })
}

///|
fn analytics_check_assignment_arithmetic_expansion_index(
  assignment : @parser.Assignment,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if assignment.indexes.length() != 1 {
    return
  }
  let index = assignment.indexes[0]
  if !analytics_array_index_is_unnecessary_arithmetic_expansion(index) {
    return
  }
  match analytics_array_index_expansion_widths(index) {
    Some((prefix_width, suffix_width)) => {
      let span = span_offset(
        assignment.span,
        assignment.name[:].length() + 1,
        index.raw[:].length(),
      )
      push_diagnostic_with_fix(
        diagnostics,
        span,
        CheckSeverity::Style,
        2321,
        "Array indices are already arithmetic contexts. Prefer removing the $(( and )).",
        analytics_remove_wrapper_fix(span, prefix_width, suffix_width, 9),
      )
    }
    None => ()
  }
}

///|
fn analytics_array_index_is_unnecessary_arithmetic_expansion(
  index : @parser.ArrayIndex,
) -> Bool {
  analytics_array_index_expansion_widths(index) is Some(_)
}

///|
fn analytics_array_index_expansion_widths(
  index : @parser.ArrayIndex,
) -> (Int, Int)? {
  guard index.arithmetic is Some(_) else { return None }
  match index.parts {
    [@parser.WordPart::ArithmeticExpansion(_)] => Some((3, 2))
    [@parser.WordPart::DollarBracket(_)] => Some((2, 1))
    _ => None
  }
}

///|
fn check_unnecessary_parens(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      analytics_visit_word_for_unnecessary_parens(word, diagnostics)
    })
    match command.kind {
      @parser.CommandKind::Simple(simple) =>
        for assignment in simple.assignments {
          analytics_check_assignment_parens(assignment, diagnostics)
        }
      @parser.CommandKind::Source(source) =>
        for assignment in source.assignments {
          analytics_check_assignment_parens(assignment, diagnostics)
        }
      @parser.CommandKind::Arithmetic(arithmetic) =>
        analytics_maybe_push_arithmetic_expr_parens_diagnostic(
          arithmetic.expr,
          command.span,
          AnalyticsParensContext::Arithmetic,
          diagnostics,
        )
      @parser.CommandKind::ForArithmetic(clause) => {
        analytics_maybe_push_arithmetic_expr_parens_diagnostic(
          clause.init,
          command.span,
          AnalyticsParensContext::ForArithmetic,
          diagnostics,
        )
        analytics_maybe_push_arithmetic_expr_parens_diagnostic(
          clause.condition,
          command.span,
          AnalyticsParensContext::ForArithmetic,
          diagnostics,
        )
        analytics_maybe_push_arithmetic_expr_parens_diagnostic(
          clause.step,
          command.span,
          AnalyticsParensContext::ForArithmetic,
          diagnostics,
        )
      }
      _ => ()
    }
  })
}

///|
fn analytics_visit_word_for_unnecessary_parens(
  word : @parser.Word,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  analytics_visit_word_parts_for_unnecessary_parens(
    word,
    word.parts,
    diagnostics,
  )
}

///|
fn analytics_visit_word_parts_for_unnecessary_parens(
  word : @parser.Word,
  parts : Array[@parser.WordPart],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for part in parts {
    match part {
      @parser.WordPart::DoubleQuoted(nested)
      | @parser.WordPart::DollarDoubleQuoted(nested) =>
        analytics_visit_word_parts_for_unnecessary_parens(
          word, nested, diagnostics,
        )
      @parser.WordPart::ArithmeticExpansion(expr) =>
        analytics_maybe_push_word_arithmetic_parens_diagnostic(
          word,
          expr,
          AnalyticsParensContext::DollarArithmetic,
          diagnostics,
        )
      @parser.WordPart::DollarBracket(expr) =>
        analytics_maybe_push_word_arithmetic_parens_diagnostic(
          word,
          expr,
          AnalyticsParensContext::DollarBracket,
          diagnostics,
        )
      _ => ()
    }
  }
}

///|
fn analytics_check_assignment_parens(
  assignment : @parser.Assignment,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for index in assignment.indexes {
    analytics_maybe_push_index_parens_diagnostic(assignment, index, diagnostics)
  }
}

///|
fn analytics_maybe_push_index_parens_diagnostic(
  assignment : @parser.Assignment,
  index : @parser.ArrayIndex,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let base_span = span_offset(
    assignment.span,
    assignment.name[:].length() + 1,
    index.raw[:].length(),
  )
  match index.arithmetic {
    Some(expr) =>
      analytics_push_parens_diagnostics_for_text(
        base_span,
        index.raw,
        expr,
        AnalyticsParensContext::ArrayIndex,
        diagnostics,
      )
    None => ()
  }
}

///|
fn analytics_maybe_push_word_arithmetic_parens_diagnostic(
  word : @parser.Word,
  expr : @parser.ArithmeticExpr,
  context : AnalyticsParensContext,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let span = analytics_span_for_word_text(word, expr.raw)
  analytics_push_parens_diagnostics_for_text(
    span,
    expr.raw,
    expr,
    context,
    diagnostics,
  )
}

///|
priv enum AnalyticsParensContext {
  DollarArithmetic
  DollarBracket
  ArrayIndex
  Arithmetic
  ForArithmetic
}

///|
fn analytics_maybe_push_arithmetic_expr_parens_diagnostic(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  context : AnalyticsParensContext,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match analytics_parens_fragments(expr) {
    Some((_, inner_fragment)) => {
      push_diagnostic(
        diagnostics,
        span,
        CheckSeverity::Style,
        2323,
        analytics_outer_parens_message(context),
      )
      match inner_fragment {
        Some(_) =>
          push_diagnostic(
            diagnostics,
            span,
            CheckSeverity::Style,
            2322,
            analytics_double_parens_message(),
          )
        None => ()
      }
    }
    None => ()
  }
}

///|
fn analytics_push_parens_diagnostics_for_text(
  base_span : @parser.Span,
  base_text : String,
  expr : @parser.ArithmeticExpr,
  context : AnalyticsParensContext,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match analytics_parens_fragments(expr) {
    Some((outer_fragment, inner_fragment)) => {
      let outer_span = analytics_span_inside_text(
        base_span, base_text, outer_fragment,
      )
      push_diagnostic_with_fix(
        diagnostics,
        outer_span,
        CheckSeverity::Style,
        2323,
        analytics_outer_parens_message(context),
        analytics_remove_parens_fix(outer_span, 9),
      )
      match inner_fragment {
        Some(fragment) => {
          let inner_span = analytics_span_inside_text(
            base_span, base_text, fragment,
          )
          push_diagnostic_with_fix(
            diagnostics,
            inner_span,
            CheckSeverity::Style,
            2322,
            analytics_double_parens_message(),
            analytics_remove_parens_fix(inner_span, 11),
          )
        }
        None => ()
      }
    }
    None => ()
  }
}

///|
fn analytics_parens_fragments(
  expr : @parser.ArithmeticExpr,
) -> (String, String?)? {
  match expr.tokens {
    [@parser.ArithmeticToken::Group(inner)] => {
      let outer_fragment = "(" + inner.raw + ")"
      let inner_fragment = match inner.tokens {
        [@parser.ArithmeticToken::Group(grandchild)] =>
          Some("(" + grandchild.raw + ")")
        _ => None
      }
      Some((outer_fragment, inner_fragment))
    }
    _ => None
  }
}

///|
fn analytics_outer_parens_message(context : AnalyticsParensContext) -> String {
  match context {
    AnalyticsParensContext::DollarArithmetic =>
      "$(( (x) )) is the same as $(( x )). Prefer not wrapping in additional parentheses."
    AnalyticsParensContext::DollarBracket =>
      "$[ (x) ] is the same as $[ x ]. Prefer not wrapping in additional parentheses."
    AnalyticsParensContext::ArrayIndex =>
      "a[(x)] is the same as a[x]. Prefer not wrapping in additional parentheses."
    AnalyticsParensContext::Arithmetic =>
      "(( (x) )) is the same as (( x )). Prefer not wrapping in additional parentheses."
    AnalyticsParensContext::ForArithmetic =>
      "for (((x); (y); (z))) is the same as for ((x; y; z)). Prefer not wrapping in additional parentheses."
  }
}

///|
fn analytics_double_parens_message() -> String {
  "In arithmetic contexts, ((x)) is the same as (x). Prefer only one layer of parentheses."
}

///|
fn analytics_span_inside_text(
  base_span : @parser.Span,
  base_text : String,
  fragment : String,
) -> @parser.Span {
  match analytics_string_offset(base_text, fragment) {
    Some(offset) => analytics_span_offset(base_span, offset, fragment.length())
    None => base_span
  }
}

///|
fn analytics_remove_parens_fix(
  span : @parser.Span,
  precedence : Int,
) -> @fixer.Fix {
  analytics_remove_wrapper_fix(span, 1, 1, precedence)
}

///|
fn analytics_remove_wrapper_fix(
  span : @parser.Span,
  prefix_width : Int,
  suffix_width : Int,
  precedence : Int,
) -> @fixer.Fix {
  let prefix_end = analytics_position_offset(span.start, prefix_width)
  let suffix_start = analytics_position_offset(span.end, -suffix_width)
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      span.start,
      prefix_end,
      "",
      precedence,
      @fixer.InsertionPoint::after(),
    ),
    @fixer.Replacement::new(
      "",
      suffix_start,
      span.end,
      "",
      precedence,
      @fixer.InsertionPoint::before(),
    ),
  ])
}

///|
fn check_plus_equals_number(
  cfg : @cfg.CFG,
  analysis : @cfg.CfgAnalysis,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for id in @cfg.ast_ids(cfg) {
    match @cfg.ast_ref_of(cfg, id) {
      Some(@semantics.NodeRef::Assignment(assignment)) =>
        analytics_maybe_push_plus_equals_number(
          analysis, id, assignment, diagnostics,
        )
      _ => ()
    }
  }
}

///|
fn analytics_maybe_push_plus_equals_number(
  analysis : @cfg.CfgAnalysis,
  id : @cfg.CfgAstId,
  assignment : @parser.Assignment,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if !assignment.append || assignment.indexes.length() > 0 {
    return
  }
  match assignment.value {
    @parser.AssignmentValue::Word(word) =>
      match @cfg.incoming_state_of_ast(analysis, id) {
        Some(state) =>
          if state.state_is_reachable &&
            !@cfg.variable_may_be_declared_integer(state, assignment.name) &&
            analytics_word_is_numeric_append_value(word, state) {
            push_diagnostic(
              diagnostics,
              assignment_name_span(assignment),
              CheckSeverity::Warning,
              2324,
              "var+=1 will append, not increment. Use (( var += 1 )), typeset -i var, or quote number to silence.",
            )
          }
        None => ()
      }
    _ => ()
  }
}

///|
fn analytics_word_is_numeric_append_value(
  word : @parser.Word,
  state : @cfg.ProgramState,
) -> Bool {
  match @semantics.leading_unquoted_text(word) {
    Some(text) if text != "" && analytics_text_is_all_digits(text) => true
    Some(text) if @cfg.variable_may_be_assigned_integer(state, text) => true
    _ =>
      match word.parts {
        [@parser.WordPart::Parameter(name)]
        | [@parser.WordPart::SpecialParameter(name)] =>
          @cfg.variable_may_be_assigned_integer(state, name)
        [@parser.WordPart::BracedParameter(expansion)] =>
          analytics_braced_parameter_is_numeric_name(state, expansion)
        _ => false
      }
  }
}

///|
fn analytics_braced_parameter_is_numeric_name(
  state : @cfg.ProgramState,
  expansion : @parser.ParameterExpansion,
) -> Bool {
  if expansion.length_prefix || expansion.indirect || expansion.index is Some(_) {
    return false
  }
  match expansion.operator {
    Some(_) => false
    None =>
      match expansion.name {
        Some(name) => @cfg.variable_may_be_assigned_integer(state, name)
        None => false
      }
  }
}

///|
fn analytics_text_is_all_digits(text : String) -> Bool {
  let view = text[:]
  if view.length() == 0 {
    return false
  }
  let mut i = 0
  while i < view.length() {
    if view[i] < '0' || view[i] > '9' {
      return false
    }
    i += 1
  }
  true
}
