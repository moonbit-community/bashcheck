///|
fn append_analytics_batch_t_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_t_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_t_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2007,
      severity: Style,
      category: "analytics",
      summary: "Use $((..)) instead of deprecated $[..].",
    },
    {
      code: 2084,
      severity: Error,
      category: "analytics",
      summary: "Standalone $((..)) in command position executes its result.",
    },
    {
      code: 2089,
      severity: Warning,
      category: "analytics",
      summary: "Quoted/backslashed fragments stored in scalars stay literal later.",
    },
    {
      code: 2090,
      severity: Warning,
      category: "analytics",
      summary: "Scalar expansions do not re-apply quotes or backslashes later.",
    },
    {
      code: 2091,
      severity: Warning,
      category: "analytics",
      summary: "Remove surrounding $() to avoid executing output.",
    },
    {
      code: 2092,
      severity: Warning,
      category: "analytics",
      summary: "Remove backticks to avoid executing output.",
    },
    {
      code: 2093,
      severity: Warning,
      category: "analytics",
      summary: "Remove exec if the script should continue afterward.",
    },
    {
      code: 2094,
      severity: Info,
      category: "analytics",
      summary: "Avoid reading and writing the same file in one pipeline.",
    },
    {
      code: 2116,
      severity: Style,
      category: "analytics",
      summary: "Avoid echo inside command substitutions when plain words suffice.",
    },
    {
      code: 2209,
      severity: Warning,
      category: "analytics",
      summary: "Common command-looking assignments usually need $(...).",
    },
  ]
}

///|
fn run_analytics_batch_t_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  check_dollar_brackets(script, diagnostics)
  check_spurious_expansion_commands(script, diagnostics)
  check_quotes_in_literals(script, shell, diagnostics)
  check_spurious_exec(script, shell, diagnostics)
  check_redirect_to_same_file(script, diagnostics)
  check_useless_echo_substitutions(script, diagnostics)
  check_command_like_assignments(script, diagnostics)
}

///|
priv enum BatchTWordUsage {
  Other
  InputRedirect
  OutputRedirect
} derive(Eq)

///|
priv struct BatchTWordOccurrence {
  word : @parser.Word
  command : @parser.Command
  usage : BatchTWordUsage
}

///|
priv struct BatchTPartLocation {
  fragment : String
  relative_offset : Int
  width : Int
}

///|
fn check_dollar_brackets(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      walk_word_deep(word, fn(part) {
        match part {
          DollarBracket(expr) =>
            if dollar_bracket_span(word, expr) is Some(span) {
              push_diagnostic(
                diagnostics,
                span,
                Style,
                2007,
                "Use $((..)) instead of deprecated $[..]",
              )
            }
          _ => ()
        }
      })
    })
  })
}

///|
fn dollar_bracket_span(
  word : @parser.Word,
  expr : @parser.ArithmeticExpr,
) -> @parser.Span? {
  let fragment = "$[" + expr.raw + "]"
  if batch_t_string_offset(word.source, fragment) is Some(offset) {
    Some(batch_t_span_offset(word.span, offset, fragment.length()))
  } else {
    None
  }
}

///|
fn check_spurious_expansion_commands(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      Simple(simple) if simple.words.length() == 1 =>
        match simple.words[0].parts {
          [CommandSubstitution(_)] =>
            push_diagnostic(
              diagnostics,
              simple.words[0].span,
              Warning,
              2091,
              "Remove surrounding $() to avoid executing output (or use eval if intentional).",
            )
          [BackQuoted(_)] =>
            push_diagnostic(
              diagnostics,
              simple.words[0].span,
              Warning,
              2092,
              "Remove backticks to avoid executing output (or use eval if intentional).",
            )
          [ArithmeticExpansion(_)] =>
            push_diagnostic(
              diagnostics,
              simple.words[0].span,
              Error,
              2084,
              "Remove '$' or use '_=$((expr))' to avoid executing output.",
            )
          _ => ()
        }
      _ => ()
    }
  })
}

///|
fn check_quotes_in_literals(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let quoted_assignments : Map[String, @parser.Span] = Map([])
  let reported_origins : Array[@parser.Span] = []
  batch_t_check_quote_literals_script(
    script, shell, quoted_assignments, reported_origins, diagnostics,
  )
}

///|
fn batch_t_check_quote_literals_script(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  quoted_assignments : Map[String, @parser.Span],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for item in script.items {
    batch_t_check_quote_literals_and_or_list(
      item.and_or,
      shell,
      quoted_assignments,
      reported_origins,
      diagnostics,
    )
  }
}

