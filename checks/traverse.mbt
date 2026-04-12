///|
priv enum WordPlace {
  CommandName
  CommandArgument
  AssignmentValue
  SourceOption
  SourcePath
  SourceArgument
  RedirectionTarget
  ForValue
  SelectValue
  CaseWord
  CasePattern
  ConditionSingleBracket
  ConditionDoubleBracket
  TimeFlag
  CoProcName
  ArithmeticWord
} derive(Eq)

///|
fn visit_script_commands(
  script : @parser.Script,
  visit : (@parser.Command) -> Unit,
) -> Unit {
  for item in script.items {
    visit_and_or_list_commands(item.and_or, visit)
  }
}

///|
fn visit_and_or_list_commands(
  list : @parser.AndOrList,
  visit : (@parser.Command) -> Unit,
) -> Unit {
  visit_pipeline_commands(list.head, visit)
  for pair in list.tail {
    let (_, pipeline) = pair
    visit_pipeline_commands(pipeline, visit)
  }
}

///|
fn visit_pipeline_commands(
  pipeline : @parser.Pipeline,
  visit : (@parser.Command) -> Unit,
) -> Unit {
  for segment in pipeline.segments {
    visit_command_and_includes(segment.command, visit)
  }
}

///|
fn visit_command_and_includes(
  command : @parser.Command,
  visit : (@parser.Command) -> Unit,
) -> Unit {
  @semantics.walk_command(command, visit)
  match command.kind {
    @parser.CommandKind::Source(source) =>
      match source.included {
        Some(script) => visit_script_commands(script, visit)
        None => ()
      }
    _ => ()
  }
}

///|
fn visit_script_pipelines(
  script : @parser.Script,
  visit : (@parser.Pipeline) -> Unit,
) -> Unit {
  for item in script.items {
    visit_and_or_list_pipelines(item.and_or, visit)
  }
}

///|
fn visit_and_or_list_pipelines(
  list : @parser.AndOrList,
  visit : (@parser.Pipeline) -> Unit,
) -> Unit {
  visit_pipeline_deep(list.head, visit)
  for pair in list.tail {
    let (_, pipeline) = pair
    visit_pipeline_deep(pipeline, visit)
  }
}

///|
fn visit_pipeline_deep(
  pipeline : @parser.Pipeline,
  visit : (@parser.Pipeline) -> Unit,
) -> Unit {
  visit(pipeline)
  for segment in pipeline.segments {
    visit_nested_pipelines_in_command(segment.command, visit)
  }
}

///|
fn visit_nested_pipelines_in_command(
  command : @parser.Command,
  visit : (@parser.Pipeline) -> Unit,
) -> Unit {
  match command.kind {
    @parser.CommandKind::Time(clause) => visit_pipeline_deep(clause.body, visit)
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      visit_script_pipelines(script, visit)
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        visit_script_pipelines(arm.condition, visit)
        visit_script_pipelines(arm.body, visit)
      }
      match clause.else_body {
        Some(body) => visit_script_pipelines(body, visit)
        None => ()
      }
    }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) => {
      visit_script_pipelines(clause.condition, visit)
      visit_script_pipelines(clause.body, visit)
    }
    @parser.CommandKind::ForIn(clause) =>
      visit_script_pipelines(clause.body, visit)
    @parser.CommandKind::ForArithmetic(clause) =>
      visit_script_pipelines(clause.body, visit)
    @parser.CommandKind::Select(clause) =>
      visit_script_pipelines(clause.body, visit)
    @parser.CommandKind::Case(clause) =>
      for item in clause.items {
        visit_script_pipelines(item.body, visit)
      }
    @parser.CommandKind::Function(function_) =>
      visit_nested_pipelines_in_command(function_.body, visit)
    @parser.CommandKind::CoProc(clause) =>
      visit_nested_pipelines_in_command(clause.body, visit)
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Source(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_) => ()
  }
}

