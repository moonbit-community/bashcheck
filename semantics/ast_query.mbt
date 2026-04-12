///|
fn ignore_script(script : @parser.Script) -> Unit {
  ignore(script)
}

///|
fn ignore_list_item(item : @parser.ListItem) -> Unit {
  ignore(item)
}

///|
fn ignore_command(command : @parser.Command) -> Unit {
  ignore(command)
}

///|
fn ignore_word(word : @parser.Word) -> Unit {
  ignore(word)
}

///|
fn ignore_word_part(part : @parser.WordPart) -> Unit {
  ignore(part)
}

///|
fn ignore_redirection(redirection : @parser.Redirection) -> Unit {
  ignore(redirection)
}

///|
/// Traverses a script and visits every nested `Script` node.
pub fn walk_script(
  script : @parser.Script,
  visit : (@parser.Script) -> Unit,
) -> Unit {
  traverse_script(
    script, visit, ignore_list_item, ignore_command, ignore_word, ignore_word_part,
    ignore_redirection,
  )
}

///|
/// Traverses a list item and visits every nested `ListItem` node.
pub fn walk_list_item(
  item : @parser.ListItem,
  visit : (@parser.ListItem) -> Unit,
) -> Unit {
  traverse_list_item(
    item, ignore_script, visit, ignore_command, ignore_word, ignore_word_part, ignore_redirection,
  )
}

///|
/// Traverses a command and visits every nested `Command` node.
pub fn walk_command(
  command : @parser.Command,
  visit : (@parser.Command) -> Unit,
) -> Unit {
  traverse_command(
    command, ignore_script, ignore_list_item, visit, ignore_word, ignore_word_part,
    ignore_redirection,
  )
}

///|
/// Traverses a word and visits every nested `Word` node.
pub fn walk_word(word : @parser.Word, visit : (@parser.Word) -> Unit) -> Unit {
  traverse_word(
    word, ignore_script, ignore_list_item, ignore_command, visit, ignore_word_part,
    ignore_redirection,
  )
}

///|
/// Traverses a word part and visits every nested `WordPart` node.
pub fn walk_word_part(
  part : @parser.WordPart,
  visit : (@parser.WordPart) -> Unit,
) -> Unit {
  traverse_word_part(
    part, ignore_script, ignore_list_item, ignore_command, ignore_word, visit, ignore_redirection,
  )
}

///|
/// Traverses a redirection and visits every nested `Redirection` node.
pub fn walk_redirection(
  redirection : @parser.Redirection,
  visit : (@parser.Redirection) -> Unit,
) -> Unit {
  traverse_redirection(
    redirection, ignore_script, ignore_list_item, ignore_command, ignore_word, ignore_word_part,
    visit,
  )
}