///|
fn batch_t_check_quote_literals_and_or_list(
  list : @parser.AndOrList,
  shell : @semantics.ShellDialect,
  quoted_assignments : Map[String, @parser.Span],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  batch_t_check_quote_literals_pipeline(
    list.head,
    shell,
    quoted_assignments,
    reported_origins,
    diagnostics,
  )
  for pair in list.tail {
    let (_, pipeline) = pair
    batch_t_check_quote_literals_pipeline(
      pipeline, shell, quoted_assignments, reported_origins, diagnostics,
    )
  }
}

///|
fn batch_t_check_quote_literals_pipeline(
  pipeline : @parser.Pipeline,
  shell : @semantics.ShellDialect,
  quoted_assignments : Map[String, @parser.Span],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if pipeline.segments.length() == 1 {
    batch_t_check_quote_literals_command(
      pipeline.segments[0].command,
      shell,
      quoted_assignments,
      reported_origins,
      diagnostics,
      true,
    )
    return
  }
  for segment in pipeline.segments {
    let quoted_copy = batch_t_copy_quote_assignment_map(quoted_assignments)
    batch_t_check_quote_literals_command(
      segment.command,
      shell,
      quoted_copy,
      reported_origins,
      diagnostics,
      false,
    )
  }
}

///|
fn batch_t_check_quote_literals_command(
  command : @parser.Command,
  shell : @semantics.ShellDialect,
  quoted_assignments : Map[String, @parser.Span],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
  persist_writes : Bool,
) -> Unit {
  match command.kind {
    Simple(simple) =>
      batch_t_check_quote_literals_simple_command(
        command, simple, shell, quoted_assignments, reported_origins, diagnostics,
        persist_writes,
      )
    Source(source) => {
      for assignment in source.assignments {
        batch_t_check_quote_literal_assignment_value(
          assignment.value,
          command,
          shell,
          quoted_assignments,
          reported_origins,
          diagnostics,
        )
      }
      batch_t_check_quote_literal_word(
        source.path,
        command,
        SourcePath,
        shell,
        quoted_assignments,
        reported_origins,
        diagnostics,
      )
      for option in source.options {
        batch_t_check_quote_literal_word(
          option,
          command,
          SourceOption,
          shell,
          quoted_assignments,
          reported_origins,
          diagnostics,
        )
      }
      for arg in source.args {
        batch_t_check_quote_literal_word(
          arg,
          command,
          SourceArgument,
          shell,
          quoted_assignments,
          reported_origins,
          diagnostics,
        )
      }
      if source.included is Some(script) {
        batch_t_check_quote_literals_script(
          script,
          shell,
          batch_t_copy_quote_assignment_map(quoted_assignments),
          reported_origins,
          diagnostics,
        )
      }
    }
    Time(clause) =>
      batch_t_check_quote_literals_pipeline(
        clause.body,
        shell,
        quoted_assignments,
        reported_origins,
        diagnostics,
      )
    BraceGroup(script) | BatsTest({ body: script, .. }) =>
      batch_t_check_quote_literals_script(
        script, shell, quoted_assignments, reported_origins, diagnostics,
      )
    Subshell(script) =>
      batch_t_check_quote_literals_script(
        script,
        shell,
        batch_t_copy_quote_assignment_map(quoted_assignments),
        reported_origins,
        diagnostics,
      )
    If(clause) => {
      for arm in clause.arms {
        batch_t_check_quote_literals_script(
          arm.condition,
          shell,
          batch_t_copy_quote_assignment_map(quoted_assignments),
          reported_origins,
          diagnostics,
        )
        batch_t_check_quote_literals_script(
          arm.body,
          shell,
          batch_t_copy_quote_assignment_map(quoted_assignments),
          reported_origins,
          diagnostics,
        )
      }
      if clause.else_body is Some(body) {
        batch_t_check_quote_literals_script(
          body,
          shell,
          batch_t_copy_quote_assignment_map(quoted_assignments),
          reported_origins,
          diagnostics,
        )
      }
    }
    While(clause) | Until(clause) => {
      batch_t_check_quote_literals_script(
        clause.condition,
        shell,
        batch_t_copy_quote_assignment_map(quoted_assignments),
        reported_origins,
        diagnostics,
      )
      batch_t_check_quote_literals_script(
        clause.body,
        shell,
        batch_t_copy_quote_assignment_map(quoted_assignments),
        reported_origins,
        diagnostics,
      )
    }
    ForIn(clause) => {
      for value in clause.values {
        batch_t_check_quote_literal_word(
          value,
          command,
          ForValue,
          shell,
          quoted_assignments,
          reported_origins,
          diagnostics,
        )
      }
      batch_t_check_quote_literals_script(
        clause.body,
        shell,
        batch_t_copy_quote_assignment_map(quoted_assignments),
        reported_origins,
        diagnostics,
      )
    }
    Select(clause) => {
      for value in clause.values {
        batch_t_check_quote_literal_word(
          value,
          command,
          SelectValue,
          shell,
          quoted_assignments,
          reported_origins,
          diagnostics,
        )
      }
      batch_t_check_quote_literals_script(
        clause.body,
        shell,
        batch_t_copy_quote_assignment_map(quoted_assignments),
        reported_origins,
        diagnostics,
      )
    }
    Case(clause) => {
      batch_t_check_quote_literal_word(
        clause.word,
        command,
        CaseWord,
        shell,
        quoted_assignments,
        reported_origins,
        diagnostics,
      )
      for item in clause.items {
        for pattern in item.patterns {
          batch_t_check_quote_literal_word(
            pattern,
            command,
            CasePattern,
            shell,
            quoted_assignments,
            reported_origins,
            diagnostics,
          )
        }
        batch_t_check_quote_literals_script(
          item.body,
          shell,
          batch_t_copy_quote_assignment_map(quoted_assignments),
          reported_origins,
          diagnostics,
        )
      }
    }
    Condition(condition) =>
      batch_t_check_quote_literals_condition_expr(
        condition.expr,
        condition.kind,
        command,
        shell,
        quoted_assignments,
        reported_origins,
        diagnostics,
      )
    Arithmetic(command_) =>
      batch_t_check_quote_literals_arithmetic_expr(
        command_.expr,
        command,
        shell,
        quoted_assignments,
        reported_origins,
        diagnostics,
      )
    ForArithmetic(clause) => {
      batch_t_check_quote_literals_arithmetic_expr(
        clause.init,
        command,
        shell,
        quoted_assignments,
        reported_origins,
        diagnostics,
      )
      batch_t_check_quote_literals_arithmetic_expr(
        clause.condition,
        command,
        shell,
        quoted_assignments,
        reported_origins,
        diagnostics,
      )
      batch_t_check_quote_literals_arithmetic_expr(
        clause.step,
        command,
        shell,
        quoted_assignments,
        reported_origins,
        diagnostics,
      )
      batch_t_check_quote_literals_script(
        clause.body,
        shell,
        batch_t_copy_quote_assignment_map(quoted_assignments),
        reported_origins,
        diagnostics,
      )
    }
    CoProc(clause) => {
      if clause.name is Some(name) {
        batch_t_check_quote_literal_word(
          name,
          command,
          CoProcName,
          shell,
          quoted_assignments,
          reported_origins,
          diagnostics,
        )
      }
      batch_t_check_quote_literals_command(
        clause.body,
        shell,
        batch_t_copy_quote_assignment_map(quoted_assignments),
        reported_origins,
        diagnostics,
        false,
      )
    }
    Function(_) => ()
  }
}