///|
fn visit_direct_words_in_command(
  command : @parser.Command,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  match command.kind {
    @parser.CommandKind::Simple(simple) => {
      for assignment in simple.assignments {
        visit_assignment_value_words(assignment.value, visit)
      }
      if simple.words.length() > 0 {
        visit(simple.words[0], WordPlace::CommandName)
      }
      let mut i = 1
      while i < simple.words.length() {
        visit(simple.words[i], WordPlace::CommandArgument)
        i += 1
      }
    }
    @parser.CommandKind::Source(source) => {
      for assignment in source.assignments {
        visit_assignment_value_words(assignment.value, visit)
      }
      for option in source.options {
        visit(option, WordPlace::SourceOption)
      }
      visit(source.path, WordPlace::SourcePath)
      for arg in source.args {
        visit(arg, WordPlace::SourceArgument)
      }
    }
    @parser.CommandKind::Time(clause) =>
      for flag in clause.flags {
        visit(flag, WordPlace::TimeFlag)
      }
    @parser.CommandKind::ForIn(clause) =>
      for value in clause.values {
        visit(value, WordPlace::ForValue)
      }
    @parser.CommandKind::Select(clause) =>
      for value in clause.values {
        visit(value, WordPlace::SelectValue)
      }
    @parser.CommandKind::Case(clause) => {
      visit(clause.word, WordPlace::CaseWord)
      for item in clause.items {
        for pattern in item.patterns {
          visit(pattern, WordPlace::CasePattern)
        }
      }
    }
    @parser.CommandKind::Condition(condition) =>
      visit_condition_expr_words(condition.expr, condition.kind, visit)
    @parser.CommandKind::Arithmetic(command) =>
      visit_arithmetic_expr_words(command.expr, visit)
    @parser.CommandKind::ForArithmetic(clause) => {
      visit_arithmetic_expr_words(clause.init, visit)
      visit_arithmetic_expr_words(clause.condition, visit)
      visit_arithmetic_expr_words(clause.step, visit)
    }
    @parser.CommandKind::CoProc(clause) =>
      match clause.name {
        Some(name) => visit(name, WordPlace::CoProcName)
        None => ()
      }
    @parser.CommandKind::Subshell(_)
    | @parser.CommandKind::BraceGroup(_)
    | @parser.CommandKind::If(_)
    | @parser.CommandKind::While(_)
    | @parser.CommandKind::Until(_)
    | @parser.CommandKind::Function(_)
    | @parser.CommandKind::BatsTest(_) => ()
  }
  for redirect in command.redirects {
    match redirect.target {
      @parser.RedirectionTarget::Word(word) =>
        visit(word, WordPlace::RedirectionTarget)
      @parser.RedirectionTarget::HereDoc(_) => ()
    }
  }
}

///|
fn visit_assignment_value_words(
  value : @parser.AssignmentValue,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  match value {
    @parser.AssignmentValue::Empty => ()
    @parser.AssignmentValue::Word(word) =>
      visit(word, WordPlace::AssignmentValue)
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      for element in elements {
        visit_array_element_words(element, visit)
      }
  }
}

///|
fn visit_array_element_words(
  element : @parser.ArrayElement,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  visit_assignment_value_words(element.value, visit)
}

///|
fn visit_condition_expr_words(
  expr : @parser.ConditionExpr,
  kind : @parser.ConditionKind,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  let place = match kind {
    @parser.ConditionKind::SingleBracket => WordPlace::ConditionSingleBracket
    @parser.ConditionKind::DoubleBracket => WordPlace::ConditionDoubleBracket
  }
  match expr {
    @parser.ConditionExpr::Empty => ()
    @parser.ConditionExpr::Word(word) => visit(word, place)
    @parser.ConditionExpr::Unary(_, _, word) => visit(word, place)
    @parser.ConditionExpr::Binary(_, _, lhs, rhs) => {
      visit(lhs, place)
      visit(rhs, place)
    }
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      visit_condition_expr_words(inner, kind, visit)
    @parser.ConditionExpr::And(lhs, rhs)
    | @parser.ConditionExpr::Or(lhs, rhs) => {
      visit_condition_expr_words(lhs, kind, visit)
      visit_condition_expr_words(rhs, kind, visit)
    }
  }
}

///|
fn visit_arithmetic_expr_words(
  expr : @parser.ArithmeticExpr,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  for token in expr.tokens {
    match token {
      @parser.ArithmeticToken::Expansion(word) =>
        visit(word, WordPlace::ArithmeticWord)
      @parser.ArithmeticToken::Group(inner) =>
        visit_arithmetic_expr_words(inner, visit)
      _ => ()
    }
  }
}
