///|
fn append_analytics_batch_f_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_f_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_f_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2015,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "A && B || C is not if-then-else. C may run when A is true.",
    },
    {
      code: 2055,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use && instead of -o in test expressions that repeat the same lhs.",
    },
    {
      code: 2056,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use && instead of || when repeated != comparisons make the expression always true.",
    },
    {
      code: 2252,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use && instead of || when both test commands compare the same lhs.",
    },
    {
      code: 2333,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use || instead of -a/&& when both comparisons repeat the same lhs.",
    },
    {
      code: 2334,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Use || instead of && in arithmetic comparisons that repeat the same lhs.",
    },
  ]
}

///|
fn run_analytics_batch_f_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_shorthand_if(script, diagnostics)
  check_or_neq(script, diagnostics)
  check_and_eq(script, diagnostics)
}

///|
fn check_shorthand_if(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  analytics_walk_script_for_shorthand_if(script, true, fn(current_script) {
    for item in current_script.items {
      analytics_check_shorthand_if_and_or_list(item.and_or, diagnostics)
    }
  })
}

///|
fn analytics_walk_script_for_shorthand_if(
  script : @parser.Script,
  allowed : Bool,
  visit : (@parser.Script) -> Unit,
) -> Unit {
  if !allowed {
    return
  }
  visit(script)
  for item in script.items {
    analytics_walk_pipeline_for_shorthand_if(item.and_or.head, visit)
    for pair in item.and_or.tail {
      let (_, pipeline) = pair
      analytics_walk_pipeline_for_shorthand_if(pipeline, visit)
    }
  }
}

///|
fn analytics_walk_pipeline_for_shorthand_if(
  pipeline : @parser.Pipeline,
  visit : (@parser.Script) -> Unit,
) -> Unit {
  for segment in pipeline.segments {
    analytics_walk_command_for_shorthand_if(segment.command, visit)
  }
}

///|
fn analytics_walk_command_for_shorthand_if(
  command : @parser.Command,
  visit : (@parser.Script) -> Unit,
) -> Unit {
  match command.kind {
    @parser.CommandKind::Time(clause) =>
      analytics_walk_pipeline_for_shorthand_if(clause.body, visit)
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      analytics_walk_script_for_shorthand_if(script, true, visit)
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        analytics_walk_script_for_shorthand_if(arm.condition, false, visit)
        analytics_walk_script_for_shorthand_if(arm.body, true, visit)
      }
      match clause.else_body {
        Some(body) => analytics_walk_script_for_shorthand_if(body, true, visit)
        None => ()
      }
    }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) => {
      analytics_walk_script_for_shorthand_if(clause.condition, false, visit)
      analytics_walk_script_for_shorthand_if(clause.body, true, visit)
    }
    @parser.CommandKind::ForIn(clause) =>
      analytics_walk_script_for_shorthand_if(clause.body, true, visit)
    @parser.CommandKind::ForArithmetic(clause) =>
      analytics_walk_script_for_shorthand_if(clause.body, true, visit)
    @parser.CommandKind::Select(clause) =>
      analytics_walk_script_for_shorthand_if(clause.body, true, visit)
    @parser.CommandKind::Case(clause) =>
      for item in clause.items {
        analytics_walk_script_for_shorthand_if(item.body, true, visit)
      }
    @parser.CommandKind::Function(function_) =>
      analytics_walk_command_for_shorthand_if(function_.body, visit)
    @parser.CommandKind::CoProc(clause) =>
      analytics_walk_command_for_shorthand_if(clause.body, visit)
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_) => ()
  }
}

///|
fn analytics_check_shorthand_if_and_or_list(
  and_or : @parser.AndOrList,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut previous_pipeline = and_or.head
  let mut previous_was_and_if = false
  for pair in and_or.tail {
    let (operator, pipeline) = pair
    match operator {
      @parser.AndOrOperator::OrIf =>
        if previous_was_and_if {
          analytics_maybe_push_shorthand_if_diagnostic(
            previous_pipeline, pipeline, diagnostics,
          )
        }
      @parser.AndOrOperator::AndIf => ()
    }
    previous_was_and_if = match operator {
      @parser.AndOrOperator::AndIf => true
      @parser.AndOrOperator::OrIf => false
    }
    previous_pipeline = pipeline
  }
}