///|
fn batch_t_check_quote_literals_simple_command(
  command : @parser.Command,
  simple : @parser.SimpleCommand,
  shell : @semantics.ShellDialect,
  quoted_assignments : Map[String, @parser.Span],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
  persist_writes : Bool,
) -> Unit {
  let persistent_assignments = persist_writes && simple.words.length() == 0
  for assignment in simple.assignments {
    batch_t_check_quote_literal_assignment_value(
      assignment.value,
      command,
      shell,
      quoted_assignments,
      reported_origins,
      diagnostics,
    )
    if persistent_assignments {
      batch_t_update_quote_literal_assignment_state(
        quoted_assignments,
        assignment,
        batch_t_assignment_value_quote_origin(
          assignment.value,
          quoted_assignments,
        ),
      )
    }
  }
  if simple.words.length() == 0 {
    return
  }
  batch_t_check_quote_literal_word(
    simple.words[0],
    command,
    CommandName,
    shell,
    quoted_assignments,
    reported_origins,
    diagnostics,
  )
  let mut i = 1
  while i < simple.words.length() {
    batch_t_check_quote_literal_word(
      simple.words[i],
      command,
      CommandArgument,
      shell,
      quoted_assignments,
      reported_origins,
      diagnostics,
    )
    i += 1
  }
}

///|
fn batch_t_check_quote_literal_assignment_value(
  value : @parser.AssignmentValue,
  command : @parser.Command,
  shell : @semantics.ShellDialect,
  quoted_assignments : Map[String, @parser.Span],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match value {
    Word(word) =>
      batch_t_check_quote_literal_word(
        word,
        command,
        AssignmentValue,
        shell,
        quoted_assignments,
        reported_origins,
        diagnostics,
      )
    ArrayLiteral(elements) =>
      for element in elements {
        batch_t_check_quote_literal_assignment_value(
          element.value,
          command,
          shell,
          quoted_assignments,
          reported_origins,
          diagnostics,
        )
      }
    Empty => ()
  }
}