///|
fn traverse_script(
  script : @parser.Script,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  on_script(script)
  for item in script.items {
    traverse_list_item(
      item, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
}

///|
fn traverse_list_item(
  item : @parser.ListItem,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  on_list_item(item)
  traverse_and_or_list(
    item.and_or,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
}

///|
fn traverse_and_or_list(
  list : @parser.AndOrList,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  traverse_pipeline(
    list.head,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
  for pair in list.tail {
    let (_, pipeline) = pair
    traverse_pipeline(
      pipeline, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
}

///|
fn traverse_pipeline(
  pipeline : @parser.Pipeline,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  for segment in pipeline.segments {
    traverse_command(
      segment.command,
      on_script,
      on_list_item,
      on_command,
      on_word,
      on_word_part,
      on_redirection,
    )
  }
}

///|
fn traverse_command(
  command : @parser.Command,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  on_command(command)
  traverse_command_kind(
    command.kind,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
  for redirect in command.redirects {
    traverse_redirection(
      redirect, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
}

///|
fn traverse_command_kind(
  kind : @parser.CommandKind,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  match kind {
    @parser.CommandKind::Simple(simple) =>
      traverse_simple_command(
        simple, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.CommandKind::Source(source) =>
      traverse_source_command(
        source, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.CommandKind::Time(clause) =>
      traverse_time_clause(
        clause, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      traverse_script(
        script, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.CommandKind::If(clause) =>
      traverse_if_clause(
        clause, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) =>
      traverse_loop_clause(
        clause, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.CommandKind::ForIn(clause) =>
      traverse_for_clause(
        clause, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.CommandKind::ForArithmetic(clause) =>
      traverse_arithmetic_for_clause(
        clause, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.CommandKind::Select(clause) =>
      traverse_select_clause(
        clause, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.CommandKind::Case(clause) =>
      traverse_case_clause(
        clause, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.CommandKind::Condition(condition) =>
      traverse_condition_expr(
        condition.expr,
        on_script,
        on_list_item,
        on_command,
        on_word,
        on_word_part,
        on_redirection,
      )
    @parser.CommandKind::Arithmetic(command) =>
      traverse_arithmetic_expr(
        command.expr,
        on_script,
        on_list_item,
        on_command,
        on_word,
        on_word_part,
        on_redirection,
      )
    @parser.CommandKind::Function(function_def) =>
      traverse_command(
        function_def.body,
        on_script,
        on_list_item,
        on_command,
        on_word,
        on_word_part,
        on_redirection,
      )
    @parser.CommandKind::CoProc(clause) =>
      traverse_co_proc_clause(
        clause, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
  }
}

///|
fn traverse_simple_command(
  simple : @parser.SimpleCommand,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  for assignment in simple.assignments {
    traverse_assignment(
      assignment, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
  for word in simple.words {
    traverse_word(
      word, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
}

///|
fn traverse_source_command(
  source : @parser.SourceCommand,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  for assignment in source.assignments {
    traverse_assignment(
      assignment, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
  for option in source.options {
    traverse_word(
      option, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
  traverse_word(
    source.path,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
  for arg in source.args {
    traverse_word(
      arg, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
}

///|
fn traverse_time_clause(
  clause : @parser.TimeClause,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  for flag in clause.flags {
    traverse_word(
      flag, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
  traverse_pipeline(
    clause.body,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
}

///|
fn traverse_assignment(
  assignment : @parser.Assignment,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  for index in assignment.indexes {
    traverse_array_index(
      index, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
  traverse_assignment_value(
    assignment.value,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
}

///|
fn traverse_assignment_value(
  value : @parser.AssignmentValue,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  match value {
    @parser.AssignmentValue::Empty => ()
    @parser.AssignmentValue::Word(word) =>
      traverse_word(
        word, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      for element in elements {
        for index in element.indexes {
          traverse_array_index(
            index, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
          )
        }
        traverse_assignment_value(
          element.value,
          on_script,
          on_list_item,
          on_command,
          on_word,
          on_word_part,
          on_redirection,
        )
      }
  }
}

///|
fn traverse_if_clause(
  clause : @parser.IfClause,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  for arm in clause.arms {
    traverse_script(
      arm.condition,
      on_script,
      on_list_item,
      on_command,
      on_word,
      on_word_part,
      on_redirection,
    )
    traverse_script(
      arm.body,
      on_script,
      on_list_item,
      on_command,
      on_word,
      on_word_part,
      on_redirection,
    )
  }
  match clause.else_body {
    Some(script) =>
      traverse_script(
        script, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    None => ()
  }
}

///|
fn traverse_loop_clause(
  clause : @parser.LoopClause,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  traverse_script(
    clause.condition,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
  traverse_script(
    clause.body,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
}

///|
fn traverse_for_clause(
  clause : @parser.ForClause,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  for value in clause.values {
    traverse_word(
      value, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
  traverse_script(
    clause.body,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
}

///|
fn traverse_arithmetic_for_clause(
  clause : @parser.ArithmeticForClause,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  traverse_arithmetic_expr(
    clause.init,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
  traverse_arithmetic_expr(
    clause.condition,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
  traverse_arithmetic_expr(
    clause.step,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
  traverse_script(
    clause.body,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
}

///|
fn traverse_select_clause(
  clause : @parser.SelectClause,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  for value in clause.values {
    traverse_word(
      value, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
  traverse_script(
    clause.body,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
}

///|
fn traverse_case_clause(
  clause : @parser.CaseClause,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  traverse_word(
    clause.word,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
  for item in clause.items {
    for pattern in item.patterns {
      traverse_word(
        pattern, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    }
    traverse_script(
      item.body,
      on_script,
      on_list_item,
      on_command,
      on_word,
      on_word_part,
      on_redirection,
    )
  }
}

///|
fn traverse_condition_expr(
  expr : @parser.ConditionExpr,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  match expr {
    @parser.ConditionExpr::Empty => ()
    @parser.ConditionExpr::Word(word)
    | @parser.ConditionExpr::Unary(_, _, word) =>
      traverse_word(
        word, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.ConditionExpr::Binary(_, _, lhs, rhs) => {
      traverse_word(
        lhs, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
      traverse_word(
        rhs, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    }
    @parser.ConditionExpr::Group(inner) | @parser.ConditionExpr::Not(inner) =>
      traverse_condition_expr(
        inner, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.ConditionExpr::And(lhs, rhs)
    | @parser.ConditionExpr::Or(lhs, rhs) => {
      traverse_condition_expr(
        lhs, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
      traverse_condition_expr(
        rhs, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    }
  }
}

///|
fn traverse_co_proc_clause(
  clause : @parser.CoProcClause,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  match clause.name {
    Some(name) =>
      traverse_word(
        name, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    None => ()
  }
  traverse_command(
    clause.body,
    on_script,
    on_list_item,
    on_command,
    on_word,
    on_word_part,
    on_redirection,
  )
}

///|
fn traverse_redirection(
  redirection : @parser.Redirection,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  on_redirection(redirection)
  match redirection.target {
    @parser.RedirectionTarget::Word(word) =>
      traverse_word(
        word, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.RedirectionTarget::HereDoc(doc) =>
      match doc.parts {
        Some(parts) =>
          for part in parts {
            traverse_word_part(
              part, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
            )
          }
        None => ()
      }
  }
}

///|
fn traverse_word(
  word : @parser.Word,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  on_word(word)
  for part in word.parts {
    traverse_word_part(
      part, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
}

///|
fn traverse_word_part(
  part : @parser.WordPart,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  on_word_part(part)
  match part {
    @parser.WordPart::Literal(_)
    | @parser.WordPart::SingleQuoted(_)
    | @parser.WordPart::DollarSingleQuoted(_)
    | @parser.WordPart::Parameter(_)
    | @parser.WordPart::SpecialParameter(_)
    | @parser.WordPart::Glob(_) => ()
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      for nested in parts {
        traverse_word_part(
          nested, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
        )
      }
    @parser.WordPart::BracedParameter(expansion) =>
      traverse_parameter_expansion(
        expansion, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.WordPart::BraceCommandSubstitution(_, script)
    | @parser.WordPart::CommandSubstitution(script)
    | @parser.WordPart::BackQuoted(script)
    | @parser.WordPart::ProcessSubstitution(_, script) =>
      traverse_script(
        script, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.WordPart::ArithmeticExpansion(expr)
    | @parser.WordPart::DollarBracket(expr) =>
      traverse_arithmetic_expr(
        expr, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    @parser.WordPart::ExtGlob(pattern) =>
      for alternative in pattern.alternatives {
        traverse_word(
          alternative, on_script, on_list_item, on_command, on_word, on_word_part,
          on_redirection,
        )
      }
    @parser.WordPart::BraceExpansion(expansion) =>
      for element in expansion.elements {
        traverse_word(
          element, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
        )
      }
  }
}

///|
fn traverse_parameter_expansion(
  expansion : @parser.ParameterExpansion,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  match expansion.index {
    Some(index) =>
      traverse_array_index(
        index, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    None => ()
  }
  match expansion.operator {
    Some(@parser.ParameterOperator::Slice(offset, length)) => {
      traverse_arithmetic_expr(
        @parser.parse_arithmetic_expr(offset),
        on_script,
        on_list_item,
        on_command,
        on_word,
        on_word_part,
        on_redirection,
      )
      match length {
        Some(length) =>
          traverse_arithmetic_expr(
            @parser.parse_arithmetic_expr(length),
            on_script,
            on_list_item,
            on_command,
            on_word,
            on_word_part,
            on_redirection,
          )
        None => ()
      }
    }
    Some(@parser.ParameterOperator::Replace(_, pattern, replacement)) => {
      traverse_word(
        @parser.parse_text_as_word(pattern),
        on_script,
        on_list_item,
        on_command,
        on_word,
        on_word_part,
        on_redirection,
      )
      match replacement {
        Some(replacement) =>
          traverse_word(
            @parser.parse_text_as_word(replacement),
            on_script,
            on_list_item,
            on_command,
            on_word,
            on_word_part,
            on_redirection,
          )
        None => ()
      }
    }
    Some(@parser.ParameterOperator::CaseModify(_, Some(pattern))) =>
      traverse_word(
        @parser.parse_text_as_word(pattern),
        on_script,
        on_list_item,
        on_command,
        on_word,
        on_word_part,
        on_redirection,
      )
    Some(@parser.ParameterOperator::DefaultValue(text))
    | Some(@parser.ParameterOperator::AssignDefault(text))
    | Some(@parser.ParameterOperator::ErrorValue(text))
    | Some(@parser.ParameterOperator::AlternateValue(text))
    | Some(@parser.ParameterOperator::RemoveShortestPrefix(text))
    | Some(@parser.ParameterOperator::RemoveLongestPrefix(text))
    | Some(@parser.ParameterOperator::RemoveShortestSuffix(text))
    | Some(@parser.ParameterOperator::RemoveLongestSuffix(text))
    | Some(@parser.ParameterOperator::Transform(text))
    | Some(@parser.ParameterOperator::Raw(text)) =>
      traverse_word(
        @parser.parse_text_as_word(text),
        on_script,
        on_list_item,
        on_command,
        on_word,
        on_word_part,
        on_redirection,
      )
    Some(@parser.ParameterOperator::Names(_))
    | Some(@parser.ParameterOperator::CaseModify(_, None))
    | None => ()
  }
}

///|
fn traverse_array_index(
  index : @parser.ArrayIndex,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  for part in index.parts {
    traverse_word_part(
      part, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
    )
  }
  match index.arithmetic {
    Some(expr) =>
      traverse_arithmetic_expr(
        expr, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
      )
    None => ()
  }
}

///|
fn traverse_arithmetic_expr(
  expr : @parser.ArithmeticExpr,
  on_script : (@parser.Script) -> Unit,
  on_list_item : (@parser.ListItem) -> Unit,
  on_command : (@parser.Command) -> Unit,
  on_word : (@parser.Word) -> Unit,
  on_word_part : (@parser.WordPart) -> Unit,
  on_redirection : (@parser.Redirection) -> Unit,
) -> Unit {
  for token in expr.tokens {
    match token {
      @parser.ArithmeticToken::Variable(_, indexes) =>
        for index in indexes {
          traverse_array_index(
            index, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
          )
        }
      @parser.ArithmeticToken::Expansion(word) =>
        traverse_word(
          word, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
        )
      @parser.ArithmeticToken::Group(inner) =>
        traverse_arithmetic_expr(
          inner, on_script, on_list_item, on_command, on_word, on_word_part, on_redirection,
        )
      _ => ()
    }
  }
}

///|
/// Returns the literal command name for a simple or source command.
pub fn command_name(command : @parser.Command) -> String? {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      match simple.words.get(0) {
        Some(word) => literal_text(word)
        None => None
      }
    @parser.CommandKind::Source(source) => Some(source.keyword)
    _ => None
  }
}

///|
/// Returns the basename of `command_name`.
pub fn command_basename(command : @parser.Command) -> String? {
  match command_name(command) {
    Some(name) => Some(path_basename(name))
    None => None
  }
}

///|
/// Returns all words that make up the executable invocation.
pub fn command_words(command : @parser.Command) -> Array[@parser.Word] {
  match command.kind {
    @parser.CommandKind::Simple(simple) => copy_words_from(simple.words, 0)
    @parser.CommandKind::Source(source) => {
      let words : Array[@parser.Word] = []
      for option in source.options {
        words.push(option)
      }
      words.push(source.path)
      for arg in source.args {
        words.push(arg)
      }
      words
    }
    _ => []
  }
}

///|
/// Returns the argument words of a command, excluding the command name itself
/// when that distinction exists.
pub fn command_arguments(command : @parser.Command) -> Array[@parser.Word] {
  match command.kind {
    @parser.CommandKind::Simple(simple) => copy_words_from(simple.words, 1)
    @parser.CommandKind::Source(source) => {
      let words : Array[@parser.Word] = []
      for option in source.options {
        words.push(option)
      }
      words.push(source.path)
      for arg in source.args {
        words.push(arg)
      }
      words
    }
    _ => []
  }
}

///|
/// Returns the command name after wrappers such as `command` are accounted for.
pub fn effective_command_name(command : @parser.Command) -> String? {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      match effective_simple_word_index(simple.words) {
        Some(index) =>
          match simple.words.get(index) {
            Some(word) => literal_text(word)
            None => None
          }
        None => None
      }
    @parser.CommandKind::Source(source) => Some(source.keyword)
    _ => None
  }
}

///|
/// Returns the command named after a leading `builtin` wrapper.
pub fn builtin_command_name(command : @parser.Command) -> String? {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      match simple.words {
        [first, second, ..] =>
          if literal_text(first) == Some("builtin") {
            literal_text(second)
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
/// Returns `command_words` after wrapper commands are skipped.
pub fn effective_command_words(
  command : @parser.Command,
) -> Array[@parser.Word] {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      copy_words_from(
        simple.words,
        match effective_simple_word_index(simple.words) {
          Some(index) => index
          None => 0
        },
      )
    _ => command_words(command)
  }
}

///|
/// Returns `command_arguments` after wrapper commands are skipped.
pub fn effective_command_arguments(
  command : @parser.Command,
) -> Array[@parser.Word] {
  match command.kind {
    @parser.CommandKind::Simple(simple) =>
      match effective_simple_word_index(simple.words) {
        Some(index) => copy_words_from(simple.words, index + 1)
        None => []
      }
    _ => command_arguments(command)
  }
}

///|
/// Returns every redirection attached to a command and its nested structure.
pub fn all_redirections(
  command : @parser.Command,
) -> Array[@parser.Redirection] {
  let redirects : Array[@parser.Redirection] = []
  walk_command(command, fn(current) {
    for redirect in current.redirects {
      redirects.push(redirect)
    }
  })
  redirects
}

///|
/// Returns the literal text of a word when every part is statically known.
pub fn literal_text(word : @parser.Word) -> String? {
  let buf = StringBuilder::new()
  if !append_literal_word_parts_text(word.parts, buf) {
    return None
  }
  Some(buf.to_string())
}

///|
/// Returns the leading unquoted literal prefix of a word.
pub fn leading_unquoted_text(word : @parser.Word) -> String? {
  guard word.parts.length() > 0 else { return None }
  let buf = StringBuilder::new()
  let mut saw_literal = false
  for part in word.parts {
    match part {
      @parser.WordPart::Literal(text) => {
        saw_literal = true
        buf.write_string(text)
      }
      _ => break
    }
  }
  if !saw_literal {
    return None
  }
  Some(buf.to_string())
}

///|
fn leading_shell_text(word : @parser.Word) -> String? {
  let flattened : Array[@parser.WordPart] = []
  append_flattened_word_parts(word.parts, flattened)
  let buf = StringBuilder::new()
  let mut saw_literal = false
  for part in flattened {
    match leading_shell_word_part_text(part) {
      Some(text) => {
        saw_literal = true
        buf.write_string(text)
      }
      None => break
    }
  }
  if !saw_literal {
    return None
  }
  Some(buf.to_string())
}

///|
fn append_flattened_word_parts(
  parts : Array[@parser.WordPart],
  flattened : Array[@parser.WordPart],
) -> Unit {
  for part in parts {
    match part {
      @parser.WordPart::DoubleQuoted(parts)
      | @parser.WordPart::DollarDoubleQuoted(parts) =>
        append_flattened_word_parts(parts, flattened)
      _ => flattened.push(part)
    }
  }
}

///|
fn leading_shell_word_part_text(part : @parser.WordPart) -> String? {
  match part {
    @parser.WordPart::Literal(text) | @parser.WordPart::SingleQuoted(text) =>
      Some(text)
    @parser.WordPart::DollarSingleQuoted(text) =>
      Some(decode_dollar_single_quoted(text))
    _ => None
  }
}

///|
/// Reports whether a word is fully constant after shell expansion rules.
pub fn is_constant_word(word : @parser.Word) -> Bool {
  match word.parts.get(0) {
    Some(@parser.WordPart::Literal(text)) if text.has_prefix("~") => false
    _ => word.parts.all(is_constant_word_part)
  }
}

///|
fn is_constant_word_part(part : @parser.WordPart) -> Bool {
  match part {
    @parser.WordPart::Literal(_)
    | @parser.WordPart::SingleQuoted(_)
    | @parser.WordPart::DollarSingleQuoted(_) => true
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      parts.all(is_constant_word_part)
    _ => false
  }
}

///|
/// Reports whether a word contains glob syntax.
pub fn is_glob_word(word : @parser.Word) -> Bool {
  word.parts.any(is_glob_word_part) || has_split_range(word.parts)
}

///|
fn is_glob_word_part(part : @parser.WordPart) -> Bool {
  match part {
    @parser.WordPart::Glob(_) | @parser.WordPart::ExtGlob(_) => true
    _ => false
  }
}

///|
fn has_split_range(parts : Array[@parser.WordPart]) -> Bool {
  let mut saw_open = false
  for part in parts {
    match part {
      @parser.WordPart::Literal(text) => {
        if saw_open && text.contains("]") {
          return true
        }
        if !saw_open && text.contains("[") {
          saw_open = true
          if text.contains("]") {
            return true
          }
        }
      }
      _ => ()
    }
  }
  false
}

///|
/// Reports whether a word starts with an unquoted option flag.
pub fn is_unquoted_flag(word : @parser.Word) -> Bool {
  match leading_unquoted_text(word) {
    Some(text) => text.has_prefix("-")
    None => false
  }
}

///|
/// Reports whether a simple command consists only of variable assignments.
pub fn is_assignment_only(simple : @parser.SimpleCommand) -> Bool {
  simple.words.length() == 0
}

///|
/// Produces a simplified word list suitable for heuristics and diagnostics.
pub fn oversimplify_command(command : @parser.Command) -> Array[String] {
  match command.kind {
    @parser.CommandKind::Simple(_) =>
      command_words(command).map(oversimplify_word)
    @parser.CommandKind::Source(source) => {
      let words : Array[String] = [source.keyword]
      for option in source.options {
        words.push(oversimplify_word(option))
      }
      words.push(oversimplify_word(source.path))
      for arg in source.args {
        words.push(oversimplify_word(arg))
      }
      words
    }
    _ => []
  }
}

///|
fn oversimplify_word(word : @parser.Word) -> String {
  let buf = StringBuilder::new()
  for part in word.parts {
    buf.write_string(oversimplify_word_part(part))
  }
  buf.to_string()
}

///|
fn oversimplify_word_part(part : @parser.WordPart) -> String {
  match part {
    @parser.WordPart::Literal(text)
    | @parser.WordPart::SingleQuoted(text)
    | @parser.WordPart::DollarSingleQuoted(text)
    | @parser.WordPart::Glob(text) => text
    @parser.WordPart::SpecialParameter(name) => name
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) => {
      let buf = StringBuilder::new()
      for nested in parts {
        buf.write_string(oversimplify_word_part(nested))
      }
      buf.to_string()
    }
    @parser.WordPart::ExtGlob(pattern) => pattern.raw
    @parser.WordPart::BraceExpansion(expansion) => expansion.raw
    _ => "${VAR}"
  }
}

///|
/// Returns `disable=` directives attached to the script.
pub fn extract_disable_directives(script : @parser.Script) -> Array[String] {
  directives_from_annotations(script.annotations, true)
}

///|
/// Returns `enable=` directives attached to the script.
pub fn extract_enable_directives(script : @parser.Script) -> Array[String] {
  directives_from_annotations(script.annotations, false)
}

///|
/// Returns `disable=` directives attached to one list item.
pub fn list_item_disable_directives(item : @parser.ListItem) -> Array[String] {
  directives_from_annotations(item.annotations, true)
}

///|
/// Returns `enable=` directives attached to one list item.
pub fn list_item_enable_directives(item : @parser.ListItem) -> Array[String] {
  directives_from_annotations(item.annotations, false)
}

///|
fn directives_from_annotations(
  annotations : Array[@parser.Annotation],
  disable : Bool,
) -> Array[String] {
  let directives : Array[String] = []
  for annotation in annotations {
    match annotation {
      @parser.Annotation::Disable(value) if disable => directives.push(value)
      @parser.Annotation::Enable(value) if !disable => directives.push(value)
      _ => ()
    }
  }
  directives
}

///|
fn append_literal_word_parts_text(
  parts : Array[@parser.WordPart],
  buf : StringBuilder,
) -> Bool {
  for part in parts {
    if !append_literal_word_part_text(part, buf) {
      return false
    }
  }
  true
}

///|
fn append_literal_word_part_text(
  part : @parser.WordPart,
  buf : StringBuilder,
) -> Bool {
  match part {
    @parser.WordPart::Literal(text)
    | @parser.WordPart::SingleQuoted(text)
    | @parser.WordPart::SpecialParameter(text) => {
      buf.write_string(text)
      true
    }
    @parser.WordPart::DollarSingleQuoted(text) => {
      buf.write_string(decode_dollar_single_quoted(text))
      true
    }
    @parser.WordPart::DoubleQuoted(parts)
    | @parser.WordPart::DollarDoubleQuoted(parts) =>
      append_literal_word_parts_text(parts, buf)
    _ => false
  }
}

///|
fn decode_dollar_single_quoted(text : String) -> String {
  let view = text.view()
  let buf = StringBuilder::new()
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch != '\\' {
      buf.write_char(ch.unsafe_to_char())
      i += 1
      continue
    }
    if i + 1 >= view.length() {
      buf.write_char('\\')
      i += 1
      continue
    }
    let next = view[i + 1]
    match next {
      'a' => {
        buf.write_char((7).unsafe_to_char())
        i += 2
      }
      'b' => {
        buf.write_char((8).unsafe_to_char())
        i += 2
      }
      'e' => {
        buf.write_char((27).unsafe_to_char())
        i += 2
      }
      'f' => {
        buf.write_char((12).unsafe_to_char())
        i += 2
      }
      'n' => {
        buf.write_char('\n')
        i += 2
      }
      'r' => {
        buf.write_char('\r')
        i += 2
      }
      't' => {
        buf.write_char('\t')
        i += 2
      }
      'v' => {
        buf.write_char((11).unsafe_to_char())
        i += 2
      }
      '\'' | '"' | '\\' => {
        buf.write_char(next.unsafe_to_char())
        i += 2
      }
      'x' => {
        let first = if i + 2 < view.length() {
          hex_digit_value(view[i + 2])
        } else {
          None
        }
        let second = if i + 3 < view.length() {
          hex_digit_value(view[i + 3])
        } else {
          None
        }
        match (first, second) {
          (Some(a), Some(b)) => {
            buf.write_char((a * 16 + b).unsafe_to_char())
            i += 4
          }
          (Some(a), None) => {
            buf.write_char(a.unsafe_to_char())
            i += 3
          }
          _ => {
            buf.write_char('\\')
            buf.write_char('x')
            i += 2
          }
        }
      }
      _ if is_octal_digit(next) => {
        let mut value = octal_digit_value(next)
        let mut consumed = 2
        if i + consumed < view.length() && is_octal_digit(view[i + consumed]) {
          value = value * 8 + octal_digit_value(view[i + consumed])
          consumed += 1
        }
        if i + consumed < view.length() && is_octal_digit(view[i + consumed]) {
          value = value * 8 + octal_digit_value(view[i + consumed])
          consumed += 1
        }
        buf.write_char((value % 256).unsafe_to_char())
        i += consumed
      }
      _ => {
        buf.write_char('\\')
        buf.write_char(next.unsafe_to_char())
        i += 2
      }
    }
  }
  buf.to_string()
}

///|
fn hex_digit_value(ch : UInt16) -> Int? {
  if ch >= '0' && ch <= '9' {
    return Some(ch.to_int() - '0'.to_int())
  }
  if ch >= 'a' && ch <= 'f' {
    return Some(ch.to_int() - 'a'.to_int() + 10)
  }
  if ch >= 'A' && ch <= 'F' {
    return Some(ch.to_int() - 'A'.to_int() + 10)
  }
  None
}

///|
fn is_octal_digit(ch : UInt16) -> Bool {
  ch >= '0' && ch <= '7'
}

///|
fn octal_digit_value(ch : UInt16) -> Int {
  ch.to_int() - '0'.to_int()
}

///|
fn copy_words_from(
  words : Array[@parser.Word],
  start : Int,
) -> Array[@parser.Word] {
  let copied : Array[@parser.Word] = []
  let mut i = start
  while i < words.length() {
    copied.push(words[i])
    i += 1
  }
  copied
}

///|
fn plain_literal_text(word : @parser.Word) -> String? {
  let buf = StringBuilder::new()
  for part in word.parts {
    match part {
      @parser.WordPart::Literal(text) => buf.write_string(text)
      _ => return None
    }
  }
  Some(buf.to_string())
}

///|
fn path_basename(path : String) -> String {
  let view = path[:]
  let mut start = 0
  let mut i = 0
  while i < view.length() {
    if view[i] == '/' {
      start = i + 1
    }
    i += 1
  }
  path.view(start_offset=start).to_string()
}

///|
fn effective_simple_word_index(words : Array[@parser.Word]) -> Int? {
  guard words.length() > 0 else { return None }
  let direct_name = match literal_text(words[0]) {
    Some(name) => name
    None => return Some(0)
  }
  match direct_name {
    "busybox" | "builtin" | "run" =>
      match wrapper_effective_word_index(words, 1, []) {
        Some(index) => Some(index)
        None => Some(0)
      }
    "command" =>
      match wrapper_effective_word_index(words, 1, ["-p"]) {
        Some(index) => Some(index)
        None => Some(0)
      }
    "exec" =>
      match exec_effective_word_index(words) {
        Some(index) => Some(index)
        None => Some(0)
      }
    _ => Some(0)
  }
}

///|
fn wrapper_effective_word_index(
  words : Array[@parser.Word],
  start : Int,
  pass_through_options : Array[String],
) -> Int? {
  let mut i = start
  while i < words.length() {
    match plain_literal_text(words[i]) {
      Some(text) if text == "--" => {
        if i + 1 < words.length() {
          return Some(i + 1)
        }
        return None
      }
      Some(text) if pass_through_options.any(fn(option) { option == text }) =>
        i += 1
      Some(text) if text.has_prefix("-") => return None
      Some(_) => return Some(i)
      None =>
        match literal_text(words[i]) {
          Some(text) if text.has_prefix("-") => return None
          Some(_) => return Some(i)
          None =>
            match leading_shell_text(words[i]) {
              Some(text) if text.has_prefix("-") => return None
              _ => return Some(i)
            }
        }
    }
  }
  None
}

///|
fn exec_effective_word_index(words : Array[@parser.Word]) -> Int? {
  let mut i = 1
  while i < words.length() {
    match literal_text(words[i]) {
      Some(text) => {
        if text == "--" {
          if i + 1 < words.length() {
            return Some(i + 1)
          }
          return None
        }
        if text == "-" || !text.has_prefix("-") {
          return Some(i)
        }
        if text.has_prefix("--") {
          return None
        }
        let view = text.view()
        let mut j = 1
        let mut valid = true
        let mut consumes_next = false
        while j < view.length() {
          match view[j] {
            'c' | 'l' => j += 1
            'a' => {
              if j + 1 == view.length() {
                consumes_next = true
              }
              j = view.length()
            }
            _ => {
              valid = false
              j = view.length()
            }
          }
        }
        if !valid {
          return None
        }
        if consumes_next {
          i += 1
          if i >= words.length() {
            return None
          }
        }
        i += 1
      }
      None =>
        match leading_shell_text(words[i]) {
          Some(text) if text.has_prefix("-") => return None
          _ => return Some(i)
        }
    }
  }
  None
}