///|
fn analytics_maybe_push_shorthand_if_diagnostic(
  lhs_pipeline : @parser.Pipeline,
  rhs_pipeline : @parser.Pipeline,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  guard analytics_pipeline_is_single_command(lhs_pipeline) else { return }
  guard analytics_pipeline_is_single_command(rhs_pipeline) else { return }
  let lhs_command = analytics_pipeline_single_command(lhs_pipeline)
  let rhs_command = analytics_pipeline_single_command(rhs_pipeline)
  guard !analytics_command_is_test(lhs_command) else { return }
  guard !analytics_shorthand_if_rhs_is_ok(rhs_command) else { return }
  push_diagnostic(
    diagnostics,
    rhs_command.span,
    CheckSeverity::Warning,
    2015,
    "Note that A && B || C is not if-then-else. C may run when A is true.",
  )
}

///|
fn analytics_shorthand_if_rhs_is_ok(command : @parser.Command) -> Bool {
  if analytics_command_is_assignment_only(command) {
    return true
  }
  command_matches_basename(command, "echo") ||
  command_matches_basename(command, "exit") ||
  command_matches_basename(command, "return") ||
  command_matches_basename(command, "printf") ||
  command_matches_basename(command, "true") ||
  command_matches_basename(command, ":")
}

///|
fn analytics_command_is_assignment_only(command : @parser.Command) -> Bool {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      simple.words.length() == 0 && simple.assignments.length() > 0
    _ => false
  }
}

///|
fn analytics_pipeline_is_single_command(pipeline : @parser.Pipeline) -> Bool {
  pipeline.segments.length() == 1
}

///|
fn analytics_pipeline_single_command(
  pipeline : @parser.Pipeline,
) -> @parser.Command {
  pipeline.segments[0].command
}

///|
fn analytics_command_is_test(command : @parser.Command) -> Bool {
  match command.kind {
    @parser.CommandKind::Condition(_) => true
    _ => false
  }
}

///|
fn check_or_neq(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  analytics_walk_script_tree(
    script,
    fn(current_script) {
      for item in current_script.items {
        analytics_check_and_or_list_or_neq(item.and_or, diagnostics)
      }
    },
    fn(command) {
      match command.kind {
        @parser.CommandKind::Condition(condition) =>
          analytics_check_condition_or_neq(
            condition.kind,
            condition.expr,
            diagnostics,
          )
        @parser.CommandKind::Arithmetic(arithmetic) =>
          analytics_check_arithmetic_or_neq(
            arithmetic.expr,
            command.span,
            diagnostics,
          )
        _ => ()
      }
    },
  )
}

///|
fn check_and_eq(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  analytics_walk_script_tree(
    script,
    fn(current_script) {
      for item in current_script.items {
        analytics_check_and_or_list_and_eq(item.and_or, diagnostics)
      }
    },
    fn(command) {
      match command.kind {
        @parser.CommandKind::Condition(condition) =>
          analytics_check_condition_and_eq(
            condition.kind,
            condition.expr,
            diagnostics,
          )
        @parser.CommandKind::Arithmetic(arithmetic) =>
          analytics_check_arithmetic_and_eq(
            arithmetic.expr,
            command.span,
            diagnostics,
          )
        _ => ()
      }
    },
  )
}

///|
fn analytics_walk_script_tree(
  script : @parser.Script,
  visit_script : (@parser.Script) -> Unit,
  visit_command : (@parser.Command) -> Unit,
) -> Unit {
  visit_script(script)
  for item in script.items {
    analytics_walk_pipeline_tree(item.and_or.head, visit_script, visit_command)
    for pair in item.and_or.tail {
      let (_, pipeline) = pair
      analytics_walk_pipeline_tree(pipeline, visit_script, visit_command)
    }
  }
}

///|
fn analytics_walk_pipeline_tree(
  pipeline : @parser.Pipeline,
  visit_script : (@parser.Script) -> Unit,
  visit_command : (@parser.Command) -> Unit,
) -> Unit {
  for segment in pipeline.segments {
    analytics_walk_command_tree(segment.command, visit_script, visit_command)
  }
}