///|
fn batch_t_update_quote_literal_assignment_state(
  quoted_assignments : Map[String, @parser.Span],
  assignment : @parser.Assignment,
  origin : @parser.Span?,
) -> Unit {
  if assignment.append ||
    assignment.indexes.length() > 0 ||
    assignment.value is ArrayLiteral(_) {
    quoted_assignments.remove(assignment.name)
    return
  }
  if origin is Some(span) {
    quoted_assignments.set(assignment.name, span)
  } else {
    quoted_assignments.remove(assignment.name)
  }
}

///|
fn batch_t_assignment_value_quote_origin(
  value : @parser.AssignmentValue,
  quoted_assignments : Map[String, @parser.Span],
) -> @parser.Span? {
  match value {
    Word(word) => batch_t_word_quote_origin(word, quoted_assignments)
    ArrayLiteral(_) | Empty => None
  }
}

///|
fn batch_t_word_quote_origin(
  word : @parser.Word,
  quoted_assignments : Map[String, @parser.Span],
) -> @parser.Span? {
  batch_t_parts_quote_origin(
    word,
    word.parts,
    word.source,
    0,
    quoted_assignments,
  )
}

///|
fn batch_t_parts_quote_origin(
  word : @parser.Word,
  parts : Array[@parser.WordPart],
  raw : String,
  base_offset : Int,
  quoted_assignments : Map[String, @parser.Span],
) -> @parser.Span? {
  let mut offset = 0
  for part in parts {
    let location = batch_t_part_location(raw, offset, part)
    let absolute_offset = base_offset + location.relative_offset
    match part {
      Parameter(name) =>
        if quoted_assignments.get(name) is Some(span) {
          return Some(span)
        }
      BracedParameter(expansion) =>
        if batch_t_plain_braced_reference_name(expansion) is Some(name) {
          if quoted_assignments.get(name) is Some(span) {
            return Some(span)
          }
        }
      DoubleQuoted(nested) =>
        if batch_t_parts_quote_origin(
            word,
            nested,
            batch_t_trim_outer_fragment(location.fragment, 1),
            absolute_offset + 1,
            quoted_assignments,
          )
          is Some(span) {
          return Some(span)
        }
      DollarDoubleQuoted(nested) =>
        if batch_t_parts_quote_origin(
            word,
            nested,
            batch_t_trim_outer_fragment(location.fragment, 2),
            absolute_offset + 2,
            quoted_assignments,
          )
          is Some(span) {
          return Some(span)
        }
      Literal(text)
      | SingleQuoted(text)
      | DollarSingleQuoted(text)
      | Glob(text) =>
        if batch_t_text_contains_quote_literals(text) {
          return Some(
            batch_t_span_offset(word.span, absolute_offset, location.width),
          )
        }
      _ => ()
    }
    offset = location.relative_offset + location.width
  }
  None
}

///|
fn batch_t_check_quote_literal_word(
  word : @parser.Word,
  command : @parser.Command,
  place : WordPlace,
  shell : @semantics.ShellDialect,
  quoted_assignments : Map[String, @parser.Span],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let skip_eval = place == CommandArgument &&
    @semantics.effective_command_name(command) == Some("eval")
  batch_t_check_quote_literal_word_parts(
    word,
    word.parts,
    word.source,
    0,
    false,
    skip_eval,
    shell,
    quoted_assignments,
    reported_origins,
    diagnostics,
  )
}

///|
fn batch_t_check_quote_literal_word_parts(
  word : @parser.Word,
  parts : Array[@parser.WordPart],
  raw : String,
  base_offset : Int,
  quoted_context : Bool,
  skip_eval : Bool,
  shell : @semantics.ShellDialect,
  quoted_assignments : Map[String, @parser.Span],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut offset = 0
  for part in parts {
    let location = batch_t_part_location(raw, offset, part)
    let span = batch_t_span_offset(
      word.span,
      base_offset + location.relative_offset,
      location.width,
    )
    match part {
      Parameter(name) =>
        if !quoted_context && !skip_eval {
          batch_t_maybe_push_quote_literal_read(
            name, span, shell, quoted_assignments, reported_origins, diagnostics,
          )
        }
      BracedParameter(expansion) =>
        if !quoted_context && !skip_eval {
          if batch_t_plain_braced_reference_name(expansion) is Some(name) {
            batch_t_maybe_push_quote_literal_read(
              name, span, shell, quoted_assignments, reported_origins, diagnostics,
            )
          }
        }
      DoubleQuoted(nested) =>
        batch_t_check_quote_literal_word_parts(
          word,
          nested,
          batch_t_trim_outer_fragment(location.fragment, 1),
          base_offset + location.relative_offset + 1,
          true,
          skip_eval,
          shell,
          quoted_assignments,
          reported_origins,
          diagnostics,
        )
      DollarDoubleQuoted(nested) =>
        batch_t_check_quote_literal_word_parts(
          word,
          nested,
          batch_t_trim_outer_fragment(location.fragment, 2),
          base_offset + location.relative_offset + 2,
          true,
          skip_eval,
          shell,
          quoted_assignments,
          reported_origins,
          diagnostics,
        )
      _ => ()
    }
    offset = location.relative_offset + location.width
  }
}

