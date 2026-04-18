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
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Use $((..)) instead of deprecated $[..].",
    },
    {
      code: 2084,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Standalone $((..)) in command position executes its result.",
    },
    {
      code: 2091,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Remove surrounding $() to avoid executing output.",
    },
    {
      code: 2092,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Remove backticks to avoid executing output.",
    },
    {
      code: 2093,
      severity: CheckSeverity::Warning,
      category: "analytics",
      summary: "Remove exec if the script should continue afterward.",
    },
    {
      code: 2094,
      severity: CheckSeverity::Info,
      category: "analytics",
      summary: "Avoid reading and writing the same file in one pipeline.",
    },
    {
      code: 2116,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Avoid echo inside command substitutions when plain words suffice.",
    },
    {
      code: 2209,
      severity: CheckSeverity::Warning,
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
fn check_dollar_brackets(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    visit_direct_words_in_command(command, fn(word, _) {
      walk_word_deep(word, fn(part) {
        match part {
          @parser.WordPart::DollarBracket(expr) =>
            match dollar_bracket_span(word, expr) {
              Some(span) =>
                push_diagnostic(
                  diagnostics,
                  span,
                  CheckSeverity::Style,
                  2007,
                  "Use $((..)) instead of deprecated $[..]",
                )
              None => ()
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
  match batch_t_string_offset(word.source, fragment) {
    Some(offset) =>
      Some(batch_t_span_offset(word.span, offset, fragment.length()))
    None => None
  }
}

///|
fn check_spurious_expansion_commands(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::Simple(simple) if simple.words.length() == 1 =>
        match simple.words[0].parts {
          [@parser.WordPart::CommandSubstitution(_)] =>
            push_diagnostic(
              diagnostics,
              simple.words[0].span,
              CheckSeverity::Warning,
              2091,
              "Remove surrounding $() to avoid executing output (or use eval if intentional).",
            )
          [@parser.WordPart::BackQuoted(_)] =>
            push_diagnostic(
              diagnostics,
              simple.words[0].span,
              CheckSeverity::Warning,
              2092,
              "Remove backticks to avoid executing output (or use eval if intentional).",
            )
          [@parser.WordPart::ArithmeticExpansion(_)] =>
            push_diagnostic(
              diagnostics,
              simple.words[0].span,
              CheckSeverity::Error,
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
    @parser.CommandKind::Simple(simple) =>
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
    @parser.CommandKind::Simple(simple) =>
      match simple.words {
        [first, _, ..] if @semantics.literal_text(first) == Some("exec") =>
          push_diagnostic(
            diagnostics,
            command.span,
            CheckSeverity::Warning,
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
    @parser.CommandKind::Source(source) =>
      match source.included {
        Some(script) => check_spurious_exec_script(script, false, diagnostics)
        None => ()
      }
    @parser.CommandKind::Time(clause) =>
      visit_spurious_exec_nested_in_pipeline(clause.body, diagnostics)
    @parser.CommandKind::Subshell(script)
    | @parser.CommandKind::BraceGroup(script)
    | @parser.CommandKind::BatsTest({ body: script, .. }) =>
      check_spurious_exec_script(script, false, diagnostics)
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        check_spurious_exec_script(arm.condition, false, diagnostics)
        check_spurious_exec_script(arm.body, false, diagnostics)
      }
      match clause.else_body {
        Some(body) => check_spurious_exec_script(body, false, diagnostics)
        None => ()
      }
    }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) => {
      check_spurious_exec_script(clause.condition, false, diagnostics)
      check_spurious_exec_script(clause.body, true, diagnostics)
    }
    @parser.CommandKind::ForIn(clause) =>
      check_spurious_exec_script(clause.body, true, diagnostics)
    @parser.CommandKind::ForArithmetic(clause) =>
      check_spurious_exec_script(clause.body, true, diagnostics)
    @parser.CommandKind::Select(clause) =>
      check_spurious_exec_script(clause.body, true, diagnostics)
    @parser.CommandKind::Case(clause) =>
      for item in clause.items {
        check_spurious_exec_script(item.body, false, diagnostics)
      }
    @parser.CommandKind::Function(function_) =>
      visit_spurious_exec_nested_in_command(function_.body, diagnostics)
    @parser.CommandKind::CoProc(clause) =>
      visit_spurious_exec_nested_in_command(clause.body, diagnostics)
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_) => ()
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
      WordPlace::AssignmentValue | WordPlace::RedirectionTarget => ()
      _ => occurrences.push({ word, command, usage: BatchTWordUsage::Other })
    }
  })
  for redirect in command.redirects {
    let usage = match redirect.op {
      @parser.RedirectionOperator::Read => Some(BatchTWordUsage::InputRedirect)
      @parser.RedirectionOperator::Write
      | @parser.RedirectionOperator::Append =>
        Some(BatchTWordUsage::OutputRedirect)
      _ => None
    }
    match (usage, redirect.target) {
      (Some(usage), @parser.RedirectionTarget::Word(word)) =>
        occurrences.push({ word, command, usage })
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
  push_diagnostic(
    diagnostics,
    occurrence.word.span,
    CheckSeverity::Info,
    2094,
    message,
  )
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
  if lhs.usage == BatchTWordUsage::Other && rhs.usage == BatchTWordUsage::Other {
    return false
  }
  if lhs.usage == rhs.usage && lhs.usage != BatchTWordUsage::Other {
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
          @parser.WordPart::CommandSubstitution(subscript)
          | @parser.WordPart::BackQuoted(subscript) =>
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
  let command = match batch_t_single_substitution_command(script) {
    Some(command) => command
    None => return
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
    CheckSeverity::Style,
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
  match @semantics.literal_text(word) {
    Some(text) => text.has_prefix("-")
    None => false
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
      @parser.WordPart::Glob(_)
      | @parser.WordPart::ExtGlob(_)
      | @parser.WordPart::BraceExpansion(_) => return false
      @parser.WordPart::DoubleQuoted(nested)
      | @parser.WordPart::DollarDoubleQuoted(nested) =>
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
  match batch_t_substitution_fragment(word.source, part) {
    Some(fragment) =>
      match batch_t_string_offset(word.source, fragment) {
        Some(offset) =>
          batch_t_span_offset(word.span, offset, fragment.length())
        None => word.span
      }
    None => word.span
  }
}

///|
fn batch_t_substitution_fragment(
  raw : String,
  part : @parser.WordPart,
) -> String? {
  match part {
    @parser.WordPart::CommandSubstitution(_) =>
      match batch_t_string_offset(raw, "$(") {
        Some(offset) => {
          let fragment = raw.view(start_offset=offset).to_string()
          Some(
            fragment
            .view(end_offset=analytics_command_substitution_width(fragment))
            .to_string(),
          )
        }
        None => None
      }
    @parser.WordPart::BackQuoted(_) =>
      match batch_t_string_offset(raw, "`") {
        Some(offset) => {
          let fragment = raw.view(start_offset=offset).to_string()
          Some(
            fragment
            .view(end_offset=analytics_backquoted_width(fragment))
            .to_string(),
          )
        }
        None => None
      }
    _ => None
  }
}

///|
fn batch_t_special_redirect_word(word : @parser.Word) -> Bool {
  match @semantics.literal_text(word) {
    Some(text) => text.has_prefix("/dev/")
    None => false
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
      @parser.CommandKind::Simple(simple) if simple.assignments.length() == 1 => {
        let assignment = simple.assignments[0]
        if assignment.append || assignment.indexes.length() > 0 {
          return
        }
        let command_name = match assignment.value {
          @parser.AssignmentValue::Word(word) => unquoted_assignment_text(word)
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
              CheckSeverity::Warning,
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
  match words.get(0) {
    Some(word) =>
      @semantics.is_glob_word(word) || @semantics.is_unquoted_flag(word)
    None => false
  }
}

///|
fn unquoted_assignment_text(word : @parser.Word) -> String? {
  let buf = StringBuilder::new()
  for part in word.parts {
    match part {
      @parser.WordPart::Literal(text) | @parser.WordPart::Glob(text) =>
        buf.write_string(text)
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