///|
fn analytics_walk_command_tree(
  command : @parser.Command,
  visit_script : (@parser.Script) -> Unit,
  visit_command : (@parser.Command) -> Unit,
) -> Unit {
  visit_command(command)
  match command.kind {
    @parser.CommandKind::Time(clause) =>
      analytics_walk_pipeline_tree(clause.body, visit_script, visit_command)
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      analytics_walk_script_tree(script, visit_script, visit_command)
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        analytics_walk_script_tree(arm.condition, visit_script, visit_command)
        analytics_walk_script_tree(arm.body, visit_script, visit_command)
      }
      match clause.else_body {
        Some(body) =>
          analytics_walk_script_tree(body, visit_script, visit_command)
        None => ()
      }
    }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) => {
      analytics_walk_script_tree(clause.condition, visit_script, visit_command)
      analytics_walk_script_tree(clause.body, visit_script, visit_command)
    }
    @parser.CommandKind::ForIn(clause) =>
      analytics_walk_script_tree(clause.body, visit_script, visit_command)
    @parser.CommandKind::ForArithmetic(clause) =>
      analytics_walk_script_tree(clause.body, visit_script, visit_command)
    @parser.CommandKind::Select(clause) =>
      analytics_walk_script_tree(clause.body, visit_script, visit_command)
    @parser.CommandKind::Case(clause) =>
      for item in clause.items {
        analytics_walk_script_tree(item.body, visit_script, visit_command)
      }
    @parser.CommandKind::Function(function_) =>
      analytics_walk_command_tree(function_.body, visit_script, visit_command)
    @parser.CommandKind::CoProc(clause) =>
      analytics_walk_command_tree(clause.body, visit_script, visit_command)
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_) => ()
  }
}

///|
fn analytics_check_and_or_list_or_neq(
  and_or : @parser.AndOrList,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut previous_pipeline = and_or.head
  for pair in and_or.tail {
    let (operator, pipeline) = pair
    match operator {
      @parser.AndOrOperator::OrIf =>
        analytics_maybe_push_command_level_or_neq(
          previous_pipeline, pipeline, diagnostics,
        )
      @parser.AndOrOperator::AndIf => ()
    }
    previous_pipeline = pipeline
  }
}

///|
fn analytics_check_and_or_list_and_eq(
  and_or : @parser.AndOrList,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut previous_pipeline = and_or.head
  for pair in and_or.tail {
    let (operator, pipeline) = pair
    match operator {
      @parser.AndOrOperator::AndIf =>
        analytics_maybe_push_command_level_and_eq(
          previous_pipeline, pipeline, diagnostics,
        )
      @parser.AndOrOperator::OrIf => ()
    }
    previous_pipeline = pipeline
  }
}

///|
fn analytics_maybe_push_command_level_or_neq(
  lhs_pipeline : @parser.Pipeline,
  rhs_pipeline : @parser.Pipeline,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let lhs_binary = match
    analytics_pipeline_single_condition_binary(lhs_pipeline) {
    Some(binary) => binary
    None => return
  }
  let rhs_binary = match
    analytics_pipeline_single_condition_binary(rhs_pipeline) {
    Some(binary) => binary
    None => return
  }
  let lhs_binary = match analytics_condition_binary_oriented(lhs_binary) {
    Some(binary) => binary
    None => return
  }
  let rhs_binary = match analytics_condition_binary_oriented(rhs_binary) {
    Some(binary) => binary
    None => return
  }
  guard analytics_condition_binary_is_neq(lhs_binary.op) else { return }
  guard lhs_binary.op == rhs_binary.op else { return }
  guard lhs_binary.lhs_key == rhs_binary.lhs_key else { return }
  guard lhs_binary.rhs_key != rhs_binary.rhs_key else { return }
  guard !@semantics.is_glob_word(lhs_binary.rhs_word) else { return }
  guard !@semantics.is_glob_word(rhs_binary.rhs_word) else { return }
  push_diagnostic(
    diagnostics,
    rhs_binary.rhs_word.span,
    CheckSeverity::Warning,
    2252,
    "You probably wanted && here, otherwise it's always true.",
  )
}