///|
fn batch_t_check_quote_literals_condition_expr(
  expr : @parser.ConditionExpr,
  kind : @parser.ConditionKind,
  command : @parser.Command,
  shell : @semantics.ShellDialect,
  quoted_assignments : Map[String, @parser.Span],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let place = match kind {
    SingleBracket => WordPlace::ConditionSingleBracket
    DoubleBracket => ConditionDoubleBracket
  }
  match expr {
    Empty => ()
    Word(word) =>
      batch_t_check_quote_literal_word(
        word, command, place, shell, quoted_assignments, reported_origins, diagnostics,
      )
    Unary(_, _, word) =>
      batch_t_check_quote_literal_word(
        word, command, place, shell, quoted_assignments, reported_origins, diagnostics,
      )
    Binary(_, _, lhs, rhs) => {
      batch_t_check_quote_literal_word(
        lhs, command, place, shell, quoted_assignments, reported_origins, diagnostics,
      )
      batch_t_check_quote_literal_word(
        rhs, command, place, shell, quoted_assignments, reported_origins, diagnostics,
      )
    }
    Group(inner) | Not(inner) =>
      batch_t_check_quote_literals_condition_expr(
        inner, kind, command, shell, quoted_assignments, reported_origins, diagnostics,
      )
    And(_, lhs, rhs) | Or(_, lhs, rhs) => {
      batch_t_check_quote_literals_condition_expr(
        lhs, kind, command, shell, quoted_assignments, reported_origins, diagnostics,
      )
      batch_t_check_quote_literals_condition_expr(
        rhs, kind, command, shell, quoted_assignments, reported_origins, diagnostics,
      )
    }
  }
}

///|
fn batch_t_check_quote_literals_arithmetic_expr(
  expr : @parser.ArithmeticExpr,
  command : @parser.Command,
  shell : @semantics.ShellDialect,
  quoted_assignments : Map[String, @parser.Span],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for token in expr.tokens {
    match token {
      Expansion(word) =>
        batch_t_check_quote_literal_word(
          word,
          command,
          ArithmeticWord,
          shell,
          quoted_assignments,
          reported_origins,
          diagnostics,
        )
      Group(inner) =>
        batch_t_check_quote_literals_arithmetic_expr(
          inner, command, shell, quoted_assignments, reported_origins, diagnostics,
        )
      _ => ()
    }
  }
}

///|
fn batch_t_maybe_push_quote_literal_read(
  name : String,
  span : @parser.Span,
  shell : @semantics.ShellDialect,
  quoted_assignments : Map[String, @parser.Span],
  reported_origins : Array[@parser.Span],
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if quoted_assignments.get(name) is Some(origin) {
    if !reported_origins.any(fn(existing) { existing == origin }) {
      reported_origins.push(origin)
      push_diagnostic(
        diagnostics,
        origin,
        Warning,
        2089,
        batch_t_quote_literal_assignment_message(shell),
      )
    }
    push_diagnostic(
      diagnostics,
      span,
      Warning,
      2090,
      "Quotes/backslashes in this variable will not be respected.",
    )
  }
}

///|
fn batch_t_quote_literal_assignment_message(
  shell : @semantics.ShellDialect,
) -> String {
  if shell_is_posix_sh(shell) {
    "Quotes/backslashes will be treated literally. Rewrite using set/\"$@\" or functions."
  } else {
    "Quotes/backslashes will be treated literally. Use an array."
  }
}

///|
fn batch_t_plain_braced_reference_name(
  expansion : @parser.ParameterExpansion,
) -> String? {
  guard !expansion.length_prefix else { return None }
  guard !expansion.indirect else { return None }
  guard expansion.index is None else { return None }
  guard expansion.operator is None else { return None }
  expansion.name
}

///|
fn batch_t_text_contains_quote_literals(text : String) -> Bool {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    if view[i] == '"' {
      return true
    }
    if view[i] == '\\' && i + 1 < view.length() && view[i + 1] == ' ' {
      return true
    }
    if view[i] == '\'' {
      let prefix_match = i == 0 ||
        view[i - 1] == '/' ||
        view[i - 1] == '=' ||
        view[i - 1] == ' '
      let suffix_match = i + 1 == view.length() || view[i + 1] == ' '
      if prefix_match || suffix_match {
        return true
      }
    }
    i += 1
  }
  false
}

