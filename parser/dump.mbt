///|
fn dump_quoted(text : String) -> String {
  let buf = StringBuilder::new()
  buf.write_char('"')
  for ch in text {
    match ch {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(ch)
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
fn join(parts : Array[String], sep : String) -> String {
  let buf = StringBuilder::new()
  let mut first = true
  for part in parts {
    if !first {
      buf.write_string(sep)
    }
    first = false
    buf.write_string(part)
  }
  buf.to_string()
}

///|
fn dump_annotation(annotation : Annotation) -> String {
  match annotation {
    Disable(code) => "disable(\{dump_quoted(code)})"
    Enable(code) => "enable(\{dump_quoted(code)})"
    Shell(shell) => "shell(\{dump_quoted(shell)})"
    Source(path) => "source(\{dump_quoted(path)})"
    SourcePath(path) => "source_path(\{dump_quoted(path)})"
    ExternalSources(flag) => "external_sources(\{flag})"
    ExtendedAnalysis(flag) => "extended_analysis(\{flag})"
  }
}

///|
fn dump_terminator(terminator : Terminator?) -> String {
  match terminator {
    None => ""
    Some(Sequential) => ";"
    Some(Background) => "&"
  }
}

///|
fn dump_and_or_operator(op : AndOrOperator) -> String {
  match op {
    AndIf => " && "
    OrIf => " || "
  }
}

///|
fn dump_pipe_operator(op : PipeOperator) -> String {
  match op {
    Pipe => " | "
    PipeAndStderr => " |& "
  }
}

///|
fn dump_redirection_operator(op : RedirectionOperator) -> String {
  match op {
    Read => "<"
    Write => ">"
    Append => ">>"
    ReadWrite => "<>"
    Clobber => ">|"
    HereDoc => "<<"
    HereDocStrip => "<<-"
    HereString => "<<<"
    DupInput => "<&"
    DupOutput => ">&"
  }
}

///|
fn dump_word_part(part : WordPart) -> String {
  match part {
    Literal(text) => "lit(\{dump_quoted(text)})"
    SingleQuoted(text) => "sq(\{dump_quoted(text)})"
    DoubleQuoted(parts) => {
      let dumped = join(parts.map(dump_word_part), ", ")
      "dq([\{dumped}])"
    }
    DollarDoubleQuoted(parts) => {
      let dumped = join(parts.map(dump_word_part), ", ")
      "ddq([\{dumped}])"
    }
    DollarSingleQuoted(text) => "dsq(\{dump_quoted(text)})"
    Parameter(name) => "param(\{dump_quoted(name)})"
    SpecialParameter(name) => "special(\{dump_quoted(name)})"
    BracedParameter(expansion) => dump_parameter_expansion(expansion)
    BraceCommandSubstitution(piped, script) =>
      "bracecmd(piped=\{piped}, \{dump_script(script)})"
    CommandSubstitution(script) => "cmdsub(\{dump_script(script)})"
    BackQuoted(script) => "backtick(\{dump_script(script)})"
    ArithmeticExpansion(expr) => "arith(\{dump_arithmetic_expr(expr)})"
    DollarBracket(expr) => "dollar_bracket(\{dump_arithmetic_expr(expr)})"
    ExtGlob(pattern) => dump_extglob_pattern(pattern)
    ProcessSubstitution(kind, script) =>
      "procsub(\{dump_quoted(kind)}, \{dump_script(script)})"
    BraceExpansion(expansion) => dump_brace_expansion(expansion)
    Glob(raw) => "glob(\{dump_quoted(raw)})"
  }
}

///|
fn dump_arithmetic_token(token : ArithmeticToken) -> String {
  match token {
    Literal(text) => "lit(\{dump_quoted(text)})"
    Operator(op) => "op(\{dump_quoted(op)})"
    Variable(name, indexes) => {
      let suffix = if indexes.length() == 0 {
        ""
      } else {
        let dumped = join(indexes.map(dump_array_index), ", ")
        ", idx=[\{dumped}]"
      }
      "var(name=\{dump_quoted(name)}\{suffix})"
    }
    Expansion(word) => "exp(\{dump_word(word)})"
    Group(expr) => "group(\{dump_arithmetic_expr(expr)})"
  }
}

///|
fn dump_arithmetic_expr(expr : ArithmeticExpr) -> String {
  let dumped = join(expr.tokens.map(dump_arithmetic_token), ", ")
  "expr(raw=\{dump_quoted(expr.raw)}, tokens=[\{dumped}])"
}

///|
fn dump_extglob_pattern(pattern : ExtGlobPattern) -> String {
  let dumped = join(pattern.alternatives.map(dump_word), ", ")
  "extglob(raw=\{dump_quoted(pattern.raw)}, op=\{dump_quoted(pattern.operator)}, alts=[\{dumped}])"
}

///|
fn dump_brace_expansion(expansion : BraceExpansion) -> String {
  let dumped = join(expansion.elements.map(dump_word), ", ")
  "braceexp(raw=\{dump_quoted(expansion.raw)}, elems=[\{dumped}])"
}

///|
fn dump_parameter_replace_mode(mode : ParameterReplaceMode) -> String {
  match mode {
    First => "first"
    All => "all"
    Prefix => "prefix"
    Suffix => "suffix"
  }
}

///|
fn dump_parameter_names_mode(mode : ParameterNamesMode) -> String {
  match mode {
    Star => "star"
    At => "at"
  }
}

///|
fn dump_parameter_case_mode(mode : ParameterCaseMode) -> String {
  match mode {
    UpperFirst => "upper_first"
    UpperAll => "upper_all"
    LowerFirst => "lower_first"
    LowerAll => "lower_all"
    ToggleFirst => "toggle_first"
    ToggleAll => "toggle_all"
  }
}

///|
fn dump_parameter_operator(operator : ParameterOperator) -> String {
  match operator {
    Slice(offset, length) => {
      let suffix = if length is Some(length) {
        ", len=\{dump_quoted(length)}"
      } else {
        ""
      }
      "slice(offset=\{dump_quoted(offset)}\{suffix})"
    }
    DefaultValue(value) => "default(\{dump_quoted(value)})"
    AssignDefault(value) => "assign_default(\{dump_quoted(value)})"
    ErrorValue(value) => "error_value(\{dump_quoted(value)})"
    AlternateValue(value) => "alternate(\{dump_quoted(value)})"
    Names(mode) => "names(\{dump_parameter_names_mode(mode)})"
    RemoveShortestPrefix(value) => "trim_prefix(\{dump_quoted(value)})"
    RemoveLongestPrefix(value) => "trim_prefix_long(\{dump_quoted(value)})"
    RemoveShortestSuffix(value) => "trim_suffix(\{dump_quoted(value)})"
    RemoveLongestSuffix(value) => "trim_suffix_long(\{dump_quoted(value)})"
    Replace(mode, pattern, replacement) => {
      let replacement = if replacement is Some(value) {
        ", replace=\{dump_quoted(value)}"
      } else {
        ""
      }
      "replace(mode=\{dump_parameter_replace_mode(mode)}, pattern=\{dump_quoted(pattern)}\{replacement})"
    }
    Transform(kind) => "transform(\{dump_quoted(kind)})"
    CaseModify(mode, pattern) => {
      let pattern = if pattern is Some(value) {
        ", pattern=\{dump_quoted(value)}"
      } else {
        ""
      }
      "case(mode=\{dump_parameter_case_mode(mode)}\{pattern})"
    }
    Raw(raw) => "rawop(\{dump_quoted(raw)})"
  }
}

///|
fn dump_parameter_expansion(expansion : ParameterExpansion) -> String {
  let fields : Array[String] = ["raw=\{dump_quoted(expansion.raw)}"]
  if expansion.length_prefix {
    fields.push("length=true")
  }
  if expansion.indirect {
    fields.push("indirect=true")
  }
  if expansion.name is Some(name) {
    fields.push("name=\{dump_quoted(name)}")
  }
  if expansion.index is Some(index) {
    fields.push("index=\{dump_array_index(index)}")
  }
  if expansion.operator is Some(operator) {
    fields.push("op=\{dump_parameter_operator(operator)}")
  }
  let dumped = join(fields, ", ")
  "braced(\{dumped})"
}

///|
fn dump_word(word : Word) -> String {
  let dumped = join(word.parts.map(dump_word_part), ", ")
  "word([\{dumped}])"
}

///|
fn dump_assignment_value(value : AssignmentValue) -> String {
  match value {
    Empty => "empty"
    Word(word) => dump_word(word)
    ArrayLiteral(elements) => {
      let dumped = join(elements.map(dump_array_element), ", ")
      "array([\{dumped}])"
    }
  }
}

///|
fn dump_array_element(element : ArrayElement) -> String {
  let indexes = if element.indexes.length() == 0 {
    ""
  } else {
    let dumped = join(element.indexes.map(dump_array_index), ", ")
    "[\{dumped}]"
  }
  let op = if element.append { "+=" } else { "=" }
  let prefix = if element.indexes.length() == 0 && !element.append {
    ""
  } else {
    "\{indexes}\{op}"
  }
  "elem(\{prefix}\{dump_assignment_value(element.value)})"
}

///|
fn dump_assignment(assignment : Assignment) -> String {
  let op = if assignment.append { "+=" } else { "=" }
  let suffix = if assignment.indexes.length() == 0 {
    ""
  } else {
    let indexes = join(assignment.indexes.map(dump_array_index), ", ")
    "[\{indexes}]"
  }
  "assign(\{assignment.name}\{suffix}\{op}\{dump_assignment_value(assignment.value)})"
}

///|
fn dump_array_index(index : ArrayIndex) -> String {
  let dumped = join(index.parts.map(dump_word_part), ", ")
  let arithmetic = if index.arithmetic is Some(expr) {
    ", arith=\{dump_arithmetic_expr(expr)}"
  } else {
    ""
  }
  "idx(raw=\{dump_quoted(index.raw)}, parts=[\{dumped}]\{arithmetic})"
}

///|
fn dump_redirection_source(source : RedirectionSource?) -> String {
  match source {
    None => ""
    Some(Fd(fd)) => "\{fd}"
    Some(Named(name)) => "{\{name}}"
    Some(All) => "&"
  }
}

///|
fn dump_redirection_target(target : RedirectionTarget) -> String {
  match target {
    Word(word) => dump_word(word)
    HereDoc(doc) => {
      let parts = if doc.parts is Some(parts) {
        let dumped = join(parts.map(dump_word_part), ", ")
        ", parts=[\{dumped}]"
      } else {
        ""
      }
      "heredoc(delim=\{dump_quoted(doc.delimiter)}, quoted=\{doc.quoted}, strip=\{doc.strip_tabs}, body=\{dump_quoted(doc.body)}\{parts})"
    }
  }
}

///|
fn dump_redirection(redirection : Redirection) -> String {
  let source = dump_redirection_source(redirection.source)
  "redir(\{source}\{dump_redirection_operator(redirection.op)} \{dump_redirection_target(redirection.target)})"
}

///|
fn dump_simple(simple : SimpleCommand) -> String {
  let assignments = join(simple.assignments.map(dump_assignment), ", ")
  let words = join(simple.words.map(dump_word), ", ")
  "simple(assign=[\{assignments}], words=[\{words}])"
}

///|
fn dump_if_arm(arm : IfArm) -> String {
  "(\{dump_script(arm.condition)} => \{dump_script(arm.body)})"
}

///|
fn dump_command_kind(kind : CommandKind) -> String {
  match kind {
    Simple(simple) => dump_simple(simple)
    Source(source) => {
      let assignments = join(source.assignments.map(dump_assignment), ", ")
      let options = join(source.options.map(dump_word), ", ")
      let args = join(source.args.map(dump_word), ", ")
      let resolved_path = if source.resolved_path is Some(path) {
        ", resolved=\{dump_quoted(path)}"
      } else {
        ""
      }
      let included = if source.included is Some(script) {
        ", include=\{dump_script(script)}"
      } else {
        ""
      }
      "source(assign=[\{assignments}], keyword=\{dump_quoted(source.keyword)}, opts=[\{options}], path=\{dump_word(source.path)}, args=[\{args}]\{resolved_path}\{included})"
    }
    Time(clause) => {
      let flags = join(clause.flags.map(dump_word), ", ")
      "time(flags=[\{flags}], body=\{dump_pipeline(clause.body)})"
    }
    Subshell(script) => "subshell(\{dump_script(script)})"
    BraceGroup(script) => "brace(\{dump_script(script)})"
    If(clause) => {
      let arms = join(clause.arms.map(dump_if_arm), ", ")
      let else_part = if clause.else_body is Some(script) {
        ", else=\{dump_script(script)}"
      } else {
        ""
      }
      "if([\{arms}]\{else_part})"
    }
    While(loop_) =>
      "while(\{dump_script(loop_.condition)} => \{dump_script(loop_.body)})"
    Until(loop_) =>
      "until(\{dump_script(loop_.condition)} => \{dump_script(loop_.body)})"
    ForIn(clause) => {
      let values = join(clause.values.map(dump_word), ", ")
      "for(name=\{clause.name}, values=[\{values}], body=\{dump_script(clause.body)})"
    }
    ForArithmetic(clause) =>
      "for_arith(init=\{dump_arithmetic_expr(clause.init)}, cond=\{dump_arithmetic_expr(clause.condition)}, step=\{dump_arithmetic_expr(clause.step)}, body=\{dump_script(clause.body)})"
    Select(clause) => {
      let values = join(clause.values.map(dump_word), ", ")
      "select(name=\{clause.name}, values=[\{values}], body=\{dump_script(clause.body)})"
    }
    Case(clause) => {
      let items = join(clause.items.map(dump_case_item), ", ")
      "case(word=\{dump_word(clause.word)}, items=[\{items}])"
    }
    Condition(condition) =>
      "condition(\{dump_condition_kind(condition.kind)}, raw=\{dump_quoted(condition.raw)}, expr=\{dump_condition_expr(condition.expr)})"
    Arithmetic(arith) =>
      "arith_cmd(raw=\{dump_quoted(arith.raw)}, expr=\{dump_arithmetic_expr(arith.expr)})"
    Function(function_) =>
      "function(name=\{function_.name}, keyword=\{function_.uses_keyword}, parens=\{function_.has_parentheses}, body=\{dump_command(function_.body)})"
    CoProc(clause) => {
      let name = if clause.name is Some(word) {
        dump_word(word)
      } else {
        "None"
      }
      "coproc(name=\{name}, body=\{dump_command(clause.body)})"
    }
    BatsTest(clause) =>
      "bats(name=\{dump_quoted(clause.name)}, body=\{dump_script(clause.body)})"
  }
}

///|
fn dump_case_separator(separator : CaseSeparator) -> String {
  match separator {
    Break => ";;"
    FallThrough => ";&"
    Continue => ";;&"
  }
}

///|
fn dump_case_item(item : CaseItem) -> String {
  let patterns = join(item.patterns.map(dump_word), " | ")
  "case_item([\{patterns}] => \{dump_script(item.body)} \{dump_case_separator(item.separator)})"
}

///|
fn dump_condition_kind(kind : ConditionKind) -> String {
  match kind {
    SingleBracket => "["
    DoubleBracket => "[["
  }
}

///|
fn dump_condition_expr(expr : ConditionExpr) -> String {
  match expr {
    Empty => "empty"
    Word(word) => dump_word(word)
    Unary(op, _, word) => "unary(\{dump_quoted(op)}, \{dump_word(word)})"
    Binary(op, _, left, right) =>
      "binary(\{dump_quoted(op)}, \{dump_word(left)}, \{dump_word(right)})"
    Group(inner) => "group(\{dump_condition_expr(inner)})"
    Not(inner) => "not(\{dump_condition_expr(inner)})"
    And(op, left, right) =>
      "and(\{dump_quoted(op.text)}, \{dump_condition_expr(left)}, \{dump_condition_expr(right)})"
    Or(op, left, right) =>
      "or(\{dump_quoted(op.text)}, \{dump_condition_expr(left)}, \{dump_condition_expr(right)})"
  }
}

///|
fn dump_command(command : Command) -> String {
  let base = dump_command_kind(command.kind)
  if command.redirects.length() == 0 {
    base
  } else {
    let redirects = join(command.redirects.map(dump_redirection), ", ")
    "redirect(\{base}, [\{redirects}])"
  }
}

///|
fn dump_pipeline(pipeline : Pipeline) -> String {
  let parts : Array[String] = []
  let mut i = 0
  while i < pipeline.segments.length() {
    if i > 0 {
      parts.push(dump_pipe_operator(pipeline.operators[i - 1]))
    }
    let segment = pipeline.segments[i]
    let mut prefix = ""
    let mut bangs = 0
    while bangs < segment.bangs {
      prefix += "! "
      bangs += 1
    }
    parts.push(prefix + dump_command(segment.command))
    i += 1
  }
  join(parts, "")
}

///|
fn dump_and_or(and_or : AndOrList) -> String {
  let parts : Array[String] = [dump_pipeline(and_or.head)]
  for pair in and_or.tail {
    parts.push(dump_and_or_operator(pair.0))
    parts.push(dump_pipeline(pair.1))
  }
  join(parts, "")
}

///|
fn dump_list_item(item : ListItem) -> String {
  let prefix = if item.annotations.length() == 0 {
    ""
  } else {
    let annotations = join(item.annotations.map(dump_annotation), ", ")
    "ann([\{annotations}]) "
  }
  "\{prefix}\{dump_and_or(item.and_or)}\{dump_terminator(item.terminator)}"
}

///|
fn dump_script(script : Script) -> String {
  let prefix : Array[String] = []
  if script.has_bom {
    prefix.push("bom")
  }
  if script.shebang is Some(shebang) {
    prefix.push("shebang=\{dump_quoted(shebang)}")
  }
  if script.annotations.length() > 0 {
    let annotations = join(script.annotations.map(dump_annotation), ", ")
    prefix.push("ann=[\{annotations}]")
  }
  let meta = if prefix.length() == 0 {
    ""
  } else {
    let joined = join(prefix, ", ")
    "\{joined} "
  }
  let dumped = join(script.items.map(dump_list_item), " ")
  "script[\{meta}\{dumped}]"
}

///|
/// Dumps a parsed script into a compact debug-oriented textual representation.
pub fn Script::dump(self : Script) -> String {
  dump_script(self)
}