///|
fn analytics_maybe_push_command_level_and_eq(
  lhs_pipeline : @parser.Pipeline,
  rhs_pipeline : @parser.Pipeline,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let lhs_binary = match
    analytics_pipeline_single_condition_binary(lhs_pipeline) {
    Some(binary) => binary
    None => return
  }
  let rhs_binary = match
    analytics_pipeline_single_condition_binary(rhs_pipeline) {
    Some(binary) => binary
    None => return
  }
  let lhs_binary = match analytics_condition_binary_oriented(lhs_binary) {
    Some(binary) => binary
    None => return
  }
  let rhs_binary = match analytics_condition_binary_oriented(rhs_binary) {
    Some(binary) => binary
    None => return
  }
  guard analytics_condition_binary_is_eq(lhs_binary.op) else { return }
  guard lhs_binary.op == rhs_binary.op else { return }
  guard lhs_binary.lhs_key == rhs_binary.lhs_key else { return }
  guard lhs_binary.rhs_key != rhs_binary.rhs_key else { return }
  guard analytics_condition_check_and_eq_operands(
    lhs_binary.op,
    lhs_binary.rhs_word,
    rhs_binary.rhs_word,
  ) else {
    return
  }
  push_diagnostic(
    diagnostics,
    rhs_binary.rhs_word.span,
    CheckSeverity::Warning,
    2333,
    "You probably wanted || here, otherwise it's always false.",
  )
}

///|
fn analytics_pipeline_single_condition_binary(
  pipeline : @parser.Pipeline,
) -> AnalyticsConditionBinary? {
  guard pipeline.segments.length() == 1 else { return None }
  analytics_command_condition_binary(pipeline.segments[0].command)
}

///|
fn analytics_command_condition_binary(
  command : @parser.Command,
) -> AnalyticsConditionBinary? {
  match command.kind {
    @parser.CommandKind::Condition(condition) =>
      analytics_condition_expr_binary(condition.expr)
    @parser.CommandKind::Simple(simple) => analytics_simple_test_binary(simple)
    _ => None
  }
}