///|
fn batch_t_part_location(
  raw : String,
  offset : Int,
  part : @parser.WordPart,
) -> BatchTPartLocation {
  let remaining = if offset <= 0 {
    raw
  } else if offset >= raw.length() {
    ""
  } else {
    raw.view(start_offset=offset).to_owned()
  }
  let fragment = analytics_bad_parameter_part_fragment(part, remaining)
  let relative_offset = if analytics_string_offset(remaining, fragment)
    is Some(inner) {
    offset + inner
  } else {
    offset
  }
  let available = if relative_offset >= raw.length() {
    0
  } else {
    raw.length() - relative_offset
  }
  let width = if fragment.length() <= available {
    fragment.length()
  } else {
    available
  }
  { fragment, relative_offset, width }
}

///|
fn batch_t_trim_outer_fragment(fragment : String, prefix_width : Int) -> String {
  if fragment.length() <= prefix_width + 1 {
    return ""
  }
  fragment
  .view(start_offset=prefix_width, end_offset=fragment.length() - 1)
  .to_owned()
}

///|
fn batch_t_copy_quote_assignment_map(
  source : Map[String, @parser.Span],
) -> Map[String, @parser.Span] {
  let copied : Map[String, @parser.Span] = Map([])
  source.each(fn(name, span) { copied.set(name, span) })
  copied
}

///|
fn check_spurious_exec(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if @semantics.has_execfail(script, shell) {
    return
  }
  check_spurious_exec_script(script, false, diagnostics)
}

///|
fn check_spurious_exec_script(
  script : @parser.Script,
  in_loop : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let items = strip_trailing_exec_cleanup(script.items)
  let mut i = 0
  while i < items.length() {
    let item = items[i]
    if in_loop || i + 1 < items.length() {
      maybe_push_spurious_exec_from_list_item(item, diagnostics)
    }
    visit_spurious_exec_nested_in_list_item(item, diagnostics)
    i += 1
  }
}

///|
fn strip_trailing_exec_cleanup(
  items : Array[@parser.ListItem],
) -> Array[@parser.ListItem] {
  let stripped : Array[@parser.ListItem] = []
  for item in items {
    stripped.push(item)
  }
  while stripped.length() > 0 &&
        list_item_is_exec_cleanup(stripped[stripped.length() - 1]) {
    let _ = stripped.pop()
  }
  stripped
}

///|
fn list_item_is_exec_cleanup(item : @parser.ListItem) -> Bool {
  if item.and_or.tail.length() != 0 {
    return false
  }
  let pipeline = item.and_or.head
  if pipeline.segments.length() != 1 {
    return false
  }
  let command = pipeline.segments[0].command
  match command.kind {
    Simple(simple) =>
      if simple.words.length() == 0 {
        simple.assignments.length() > 0
      } else {
        match @semantics.literal_text(simple.words[0]) {
          Some(":")
          | Some("echo")
          | Some("exit")
          | Some("printf")
          | Some("return") => true
          _ => false
        }
      }
    _ => false
  }
}

///|
fn maybe_push_spurious_exec_from_list_item(
  item : @parser.ListItem,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if item.and_or.tail.length() != 0 {
    return
  }
  let pipeline = item.and_or.head
  if pipeline.segments.length() != 1 {
    return
  }
  let command = pipeline.segments[0].command
  match command.kind {
    Simple(simple) =>
      match simple.words {
        [first, _, ..] if @semantics.literal_text(first) == Some("exec") =>
          push_diagnostic(
            diagnostics,
            command.span,
            Warning,
            2093,
            "Remove \"exec \" if script should continue after this command.",
          )
        _ => ()
      }
    _ => ()
  }
}

///|
fn visit_spurious_exec_nested_in_list_item(
  item : @parser.ListItem,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_spurious_exec_nested_in_pipeline(item.and_or.head, diagnostics)
  for pair in item.and_or.tail {
    let (_, pipeline) = pair
    visit_spurious_exec_nested_in_pipeline(pipeline, diagnostics)
  }
}

///|
fn visit_spurious_exec_nested_in_pipeline(
  pipeline : @parser.Pipeline,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for segment in pipeline.segments {
    visit_spurious_exec_nested_in_command(segment.command, diagnostics)
  }
}

