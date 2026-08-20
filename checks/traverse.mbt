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
    Source(source) =>
      if source.included is Some(script) {
        visit_script_commands(script, visit)
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
    Time(clause) => visit_pipeline_deep(clause.body, visit)
    Subshell(script) | BraceGroup(script) | BatsTest({ body: script, .. }) =>
      visit_script_pipelines(script, visit)
    If(clause) => {
      for arm in clause.arms {
        visit_script_pipelines(arm.condition, visit)
        visit_script_pipelines(arm.body, visit)
      }
      if clause.else_body is Some(body) {
        visit_script_pipelines(body, visit)
      }
    }
    While(clause) | Until(clause) => {
      visit_script_pipelines(clause.condition, visit)
      visit_script_pipelines(clause.body, visit)
    }
    ForIn(clause) => visit_script_pipelines(clause.body, visit)
    ForArithmetic(clause) => visit_script_pipelines(clause.body, visit)
    Select(clause) => visit_script_pipelines(clause.body, visit)
    Case(clause) =>
      for item in clause.items {
        visit_script_pipelines(item.body, visit)
      }
    Function(function_) =>
      visit_nested_pipelines_in_command(function_.body, visit)
    CoProc(clause) => visit_nested_pipelines_in_command(clause.body, visit)
    Simple(_) | Source(_) | Condition(_) | Arithmetic(_) => ()
  }
}

///|
fn visit_direct_words_in_command(
  command : @parser.Command,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  match command.kind {
    Simple(simple) => {
      for assignment in simple.assignments {
        visit_assignment_value_words(assignment.value, visit)
      }
      if simple.words.length() > 0 {
        visit(simple.words[0], CommandName)
      }
      let mut i = 1
      while i < simple.words.length() {
        visit(simple.words[i], CommandArgument)
        i += 1
      }
    }
    Source(source) => {
      for assignment in source.assignments {
        visit_assignment_value_words(assignment.value, visit)
      }
      for option in source.options {
        visit(option, SourceOption)
      }
      visit(source.path, SourcePath)
      for arg in source.args {
        visit(arg, SourceArgument)
      }
    }
    Time(clause) =>
      for flag in clause.flags {
        visit(flag, TimeFlag)
      }
    ForIn(clause) =>
      for value in clause.values {
        visit(value, ForValue)
      }
    Select(clause) =>
      for value in clause.values {
        visit(value, SelectValue)
      }
    Case(clause) => {
      visit(clause.word, CaseWord)
      for item in clause.items {
        for pattern in item.patterns {
          visit(pattern, CasePattern)
        }
      }
    }
    Condition(condition) =>
      visit_condition_expr_words(condition.expr, condition.kind, visit)
    Arithmetic(command) => visit_arithmetic_expr_words(command.expr, visit)
    ForArithmetic(clause) => {
      visit_arithmetic_expr_words(clause.init, visit)
      visit_arithmetic_expr_words(clause.condition, visit)
      visit_arithmetic_expr_words(clause.step, visit)
    }
    CoProc(clause) => if clause.name is Some(name) { visit(name, CoProcName) }
    Subshell(_)
    | BraceGroup(_)
    | If(_)
    | While(_)
    | Until(_)
    | Function(_)
    | BatsTest(_) => ()
  }
  for redirect in command.redirects {
    match redirect.target {
      Word(word) => visit(word, RedirectionTarget)
      HereDoc(_) => ()
    }
  }
}

///|
fn visit_assignment_value_words(
  value : @parser.AssignmentValue,
  visit : (@parser.Word, WordPlace) -> Unit,
) -> Unit {
  match value {
    Empty => ()
    Word(word) => visit(word, AssignmentValue)
    ArrayLiteral(elements) =>
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
    SingleBracket => WordPlace::ConditionSingleBracket
    DoubleBracket => ConditionDoubleBracket
  }
  match expr {
    Empty => ()
    Word(word) => visit(word, place)
    Unary(_, _, word) => visit(word, place)
    Binary(_, _, lhs, rhs) => {
      visit(lhs, place)
      visit(rhs, place)
    }
    Group(inner) | Not(inner) => visit_condition_expr_words(inner, kind, visit)
    And(_, lhs, rhs) | Or(_, lhs, rhs) => {
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
      Expansion(word) => visit(word, ArithmeticWord)
      Group(inner) => visit_arithmetic_expr_words(inner, visit)
      _ => ()
    }
  }
}