///|
fn analytics_simple_test_binary(
  simple : @parser.SimpleCommand,
) -> AnalyticsConditionBinary? {
  match simple.words {
    [open, lhs, op_word, rhs, close] =>
      if word_single_literal_text(open) == Some("[") &&
        word_single_literal_text(close) == Some("]") {
        match @semantics.literal_text(op_word) {
          Some(op) => Some({ lhs, op, rhs })
          None => None
        }
      } else {
        None
      }
    [name, lhs, op_word, rhs] =>
      if word_single_literal_text(name) == Some("test") {
        match @semantics.literal_text(op_word) {
          Some(op) => Some({ lhs, op, rhs })
          None => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn analytics_condition_expr_binary(
  expr : @parser.ConditionExpr,
) -> AnalyticsConditionBinary? {
  match expr {
    @parser.ConditionExpr::Binary(op, _, lhs, rhs) => Some({ lhs, op, rhs })
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      analytics_condition_expr_binary(inner)
    _ => None
  }
}

///|
priv struct AnalyticsConditionBinary {
  lhs : @parser.Word
  op : String
  rhs : @parser.Word
}

///|
priv struct AnalyticsOrientedConditionBinary {
  lhs_key : String
  op : String
  rhs_key : String
  rhs_word : @parser.Word
}

///|
fn analytics_check_condition_or_neq(
  kind : @parser.ConditionKind,
  expr : @parser.ConditionExpr,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  analytics_check_condition_neq_expr(kind, expr, true, diagnostics)
}

///|
fn analytics_check_condition_and_eq(
  kind : @parser.ConditionKind,
  expr : @parser.ConditionExpr,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  analytics_check_condition_neq_expr(kind, expr, false, diagnostics)
}

///|
fn analytics_check_condition_neq_expr(
  kind : @parser.ConditionKind,
  expr : @parser.ConditionExpr,
  is_or : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match expr {
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      analytics_check_condition_neq_expr(kind, inner, is_or, diagnostics)
    @parser.ConditionExpr::Or(_, lhs, rhs) => {
      if is_or {
        analytics_maybe_push_condition_or_neq(kind, lhs, rhs, diagnostics)
      }
      analytics_check_condition_neq_expr(kind, lhs, is_or, diagnostics)
      analytics_check_condition_neq_expr(kind, rhs, is_or, diagnostics)
    }
    @parser.ConditionExpr::And(_, lhs, rhs) => {
      if !is_or {
        analytics_maybe_push_condition_and_eq(kind, lhs, rhs, diagnostics)
      }
      analytics_check_condition_neq_expr(kind, lhs, is_or, diagnostics)
      analytics_check_condition_neq_expr(kind, rhs, is_or, diagnostics)
    }
    _ => ()
  }
}

///|
fn analytics_maybe_push_condition_or_neq(
  kind : @parser.ConditionKind,
  lhs_expr : @parser.ConditionExpr,
  rhs_expr : @parser.ConditionExpr,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let lhs = match analytics_condition_expr_binary(lhs_expr) {
    Some(binary) => binary
    None => return
  }
  let rhs = match analytics_condition_expr_binary(rhs_expr) {
    Some(binary) => binary
    None => return
  }
  guard analytics_condition_binary_is_neq(lhs.op) else { return }
  guard lhs.op == rhs.op else { return }
  guard analytics_condition_word_key(lhs.lhs) ==
    analytics_condition_word_key(rhs.lhs) else {
    return
  }
  guard analytics_condition_word_key(lhs.rhs) !=
    analytics_condition_word_key(rhs.rhs) else {
    return
  }
  guard !@semantics.is_glob_word(lhs.rhs) else { return }
  guard !@semantics.is_glob_word(rhs.rhs) else { return }
  push_diagnostic(
    diagnostics,
    rhs.rhs.span,
    CheckSeverity::Warning,
    analytics_condition_or_neq_code(kind),
    "You probably wanted && here, otherwise it's always true.",
  )
}

///|
fn analytics_maybe_push_condition_and_eq(
  kind : @parser.ConditionKind,
  lhs_expr : @parser.ConditionExpr,
  rhs_expr : @parser.ConditionExpr,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let lhs = match analytics_condition_expr_binary(lhs_expr) {
    Some(binary) => binary
    None => return
  }
  let rhs = match analytics_condition_expr_binary(rhs_expr) {
    Some(binary) => binary
    None => return
  }
  guard analytics_condition_binary_is_eq(lhs.op) else { return }
  guard lhs.op == rhs.op else { return }
  guard analytics_condition_word_key(lhs.lhs) ==
    analytics_condition_word_key(rhs.lhs) else {
    return
  }
  guard analytics_condition_word_key(lhs.rhs) !=
    analytics_condition_word_key(rhs.rhs) else {
    return
  }
  guard analytics_condition_check_and_eq_operands(lhs.op, lhs.rhs, rhs.rhs) else {
    return
  }
  push_diagnostic(
    diagnostics,
    rhs.rhs.span,
    CheckSeverity::Warning,
    analytics_condition_and_eq_code(kind),
    "You probably wanted || here, otherwise it's always false.",
  )
}

///|
fn analytics_condition_or_neq_code(kind : @parser.ConditionKind) -> Int {
  match kind {
    @parser.ConditionKind::SingleBracket => 2055
    @parser.ConditionKind::DoubleBracket => 2056
  }
}

///|
fn analytics_condition_and_eq_code(kind : @parser.ConditionKind) -> Int {
  match kind {
    @parser.ConditionKind::SingleBracket => 2333
    @parser.ConditionKind::DoubleBracket => 2333
  }
}

///|
fn analytics_condition_binary_is_neq(op : String) -> Bool {
  op == "!=" || op == "-ne"
}

///|
fn analytics_condition_binary_is_eq(op : String) -> Bool {
  op == "=" || op == "==" || op == "-eq"
}

///|
fn analytics_condition_binary_oriented(
  binary : AnalyticsConditionBinary,
) -> AnalyticsOrientedConditionBinary? {
  let lhs_constant = analytics_condition_word_is_constant(binary.lhs)
  let rhs_constant = analytics_condition_word_is_constant(binary.rhs)
  match (lhs_constant, rhs_constant) {
    (true, false) =>
      Some({
        lhs_key: analytics_condition_word_key(binary.rhs),
        op: binary.op,
        rhs_key: analytics_condition_word_key(binary.lhs),
        rhs_word: binary.lhs,
      })
    (false, true) =>
      Some({
        lhs_key: analytics_condition_word_key(binary.lhs),
        op: binary.op,
        rhs_key: analytics_condition_word_key(binary.rhs),
        rhs_word: binary.rhs,
      })
    _ => None
  }
}

///|
fn analytics_condition_word_key(word : @parser.Word) -> String {
  word.source
}

///|
fn analytics_condition_check_and_eq_operands(
  op : String,
  lhs_rhs : @parser.Word,
  rhs_rhs : @parser.Word,
) -> Bool {
  if op == "-eq" {
    return analytics_condition_word_is_literal_number(lhs_rhs) &&
      analytics_condition_word_is_literal_number(rhs_rhs)
  }
  if op == "=" || op == "==" {
    return analytics_condition_word_is_constant(lhs_rhs) &&
      analytics_condition_word_is_constant(rhs_rhs)
  }
  false
}

///|
fn analytics_condition_word_is_literal_number(word : @parser.Word) -> Bool {
  let text = match @semantics.literal_text(word) {
    Some(text) => text
    None => return false
  }
  guard text != "" else { return false }
  for ch in text {
    guard ch >= '0' && ch <= '9' else { return false }
  }
  true
}

///|
fn analytics_check_arithmetic_or_neq(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  analytics_check_arithmetic_expr(expr, "||", "!=", 2056, span, diagnostics)
}

///|
fn analytics_check_arithmetic_and_eq(
  expr : @parser.ArithmeticExpr,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  analytics_check_arithmetic_expr(expr, "&&", "==", 2334, span, diagnostics)
}

///|
fn analytics_check_arithmetic_expr(
  expr : @parser.ArithmeticExpr,
  logical_op : String,
  comparison_op : String,
  code : Int,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut i = 0
  while i < expr.tokens.length() {
    match expr.tokens[i] {
      @parser.ArithmeticToken::Operator(op) if op == logical_op => {
        let lhs = expr.tokens[:i].to_array()
        let rhs = expr.tokens[i + 1:].to_array()
        analytics_maybe_push_arithmetic_logical_diagnostic(
          lhs, rhs, comparison_op, code, span, diagnostics,
        )
      }
      @parser.ArithmeticToken::Group(inner) =>
        analytics_check_arithmetic_expr(
          inner, logical_op, comparison_op, code, span, diagnostics,
        )
      _ => ()
    }
    i += 1
  }
}

///|
priv struct AnalyticsArithmeticComparison {
  lhs : String
  op : String
  rhs : String
}

///|
fn analytics_maybe_push_arithmetic_logical_diagnostic(
  lhs_tokens : Array[@parser.ArithmeticToken],
  rhs_tokens : Array[@parser.ArithmeticToken],
  comparison_op : String,
  code : Int,
  span : @parser.Span,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let lhs = match analytics_arithmetic_tokens_as_comparison(lhs_tokens) {
    Some(comparison) => comparison
    None => return
  }
  let rhs = match analytics_arithmetic_tokens_as_comparison(rhs_tokens) {
    Some(comparison) => comparison
    None => return
  }
  guard lhs.op == comparison_op else { return }
  guard rhs.op == comparison_op else { return }
  guard lhs.lhs == rhs.lhs else { return }
  guard lhs.rhs != rhs.rhs else { return }
  push_diagnostic(
    diagnostics,
    span,
    CheckSeverity::Warning,
    code,
    if code == 2334 {
      "You probably wanted || here, otherwise it's always false."
    } else {
      "You probably wanted && here, otherwise it's always true."
    },
  )
}

///|
fn analytics_arithmetic_tokens_as_comparison(
  tokens : Array[@parser.ArithmeticToken],
) -> AnalyticsArithmeticComparison? {
  match tokens {
    [@parser.ArithmeticToken::Group(inner)] =>
      analytics_arithmetic_tokens_as_comparison(inner.tokens)
    [lhs, @parser.ArithmeticToken::Operator(op), rhs] if analytics_arithmetic_binary_operator_is_compare(
        op,
      ) =>
      Some({
        lhs: analytics_arithmetic_token_key(lhs),
        op,
        rhs: analytics_arithmetic_token_key(rhs),
      })
    _ => None
  }
}

///|
fn analytics_arithmetic_binary_operator_is_compare(op : String) -> Bool {
  op == "==" || op == "!=" || op == "-eq" || op == "-ne"
}

///|
fn analytics_arithmetic_token_key(token : @parser.ArithmeticToken) -> String {
  match token {
    @parser.ArithmeticToken::Literal(text) => "lit:" + text
    @parser.ArithmeticToken::Operator(op) => "op:" + op
    @parser.ArithmeticToken::Variable(name, indexes) => {
      let buf = StringBuilder::new()
      buf.write_string("var:")
      buf.write_string(name)
      for index in indexes {
        buf.write_char('[')
        buf.write_string(index.raw)
        buf.write_char(']')
      }
      buf.to_string()
    }
    @parser.ArithmeticToken::Expansion(word) => "exp:" + word.source
    @parser.ArithmeticToken::Group(expr) => "grp:" + expr.raw
  }
}