///|
fn visit_spurious_exec_nested_in_command(
  command : @parser.Command,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  match command.kind {
    Source(source) =>
      if source.included is Some(script) {
        check_spurious_exec_script(script, false, diagnostics)
      }
    Time(clause) =>
      visit_spurious_exec_nested_in_pipeline(clause.body, diagnostics)
    Subshell(script) | BraceGroup(script) | BatsTest({ body: script, .. }) =>
      check_spurious_exec_script(script, false, diagnostics)
    If(clause) => {
      for arm in clause.arms {
        check_spurious_exec_script(arm.condition, false, diagnostics)
        check_spurious_exec_script(arm.body, false, diagnostics)
      }
      if clause.else_body is Some(body) {
        check_spurious_exec_script(body, false, diagnostics)
      }
    }
    While(clause) | Until(clause) => {
      check_spurious_exec_script(clause.condition, false, diagnostics)
      check_spurious_exec_script(clause.body, true, diagnostics)
    }
    ForIn(clause) => check_spurious_exec_script(clause.body, true, diagnostics)
    ForArithmetic(clause) =>
      check_spurious_exec_script(clause.body, true, diagnostics)
    Select(clause) => check_spurious_exec_script(clause.body, true, diagnostics)
    Case(clause) =>
      for item in clause.items {
        check_spurious_exec_script(item.body, false, diagnostics)
      }
    Function(function_) =>
      visit_spurious_exec_nested_in_command(function_.body, diagnostics)
    CoProc(clause) =>
      visit_spurious_exec_nested_in_command(clause.body, diagnostics)
    Simple(_) | Condition(_) | Arithmetic(_) => ()
  }
}

///|
fn check_redirect_to_same_file(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_pipelines(script, fn(pipeline) {
    let occurrences = batch_t_pipeline_occurrences(pipeline)
    let reported : Array[BatchTWordOccurrence] = []
    let mut i = 0
    while i < occurrences.length() {
      let mut j = i + 1
      while j < occurrences.length() {
        if batch_t_redirect_conflict(occurrences[i], occurrences[j]) {
          let message = "Make sure not to read and write the same file in the same pipeline."
          batch_t_push_redirect_conflict(
            diagnostics,
            reported,
            occurrences[i],
            message,
          )
          batch_t_push_redirect_conflict(
            diagnostics,
            reported,
            occurrences[j],
            message,
          )
        }
        j += 1
      }
      i += 1
    }
  })
}

///|
fn batch_t_pipeline_occurrences(
  pipeline : @parser.Pipeline,
) -> Array[BatchTWordOccurrence] {
  let occurrences : Array[BatchTWordOccurrence] = []
  for segment in pipeline.segments {
    batch_t_collect_command_occurrences(segment.command, occurrences)
  }
  occurrences
}

///|
fn batch_t_collect_command_occurrences(
  command : @parser.Command,
  occurrences : Array[BatchTWordOccurrence],
) -> Unit {
  visit_direct_words_in_command(command, fn(word, place) {
    match place {
      AssignmentValue | RedirectionTarget => ()
      _ => occurrences.push({ word, command, usage: Other })
    }
  })
  for redirect in command.redirects {
    let usage = match redirect.op {
      Read => Some(BatchTWordUsage::InputRedirect)
      Write | Append => Some(OutputRedirect)
      _ => None
    }
    match (usage, redirect.target) {
      (Some(usage), Word(word)) => occurrences.push({ word, command, usage })
      _ => ()
    }
  }
}

///|
fn batch_t_push_redirect_conflict(
  diagnostics : Array[CheckDiagnostic],
  reported : Array[BatchTWordOccurrence],
  occurrence : BatchTWordOccurrence,
  message : String,
) -> Unit {
  if reported.any(fn(existing) { existing.word.span == occurrence.word.span }) {
    return
  }
  reported.push(occurrence)
  push_diagnostic(diagnostics, occurrence.word.span, Info, 2094, message)
}

///|
fn batch_t_redirect_conflict(
  lhs : BatchTWordOccurrence,
  rhs : BatchTWordOccurrence,
) -> Bool {
  if lhs.word.span == rhs.word.span {
    return false
  }
  if lhs.word.source != rhs.word.source {
    return false
  }
  if lhs.usage == Other && rhs.usage == Other {
    return false
  }
  if lhs.usage == rhs.usage && lhs.usage != Other {
    return false
  }
  if batch_t_special_redirect_word(lhs.word) ||
    batch_t_special_redirect_word(rhs.word) {
    return false
  }
  if batch_t_redirect_harmless_command(lhs.command) ||
    batch_t_redirect_harmless_command(rhs.command) {
    return false
  }
  true
}

///|
fn check_useless_echo_substitutions(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      walk_word_deep(word, fn(part) {
        match part {
          CommandSubstitution(subscript) | BackQuoted(subscript) =>
            batch_t_maybe_warn_useless_echo(word, part, subscript, diagnostics)
          _ => ()
        }
      })
    })
  })
}

///|
fn batch_t_maybe_warn_useless_echo(
  word : @parser.Word,
  part : @parser.WordPart,
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let command = if batch_t_single_substitution_command(script) is Some(command) {
    command
  } else {
    return
  }
  guard command_matches_exact_name(command, "echo") else { return }
  let arguments = @semantics.command_arguments(command)
  guard arguments.length() > 0 else { return }
  guard !batch_t_echo_just_wraps_command_output(arguments) else { return }
  guard !batch_t_echo_argument_looks_like_flag(arguments[0]) else { return }
  guard arguments.all(batch_t_echo_argument_can_be_inlined) else { return }
  push_diagnostic(
    diagnostics,
    batch_t_substitution_span(word, part),
    Style,
    2116,
    "Useless echo? Instead of 'cmd $(echo foo)', just use 'cmd foo'.",
  )
}

///|
fn batch_t_single_substitution_command(
  script : @parser.Script,
) -> @parser.Command? {
  match script.items {
    [item] if item.and_or.tail.length() == 0 => {
      let pipeline = item.and_or.head
      match pipeline.segments {
        [segment] => Some(segment.command)
        _ => None
      }
    }
    _ => None
  }
}

///|
fn batch_t_echo_just_wraps_command_output(
  arguments : Array[@parser.Word],
) -> Bool {
  match arguments {
    [first] => word_is_just_command_output(first)
    _ => false
  }
}

///|
fn batch_t_echo_argument_looks_like_flag(word : @parser.Word) -> Bool {
  if @semantics.literal_text(word) is Some(text) {
    text.has_prefix("-")
  } else {
    false
  }
}

///|
fn batch_t_echo_argument_can_be_inlined(word : @parser.Word) -> Bool {
  batch_t_word_parts_can_be_inlined(word.parts)
}

///|
fn batch_t_word_parts_can_be_inlined(parts : Array[@parser.WordPart]) -> Bool {
  for part in parts {
    match part {
      Glob(_) | ExtGlob(_) | BraceExpansion(_) => return false
      DoubleQuoted(nested) | DollarDoubleQuoted(nested) =>
        if !batch_t_word_parts_can_be_inlined(nested) {
          return false
        }
      _ => ()
    }
  }
  true
}

///|
fn batch_t_substitution_span(
  word : @parser.Word,
  part : @parser.WordPart,
) -> @parser.Span {
  if batch_t_substitution_fragment(word.source, part) is Some(fragment) {
    if batch_t_string_offset(word.source, fragment) is Some(offset) {
      batch_t_span_offset(word.span, offset, fragment.length())
    } else {
      word.span
    }
  } else {
    word.span
  }
}

///|
fn batch_t_substitution_fragment(
  raw : String,
  part : @parser.WordPart,
) -> String? {
  match part {
    CommandSubstitution(_) =>
      if batch_t_string_offset(raw, "$(") is Some(offset) {
        let fragment = raw.view(start_offset=offset).to_owned()
        Some(
          fragment
          .view(end_offset=analytics_command_substitution_width(fragment))
          .to_owned(),
        )
      } else {
        None
      }
    BackQuoted(_) =>
      if batch_t_string_offset(raw, "`") is Some(offset) {
        let fragment = raw.view(start_offset=offset).to_owned()
        Some(
          fragment
          .view(end_offset=analytics_backquoted_width(fragment))
          .to_owned(),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn batch_t_special_redirect_word(word : @parser.Word) -> Bool {
  if @semantics.literal_text(word) is Some(text) {
    text.has_prefix("/dev/")
  } else {
    false
  }
}

///|
fn batch_t_redirect_harmless_command(command : @parser.Command) -> Bool {
  match @semantics.command_basename(command) {
    Some("echo") | Some("mapfile") | Some("printf") | Some("sponge") => true
    _ => false
  }
}

///|
fn check_command_like_assignments(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let common_commands = @semantics.common_command_names()
  visit_script_commands(script, fn(command) {
    match command.kind {
      Simple(simple) if simple.assignments.length() == 1 => {
        let assignment = simple.assignments[0]
        if assignment.append || assignment.indexes.length() > 0 {
          return
        }
        let command_name = match assignment.value {
          Word(word) => unquoted_assignment_text(word)
          _ => None
        }
        match command_name {
          Some(name) if common_commands.contains(name) &&
            !assignment_word_is_command_argument(simple.words) => {
            let span = if simple.words.length() > 0 {
              command.span
            } else {
              assignment_name_span(assignment)
            }
            push_diagnostic(
              diagnostics,
              span,
              Warning,
              2209,
              "Use var=$(command) to assign output (or quote to assign string).",
            )
          }
          _ => ()
        }
      }
      _ => ()
    }
  })
}

///|
fn assignment_word_is_command_argument(words : Array[@parser.Word]) -> Bool {
  if words.get(0) is Some(word) {
    @semantics.is_glob_word(word) || @semantics.is_unquoted_flag(word)
  } else {
    false
  }
}

///|
fn unquoted_assignment_text(word : @parser.Word) -> String? {
  let buf = StringBuilder::new()
  for part in word.parts {
    match part {
      Literal(text) | Glob(text) => buf.write_string(text)
      _ => return None
    }
  }
  Some(buf.to_string())
}

///|
fn batch_t_string_offset(text : String, needle : String) -> Int? {
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
fn batch_t_span_offset(
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
