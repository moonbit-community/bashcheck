///|
priv struct Cursor {
  offset : Int
  line : Int
  column : Int
}

///|
priv enum ConditionToken {
  Word(Word)
  LParen
  RParen
  And
  Or
}

///|
priv enum ShebangLineKind {
  Correct
  LeadingSpaces
  SpacesBetweenHashBang
  Swapped
  MissingHash
  MissingBang
}

///|
priv enum ShebangShellStatus {
  Supported
  Unsupported
  Unknown
}

///|
priv struct ConditionCursor {
  tokens : Array[ConditionToken]
  kind : ConditionKind
  mut index : Int
}

///|
priv struct ArithmeticCursor {
  tokens : Array[ArithmeticToken]
  mut index : Int
}

///|
priv struct PendingHereDoc {
  redirections : Array[Redirection]
  index : Int
  delimiter : String
  quoted : Bool
  strip_tabs : Bool
  annotations : Array[Annotation]
  owner_context_pos : Position?
  owner_context_message : String?
  redirection_pos : Position
  delimiter_pos : Position
}

///|
priv struct Parser {
  source : StringView
  options : ParseOptions
  source_stack : Array[String]
  mut offset : Int
  mut line : Int
  mut column : Int
  mut pending_heredocs : Array[PendingHereDoc]
  mut current_annotations : Array[Annotation]
  mut file_annotations : Array[Annotation]
  mut simple_command_context : Position?
  diagnostics : Array[Diagnostic]
}

///|
fn Parser::new(
  source : StringView,
  options : ParseOptions,
  source_stack : Array[String],
) -> Parser {
  {
    source,
    options,
    source_stack,
    offset: 0,
    line: 1,
    column: 1,
    pending_heredocs: [],
    current_annotations: [],
    file_annotations: [],
    simple_command_context: None,
    diagnostics: [],
  }
}

///|
fn Parser::position(self : Parser) -> Position {
  { offset: self.offset, line: self.line, column: self.column }
}

///|
fn make_span(start : Position, end_ : Position) -> Span {
  { start, end: end_ }
}

///|
fn span_at(pos : Position) -> Span {
  { start: pos, end: pos }
}

///|
fn translate_position(base : Position, relative : Position) -> Position {
  {
    offset: base.offset + relative.offset,
    line: base.line + relative.line - 1,
    column: if relative.line == 1 {
      base.column + relative.column - 1
    } else {
      relative.column
    },
  }
}

///|
fn translate_span(base : Position, span : Span) -> Span {
  {
    start: translate_position(base, span.start),
    end: translate_position(base, span.end),
  }
}

///|
fn translate_parse_error(base : Position, err : ParseError) -> ParseError {
  match err {
    ParseError::UnexpectedEnd(pos~, context~) =>
      ParseError::UnexpectedEnd(pos=translate_position(base, pos), context~)
    ParseError::UnexpectedToken(pos~, found~, expected~) =>
      ParseError::UnexpectedToken(
        pos=translate_position(base, pos),
        found~,
        expected~,
      )
    ParseError::Message(pos~, message~) =>
      ParseError::Message(pos=translate_position(base, pos), message~)
  }
}

///|
fn translate_script(base : Position, script : Script) -> Script {
  let items : Array[ListItem] = []
  for item in script.items {
    items.push(translate_list_item(base, item))
  }
  { ..script, span: translate_span(base, script.span), items }
}

///|
fn translate_list_item(base : Position, item : ListItem) -> ListItem {
  {
    ..item,
    span: translate_span(base, item.span),
    and_or: translate_and_or_list(base, item.and_or),
  }
}

///|
fn translate_and_or_list(base : Position, list : AndOrList) -> AndOrList {
  let tail : Array[(AndOrOperator, Pipeline)] = []
  for pair in list.tail {
    tail.push((pair.0, translate_pipeline(base, pair.1)))
  }
  {
    span: translate_span(base, list.span),
    head: translate_pipeline(base, list.head),
    tail,
  }
}

///|
fn translate_pipeline(base : Position, pipeline : Pipeline) -> Pipeline {
  let segments : Array[PipelineSegment] = []
  for segment in pipeline.segments {
    segments.push(translate_pipeline_segment(base, segment))
  }
  { ..pipeline, span: translate_span(base, pipeline.span), segments }
}

///|
fn translate_pipeline_segment(
  base : Position,
  segment : PipelineSegment,
) -> PipelineSegment {
  {
    ..segment,
    span: translate_span(base, segment.span),
    command: translate_command(base, segment.command),
  }
}

///|
fn translate_command(base : Position, command : Command) -> Command {
  {
    span: translate_span(base, command.span),
    kind: translate_command_kind(base, command.kind),
    redirects: translate_redirections(base, command.redirects),
  }
}

///|
fn translate_command_kind(base : Position, kind : CommandKind) -> CommandKind {
  match kind {
    CommandKind::Simple(simple) =>
      CommandKind::Simple(translate_simple_command(base, simple))
    CommandKind::Source(source) =>
      CommandKind::Source(translate_source_command(base, source))
    CommandKind::Time(clause) =>
      CommandKind::Time(translate_time_clause(base, clause))
    CommandKind::Subshell(script) =>
      CommandKind::Subshell(translate_script(base, script))
    CommandKind::BraceGroup(script) =>
      CommandKind::BraceGroup(translate_script(base, script))
    CommandKind::If(clause) =>
      CommandKind::If(translate_if_clause(base, clause))
    CommandKind::While(clause) =>
      CommandKind::While(translate_loop_clause(base, clause))
    CommandKind::Until(clause) =>
      CommandKind::Until(translate_loop_clause(base, clause))
    CommandKind::ForIn(clause) =>
      CommandKind::ForIn(translate_for_clause(base, clause))
    CommandKind::ForArithmetic(clause) =>
      CommandKind::ForArithmetic(translate_arithmetic_for_clause(base, clause))
    CommandKind::Select(clause) =>
      CommandKind::Select(translate_select_clause(base, clause))
    CommandKind::Case(clause) =>
      CommandKind::Case(translate_case_clause(base, clause))
    CommandKind::Condition(condition) =>
      CommandKind::Condition(translate_condition_command(base, condition))
    CommandKind::Arithmetic(command) =>
      CommandKind::Arithmetic(translate_arithmetic_command(base, command))
    CommandKind::Function(function_) =>
      CommandKind::Function(translate_function_def(base, function_))
    CommandKind::CoProc(clause) =>
      CommandKind::CoProc(translate_co_proc_clause(base, clause))
    CommandKind::BatsTest(clause) =>
      CommandKind::BatsTest(translate_bats_test_clause(base, clause))
  }
}

///|
fn translate_simple_command(
  base : Position,
  simple : SimpleCommand,
) -> SimpleCommand {
  {
    assignments: translate_assignments(base, simple.assignments),
    words: translate_words(base, simple.words),
  }
}

///|
fn translate_source_command(
  base : Position,
  source : SourceCommand,
) -> SourceCommand {
  {
    ..source,
    assignments: translate_assignments(base, source.assignments),
    options: translate_words(base, source.options),
    path: translate_word(base, source.path),
    args: translate_words(base, source.args),
    included: match source.included {
      Some(script) => Some(translate_script(base, script))
      None => None
    },
  }
}

///|
fn translate_time_clause(base : Position, clause : TimeClause) -> TimeClause {
  {
    flags: translate_words(base, clause.flags),
    body: translate_pipeline(base, clause.body),
  }
}

///|
fn translate_assignments(
  base : Position,
  assignments : Array[Assignment],
) -> Array[Assignment] {
  let translated : Array[Assignment] = []
  for assignment in assignments {
    translated.push(translate_assignment(base, assignment))
  }
  translated
}

///|
fn translate_assignment(base : Position, assignment : Assignment) -> Assignment {
  {
    ..assignment,
    span: translate_span(base, assignment.span),
    indexes: translate_array_indices(base, assignment.indexes),
    value: translate_assignment_value(base, assignment.value),
  }
}

///|
fn translate_assignment_value(
  base : Position,
  value : AssignmentValue,
) -> AssignmentValue {
  match value {
    AssignmentValue::Empty => AssignmentValue::Empty
    AssignmentValue::Word(word) =>
      AssignmentValue::Word(translate_word(base, word))
    AssignmentValue::ArrayLiteral(elements) =>
      AssignmentValue::ArrayLiteral(translate_array_elements(base, elements))
  }
}

///|
fn translate_array_elements(
  base : Position,
  elements : Array[ArrayElement],
) -> Array[ArrayElement] {
  let translated : Array[ArrayElement] = []
  for element in elements {
    translated.push(translate_array_element(base, element))
  }
  translated
}

///|
fn translate_array_element(
  base : Position,
  element : ArrayElement,
) -> ArrayElement {
  {
    ..element,
    indexes: translate_array_indices(base, element.indexes),
    value: translate_assignment_value(base, element.value),
  }
}

///|
fn translate_if_clause(base : Position, clause : IfClause) -> IfClause {
  let arms : Array[IfArm] = []
  for arm in clause.arms {
    arms.push(translate_if_arm(base, arm))
  }
  {
    arms,
    else_body: match clause.else_body {
      Some(script) => Some(translate_script(base, script))
      None => None
    },
  }
}

///|
fn translate_if_arm(base : Position, arm : IfArm) -> IfArm {
  {
    condition: translate_script(base, arm.condition),
    body: translate_script(base, arm.body),
  }
}

///|
fn translate_loop_clause(base : Position, clause : LoopClause) -> LoopClause {
  {
    condition: translate_script(base, clause.condition),
    body: translate_script(base, clause.body),
  }
}

///|
fn translate_for_clause(base : Position, clause : ForClause) -> ForClause {
  {
    ..clause,
    values: translate_words(base, clause.values),
    body: translate_script(base, clause.body),
  }
}

///|
fn translate_arithmetic_for_clause(
  base : Position,
  clause : ArithmeticForClause,
) -> ArithmeticForClause {
  {
    init: translate_arithmetic_expr(base, clause.init),
    condition: translate_arithmetic_expr(base, clause.condition),
    step: translate_arithmetic_expr(base, clause.step),
    body: translate_script(base, clause.body),
  }
}

///|
fn translate_select_clause(
  base : Position,
  clause : SelectClause,
) -> SelectClause {
  {
    ..clause,
    values: translate_words(base, clause.values),
    body: translate_script(base, clause.body),
  }
}

///|
fn translate_case_clause(base : Position, clause : CaseClause) -> CaseClause {
  let items : Array[CaseItem] = []
  for item in clause.items {
    items.push(translate_case_item(base, item))
  }
  { word: translate_word(base, clause.word), items }
}

///|
fn translate_case_item(base : Position, item : CaseItem) -> CaseItem {
  {
    ..item,
    patterns: translate_words(base, item.patterns),
    body: translate_script(base, item.body),
  }
}

///|
fn translate_condition_command(
  base : Position,
  condition : ConditionCommand,
) -> ConditionCommand {
  { ..condition, expr: translate_condition_expr(base, condition.expr) }
}

///|
fn translate_condition_expr(
  base : Position,
  expr : ConditionExpr,
) -> ConditionExpr {
  match expr {
    ConditionExpr::Empty => ConditionExpr::Empty
    ConditionExpr::Word(word) => ConditionExpr::Word(translate_word(base, word))
    ConditionExpr::Unary(op, span, word) =>
      ConditionExpr::Unary(
        op,
        translate_span(base, span),
        translate_word(base, word),
      )
    ConditionExpr::Binary(op, span, lhs, rhs) =>
      ConditionExpr::Binary(
        op,
        translate_span(base, span),
        translate_word(base, lhs),
        translate_word(base, rhs),
      )
    ConditionExpr::Group(inner) =>
      ConditionExpr::Group(translate_condition_expr(base, inner))
    ConditionExpr::Not(inner) =>
      ConditionExpr::Not(translate_condition_expr(base, inner))
    ConditionExpr::And(lhs, rhs) =>
      ConditionExpr::And(
        translate_condition_expr(base, lhs),
        translate_condition_expr(base, rhs),
      )
    ConditionExpr::Or(lhs, rhs) =>
      ConditionExpr::Or(
        translate_condition_expr(base, lhs),
        translate_condition_expr(base, rhs),
      )
  }
}

///|
fn translate_arithmetic_command(
  base : Position,
  command : ArithmeticCommand,
) -> ArithmeticCommand {
  { ..command, expr: translate_arithmetic_expr(base, command.expr) }
}

///|
fn translate_co_proc_clause(
  base : Position,
  clause : CoProcClause,
) -> CoProcClause {
  {
    name: match clause.name {
      Some(name) => Some(translate_word(base, name))
      None => None
    },
    body: translate_command(base, clause.body),
  }
}

///|
fn translate_bats_test_clause(
  base : Position,
  clause : BatsTestClause,
) -> BatsTestClause {
  { ..clause, body: translate_script(base, clause.body) }
}

///|
fn translate_function_def(
  base : Position,
  function_ : FunctionDef,
) -> FunctionDef {
  { ..function_, body: translate_command(base, function_.body) }
}

///|
fn translate_redirections(
  base : Position,
  redirects : Array[Redirection],
) -> Array[Redirection] {
  let translated : Array[Redirection] = []
  for redirect in redirects {
    translated.push(translate_redirection(base, redirect))
  }
  translated
}

///|
fn translate_redirection(
  base : Position,
  redirect : Redirection,
) -> Redirection {
  {
    ..redirect,
    span: translate_span(base, redirect.span),
    target: translate_redirection_target(base, redirect.target),
  }
}

///|
fn translate_redirection_target(
  base : Position,
  target : RedirectionTarget,
) -> RedirectionTarget {
  match target {
    RedirectionTarget::Word(word) =>
      RedirectionTarget::Word(translate_word(base, word))
    RedirectionTarget::HereDoc(doc) =>
      RedirectionTarget::HereDoc(translate_here_doc(base, doc))
  }
}

///|
fn translate_here_doc(base : Position, doc : HereDoc) -> HereDoc {
  {
    ..doc,
    parts: match doc.parts {
      Some(parts) => Some(translate_word_parts(base, parts))
      None => None
    },
  }
}

///|
fn translate_words(base : Position, words : Array[Word]) -> Array[Word] {
  let translated : Array[Word] = []
  for word in words {
    translated.push(translate_word(base, word))
  }
  translated
}

///|
fn translate_word(base : Position, word : Word) -> Word {
  {
    ..word,
    span: translate_span(base, word.span),
    parts: translate_word_parts(base, word.parts),
  }
}

///|
fn translate_word_parts(
  base : Position,
  parts : Array[WordPart],
) -> Array[WordPart] {
  let translated : Array[WordPart] = []
  for part in parts {
    translated.push(translate_word_part(base, part))
  }
  translated
}

///|
fn translate_word_part(base : Position, part : WordPart) -> WordPart {
  match part {
    WordPart::Literal(_)
    | WordPart::SingleQuoted(_)
    | WordPart::DollarSingleQuoted(_)
    | WordPart::Parameter(_)
    | WordPart::SpecialParameter(_)
    | WordPart::Glob(_) => part
    WordPart::DoubleQuoted(parts) =>
      WordPart::DoubleQuoted(translate_word_parts(base, parts))
    WordPart::DollarDoubleQuoted(parts) =>
      WordPart::DollarDoubleQuoted(translate_word_parts(base, parts))
    WordPart::BracedParameter(expansion) =>
      WordPart::BracedParameter(translate_parameter_expansion(base, expansion))
    WordPart::BraceCommandSubstitution(piped, script) =>
      WordPart::BraceCommandSubstitution(piped, translate_script(base, script))
    WordPart::CommandSubstitution(script) =>
      WordPart::CommandSubstitution(translate_script(base, script))
    WordPart::BackQuoted(script) =>
      WordPart::BackQuoted(translate_script(base, script))
    WordPart::ArithmeticExpansion(expr) =>
      WordPart::ArithmeticExpansion(translate_arithmetic_expr(base, expr))
    WordPart::DollarBracket(expr) =>
      WordPart::DollarBracket(translate_arithmetic_expr(base, expr))
    WordPart::ExtGlob(pattern) =>
      WordPart::ExtGlob(translate_extglob_pattern(base, pattern))
    WordPart::ProcessSubstitution(kind, script) =>
      WordPart::ProcessSubstitution(kind, translate_script(base, script))
    WordPart::BraceExpansion(expansion) =>
      WordPart::BraceExpansion(translate_brace_expansion(base, expansion))
  }
}

///|
fn translate_parameter_expansion(
  base : Position,
  expansion : ParameterExpansion,
) -> ParameterExpansion {
  {
    ..expansion,
    index: match expansion.index {
      Some(index) => Some(translate_array_index(base, index))
      None => None
    },
  }
}

///|
fn translate_extglob_pattern(
  base : Position,
  pattern : ExtGlobPattern,
) -> ExtGlobPattern {
  { ..pattern, alternatives: translate_words(base, pattern.alternatives) }
}

///|
fn translate_brace_expansion(
  base : Position,
  expansion : BraceExpansion,
) -> BraceExpansion {
  { ..expansion, elements: translate_words(base, expansion.elements) }
}

///|
fn translate_arithmetic_expr(
  base : Position,
  expr : ArithmeticExpr,
) -> ArithmeticExpr {
  let tokens : Array[ArithmeticToken] = []
  for token in expr.tokens {
    tokens.push(translate_arithmetic_token(base, token))
  }
  { ..expr, tokens, }
}

///|
fn translate_arithmetic_token(
  base : Position,
  token : ArithmeticToken,
) -> ArithmeticToken {
  match token {
    ArithmeticToken::Literal(_) | ArithmeticToken::Operator(_) => token
    ArithmeticToken::Variable(name, indexes) =>
      ArithmeticToken::Variable(name, translate_array_indices(base, indexes))
    ArithmeticToken::Expansion(word) =>
      ArithmeticToken::Expansion(translate_word(base, word))
    ArithmeticToken::Group(inner) =>
      ArithmeticToken::Group(translate_arithmetic_expr(base, inner))
  }
}

///|
fn translate_array_indices(
  base : Position,
  indexes : Array[ArrayIndex],
) -> Array[ArrayIndex] {
  let translated : Array[ArrayIndex] = []
  for index in indexes {
    translated.push(translate_array_index(base, index))
  }
  translated
}

///|
fn translate_array_index(base : Position, index : ArrayIndex) -> ArrayIndex {
  {
    ..index,
    parts: translate_word_parts(base, index.parts),
    arithmetic: match index.arithmetic {
      Some(expr) => Some(translate_arithmetic_expr(base, expr))
      None => None
    },
  }
}

///|
fn parse_error_position(err : ParseError) -> Position {
  match err {
    ParseError::UnexpectedEnd(pos~, ..) => pos
    ParseError::UnexpectedToken(pos~, ..) => pos
    ParseError::Message(pos~, ..) => pos
  }
}

///|
fn is_backquote_char(ch : UInt16) -> Bool {
  ch == '`' || ch == '´'
}

///|
fn Parser::consume_backquote_start(self : Parser) -> Unit {
  if self.peek() == Some('´') {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      self.position(),
      "For command expansion, the tick should slant left (` vs ´). Use $(..) instead.",
      Some(1077),
    )
  }
  ignore(self.advance_one())
}

///|
fn unescape_backquoted_body(body : String, quoted : Bool) -> String {
  let content = StringBuilder::new()
  let view = body[:]
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch == '\\' && i + 1 < view.length() {
      let next = view[i + 1]
      if quoted && next == '"' {
        content.write_char('"')
        i += 2
        continue
      }
      if next == '$' || next == '`' || next == '\\' {
        content.write_char(next.unsafe_to_char())
        i += 2
        continue
      }
      if next == '\n' {
        i += 2
        continue
      }
      if next == '\r' && i + 2 < view.length() && view[i + 2] == '\n' {
        i += 3
        continue
      }
      content.write_char('\\')
      content.write_char(next.unsafe_to_char())
      i += 2
      continue
    }
    content.write_char(ch.unsafe_to_char())
    i += 1
  }
  content.to_string()
}

///|
priv struct NestedScriptParseResult {
  script : Script
  diagnostics : Array[Diagnostic]
}

///|
fn Parser::resolve_nested_script(self : Parser, script : Script) -> Script {
  resolve_script_sources(
    script,
    [],
    self.options,
    self.source_stack,
    self.diagnostics,
  )
}

///|
fn Parser::emit_diagnostic(
  self : Parser,
  severity : DiagnosticSeverity,
  pos : Position,
  message : String,
  code : Int?,
) -> Unit {
  self.diagnostics.push({ span: span_at(pos), severity, code, message })
}

///|
fn Parser::emit_simple_command_context_diagnostic(self : Parser) -> Unit {
  match self.simple_command_context {
    Some(pos) => {
      for diagnostic in self.diagnostics {
        if diagnostic.code == Some(1009) &&
          diagnostic.span.start == pos &&
          diagnostic.message ==
          "The mentioned syntax error was in this simple command." {
          return
        }
      }
      self.emit_diagnostic(
        DiagnosticSeverity::Info,
        pos,
        "The mentioned syntax error was in this simple command.",
        Some(1009),
      )
    }
    None => ()
  }
}

///|
fn Parser::consume_unicode_space(self : Parser) -> Bool {
  match self.peek() {
    Some(ch) if is_unicode_space_char(ch) => {
      let message = if ch == 0x00A0 {
        "This is a unicode non-breaking space. Delete and retype it."
      } else {
        "This is a unicode space. Delete and retype it."
      }
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        self.position(),
        message,
        Some(1018),
      )
      ignore(self.advance_one())
      true
    }
    _ => false
  }
}

///|
fn Parser::maybe_emit_unicode_quote(self : Parser, ch : UInt16) -> Unit {
  if is_unicode_quote_char(ch) {
    self.emit_diagnostic(
      DiagnosticSeverity::Warning,
      self.position(),
      "This is a unicode quote. Delete and retype it (or quote to make literal).",
      Some(1110),
    )
  }
}

///|
fn Parser::mark(self : Parser) -> Cursor {
  { offset: self.offset, line: self.line, column: self.column }
}

///|
fn Parser::reset(self : Parser, cursor : Cursor) -> Unit {
  self.offset = cursor.offset
  self.line = cursor.line
  self.column = cursor.column
}

///|
fn Parser::eof(self : Parser) -> Bool {
  self.offset >= self.source.length()
}

///|
fn Parser::peek(self : Parser) -> UInt16? {
  if self.eof() {
    None
  } else {
    Some(self.source[self.offset])
  }
}

///|
fn Parser::peek_n(self : Parser, n : Int) -> UInt16? {
  let idx = self.offset + n
  if idx < 0 || idx >= self.source.length() {
    None
  } else {
    Some(self.source[idx])
  }
}

///|
fn Parser::starts_with(self : Parser, prefix : String) -> Bool {
  if self.offset > self.source.length() {
    return false
  }
  self.source.view(start_offset=self.offset).has_prefix(prefix)
}

///|
fn Parser::advance_one(self : Parser) -> UInt16? {
  match self.peek() {
    None => None
    Some(ch) => {
      self.offset += 1
      if ch == '\n' {
        self.line += 1
        self.column = 1
      } else {
        self.column += 1
      }
      Some(ch)
    }
  }
}

///|
fn Parser::advance_n(self : Parser, n : Int) -> Unit {
  for _ in 0..<n {
    ignore(self.advance_one())
  }
}

///|
fn Parser::consume_newline(self : Parser) -> Bool {
  match self.peek() {
    Some('\r') => {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        self.position(),
        "Literal carriage return. Run script through tr -d '\\r' .",
        Some(1017),
      )
      self.offset += 1
      if self.peek() == Some('\n') {
        self.offset += 1
      }
      self.line += 1
      self.column = 1
      true
    }
    Some('\n') => {
      ignore(self.advance_one())
      true
    }
    _ => false
  }
}

///|
fn Parser::current_slice(self : Parser, start_offset : Int) -> String {
  self.source.view(start_offset~, end_offset=self.offset).to_string()
}

///|
fn Parser::peek_line(self : Parser) -> String {
  let mut end_ = self.offset
  while end_ < self.source.length() {
    let ch = self.source[end_]
    if ch == '\n' || ch == '\r' {
      break
    }
    end_ += 1
  }
  self.source.view(start_offset=self.offset, end_offset=end_).to_string()
}

///|
fn is_space_char(ch : UInt16) -> Bool {
  ch == ' ' || ch == '\t' || is_unicode_space_char(ch)
}

///|
fn is_unicode_space_char(ch : UInt16) -> Bool {
  ch == 0x00A0 ||
  ch == 0x2002 ||
  ch == 0x2003 ||
  ch == 0x2004 ||
  ch == 0x2005 ||
  ch == 0x2006 ||
  ch == 0x2007 ||
  ch == 0x2008 ||
  ch == 0x2009 ||
  ch == 0x200B ||
  ch == 0x202F
}

///|
fn is_unicode_quote_char(ch : UInt16) -> Bool {
  ch == 0x2018 ||
  ch == 0x2019 ||
  ch == 0x201C ||
  ch == 0x201D ||
  ch == 0x2033 ||
  ch == 0x2036
}

///|
fn is_unicode_dash_char(ch : UInt16) -> Bool {
  ch == 0x058A ||
  ch == 0x05BE ||
  ch == 0x2010 ||
  ch == 0x2011 ||
  ch == 0x2012 ||
  ch == 0x2013 ||
  ch == 0x2014 ||
  ch == 0x2015 ||
  ch == 0xFE63 ||
  ch == 0xFF0D
}

///|
fn is_unicode_single_quote_char(ch : UInt16) -> Bool {
  ch == 0x2018 || ch == 0x2019
}

///|
fn is_unicode_double_quote_char(ch : UInt16) -> Bool {
  ch == 0x201C || ch == 0x201D || ch == 0x2033 || ch == 0x2036
}

///|
fn is_digit(ch : UInt16) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_ascii_alpha(ch : UInt16) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_name_start(ch : UInt16) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_'
}

///|
fn is_name_part(ch : UInt16) -> Bool {
  is_name_start(ch) || is_digit(ch)
}

///|
fn is_function_name_start_char(ch : UInt16, uses_keyword : Bool) -> Bool {
  is_name_part(ch) ||
  ch == ':' ||
  ch == '+' ||
  ch == '?' ||
  ch == '-' ||
  ch == '.' ||
  ch == '/' ||
  ch == '^' ||
  ch == '@' ||
  ch == ',' ||
  (
    uses_keyword &&
    (ch == '[' || ch == ']' || ch == '*' || ch == '=' || ch == '!')
  )
}

///|
fn is_function_name_part_char(ch : UInt16, uses_keyword : Bool) -> Bool {
  is_function_name_start_char(ch, uses_keyword) || ch == '#'
}

///|
fn is_special_parameter_char(ch : UInt16) -> Bool {
  ch == '@' ||
  ch == '*' ||
  ch == '#' ||
  ch == '?' ||
  ch == '$' ||
  ch == '!' ||
  ch == '-' ||
  ch == '_'
}

///|
fn lower_ascii_alpha_prefix(text : String) -> String {
  let view = text[:]
  let buf = StringBuilder::new()
  let mut i = 0
  while i < view.length() && is_ascii_alpha(view[i]) {
    let ch = view[i]
    if ch >= 'A' && ch <= 'Z' {
      buf.write_char((ch + ('a' - 'A')).unsafe_to_char())
    } else {
      buf.write_char(ch.unsafe_to_char())
    }
    i += 1
  }
  buf.to_string()
}

///|
fn lower_ascii_string(text : String) -> String {
  let view = text[:]
  let buf = StringBuilder::new()
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch >= 'A' && ch <= 'Z' {
      buf.write_char((ch + ('a' - 'A')).unsafe_to_char())
    } else {
      buf.write_char(ch.unsafe_to_char())
    }
    i += 1
  }
  buf.to_string()
}

///|
fn first_line_containing(text : String, needle : String) -> String? {
  let view = text[:]
  let mut start = 0
  let mut i = 0
  while i <= view.length() {
    if i == view.length() || view[i] == '\n' {
      let line = text.view(start_offset=start, end_offset=i).to_string()
      if line.contains(needle) {
        return Some(line)
      }
      start = i + 1
    }
    i += 1
  }
  None
}

///|
fn is_keyword_boundary(ch : UInt16?) -> Bool {
  match ch {
    None => true
    Some(c) =>
      is_space_char(c) ||
      c == '\n' ||
      c == '\r' ||
      c == ';' ||
      c == '&' ||
      c == '|' ||
      c == '<' ||
      c == '>' ||
      c == '(' ||
      c == ')'
  }
}

///|
fn is_word_boundary(ch : UInt16?) -> Bool {
  match ch {
    None => true
    Some(c) =>
      is_space_char(c) ||
      c == '\n' ||
      c == '\r' ||
      c == ';' ||
      c == '&' ||
      c == '|' ||
      c == '<' ||
      c == '>' ||
      c == '(' ||
      c == ')'
  }
}

///|
fn is_suspect_char_after_quotes(ch : UInt16) -> Bool {
  is_name_start(ch) ||
  is_digit(ch) ||
  is_special_parameter_char(ch) ||
  ch == '%'
}

///|
fn is_condition_regex_boundary(ch : UInt16?) -> Bool {
  match ch {
    None => true
    Some(c) => c == ' ' || c == '\t' || c == '\n' || c == '\r'
  }
}

///|
fn condition_internal_message(tag : String) -> String {
  "__condition_internal__:\{tag}"
}

///|
fn is_condition_internal_message(message : String, tag : String) -> Bool {
  message == condition_internal_message(tag)
}

///|
fn digits_to_int(digits : String) -> Int {
  let mut acc = 0
  for ch in digits {
    acc = acc * 10 + (ch.to_int() - '0'.to_int())
  }
  acc
}

///|
fn char_display(ch : UInt16) -> String {
  match ch {
    '\n' => "\\n"
    '\r' => "\\r"
    '\t' => "\\t"
    _ => {
      let buf = StringBuilder::new()
      buf.write_char(ch.unsafe_to_char())
      buf.to_string()
    }
  }
}

///|
fn Parser::found_description(self : Parser) -> String {
  match self.peek() {
    None => "end of input"
    Some(ch) => "'\{char_display(ch)}'"
  }
}

///|
fn Parser::unexpected_end(self : Parser, context : String) -> ParseError {
  ParseError::UnexpectedEnd(pos=self.position(), context~)
}

///|
fn Parser::unexpected(self : Parser, expected : String) -> ParseError {
  ParseError::UnexpectedToken(
    pos=self.position(),
    found=self.found_description(),
    expected~,
  )
}

///|
fn Parser::skip_comment(self : Parser) -> Unit {
  if self.peek() != Some('#') {
    return
  }
  while self.peek() is Some(ch) {
    if ch == '\n' || ch == '\r' {
      break
    }
    ignore(self.advance_one())
  }
}

///|
fn Parser::maybe_emit_comment_line_continuation_diagnostic(
  self : Parser,
) -> Unit {
  let mark = self.mark()
  while self.peek() == Some(' ') || self.peek() == Some('\t') {
    ignore(self.advance_one())
  }
  if self.peek() == Some('#') {
    let pos = self.position()
    if self.peek_line().has_suffix("\\") {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        pos,
        "This backslash is part of a comment and does not continue the line.",
        Some(1143),
      )
    }
  }
  self.reset(mark)
}

///|
fn Parser::skip_inline_space(self : Parser) -> Unit {
  while true {
    match self.peek() {
      Some(ch) if is_unicode_space_char(ch) => {
        ignore(self.consume_unicode_space())
        continue
      }
      Some(ch) if is_space_char(ch) => {
        ignore(self.advance_one())
        continue
      }
      Some('\\') if self.peek_n(1) == Some('\n') => {
        self.advance_n(2)
        self.maybe_emit_comment_line_continuation_diagnostic()
        continue
      }
      Some('\\') if self.peek_n(1) == Some('\r') && self.peek_n(2) == Some('\n') => {
        self.advance_n(3)
        self.maybe_emit_comment_line_continuation_diagnostic()
        continue
      }
      Some('#') => {
        self.skip_comment()
        continue
      }
      _ => break
    }
  }
}

///|
fn Parser::peek_comment_after_inline_space(
  self : Parser,
) -> (Position, String)? {
  let mut i = self.offset
  let mut pos = self.position()
  while i < self.source.length() {
    let ch = self.source[i]
    if is_unicode_space_char(ch) || is_space_char(ch) {
      i += 1
      pos = advance_position_columns(pos, 1)
      continue
    }
    if ch == '\\' && i + 1 < self.source.length() && self.source[i + 1] == '\n' {
      i += 2
      pos = { offset: pos.offset + 2, line: pos.line + 1, column: 1 }
      continue
    }
    if ch == '\\' &&
      i + 2 < self.source.length() &&
      self.source[i + 1] == '\r' &&
      self.source[i + 2] == '\n' {
      i += 3
      pos = { offset: pos.offset + 3, line: pos.line + 1, column: 1 }
      continue
    }
    if ch != '#' {
      return None
    }
    let mut end_ = i
    while end_ < self.source.length() {
      let current = self.source[end_]
      if current == '\n' || current == '\r' {
        break
      }
      end_ += 1
    }
    return Some(
      (pos, self.source.view(start_offset=i, end_offset=end_).to_string()),
    )
  }
  None
}

///|
fn Parser::peek_after_linebreak_gaps(self : Parser) -> (Position, Int)? {
  let mut i = self.offset
  let mut pos = self.position()
  while i < self.source.length() {
    let ch = self.source[i]
    if is_unicode_space_char(ch) || is_space_char(ch) {
      i += 1
      pos = advance_position_columns(pos, 1)
      continue
    }
    if ch == '\n' {
      i += 1
      pos = { offset: pos.offset + 1, line: pos.line + 1, column: 1 }
      continue
    }
    if ch == '\r' {
      i += 1
      if i < self.source.length() && self.source[i] == '\n' {
        i += 1
        pos = { offset: pos.offset + 2, line: pos.line + 1, column: 1 }
      } else {
        pos = { offset: pos.offset + 1, line: pos.line + 1, column: 1 }
      }
      continue
    }
    if ch == '#' {
      while i < self.source.length() {
        let current = self.source[i]
        if current == '\n' || current == '\r' {
          break
        }
        i += 1
        pos = advance_position_columns(pos, 1)
      }
      continue
    }
    return Some((pos, i))
  }
  None
}

///|
fn Parser::skip_command_gaps_with_state(self : Parser) -> Bool {
  let mut saw_linebreak = false
  while true {
    self.skip_inline_space()
    if self.consume_newline() {
      saw_linebreak = true
      if self.pending_heredocs.length() > 0 {
        self.read_pending_heredocs()
      }
      continue
    }
    break
  }
  saw_linebreak
}

///|
fn Parser::skip_command_gaps(self : Parser) -> Unit {
  ignore(self.skip_command_gaps_with_state())
}

///|
fn Parser::has_line_continuation_at(self : Parser, offset : Int) -> Bool {
  self.peek_n(offset) == Some('\\') &&
  (
    self.peek_n(offset + 1) == Some('\n') ||
    (
      self.peek_n(offset + 1) == Some('\r') &&
      self.peek_n(offset + 2) == Some('\n')
    )
  )
}

///|
fn Parser::is_keyword_boundary_after(self : Parser, offset : Int) -> Bool {
  self.has_line_continuation_at(offset) ||
  is_keyword_boundary(self.peek_n(offset))
}

///|
fn Parser::starts_keyword_token(self : Parser, keyword : String) -> Bool {
  self.starts_with(keyword) && self.is_keyword_boundary_after(keyword.length())
}

///|
fn Parser::eat_keyword(self : Parser, keyword : String) -> Bool {
  if !self.starts_keyword_token(keyword) {
    return false
  }
  self.advance_n(keyword.length())
  true
}

///|
fn is_reserved_word(name : String) -> Bool {
  match name {
    "if"
    | "then"
    | "else"
    | "elif"
    | "fi"
    | "for"
    | "select"
    | "while"
    | "until"
    | "do"
    | "done"
    | "case"
    | "esac"
    | "coproc"
    | "function" => true
    _ => false
  }
}

///|
fn Parser::expect_keyword(
  self : Parser,
  keyword : String,
) -> Unit raise ParseError {
  if !self.eat_keyword(keyword) {
    raise self.unexpected(keyword)
  }
}

///|
fn Parser::is_at_keyword(self : Parser, keyword : String) -> Bool {
  self.starts_keyword_token(keyword)
}

///|
fn Parser::is_at_any_keyword(self : Parser, keywords : Array[String]) -> Bool {
  for keyword in keywords {
    if self.is_at_keyword(keyword) {
      return true
    }
  }
  false
}

///|
fn Parser::accept_but_warn_semicolon(
  self : Parser,
  code : Int,
  message : String,
) -> Unit {
  let mark = self.mark()
  self.skip_inline_space()
  if self.peek() == Some(';') {
    let pos = self.position()
    ignore(self.advance_one())
    self.emit_diagnostic(DiagnosticSeverity::Error, pos, message, Some(code))
  } else {
    self.reset(mark)
  }
}

///|
fn Parser::warn_if_empty_clause(
  self : Parser,
  label : String,
  stop_keywords : Array[String],
) -> Unit raise ParseError {
  let mark = self.mark()
  ignore(self.skip_list_gaps())
  let pos = self.position()
  let is_empty = self.is_at_any_keyword(stop_keywords)
  self.reset(mark)
  if is_empty {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      pos,
      "Can't have empty \{label} clauses (use 'true' as a no-op).",
      Some(1048),
    )
  }
}

///|
fn Parser::is_at_stop(
  self : Parser,
  stop_keywords : Array[String],
  stop_char : UInt16?,
) -> Bool {
  match stop_char {
    Some('}') => if self.peek() == Some('}') { return true }
    Some(ch) => if self.peek() == Some(ch) { return true }
    None => ()
  }
  for keyword in stop_keywords {
    if self.starts_keyword_token(keyword) {
      return true
    }
  }
  false
}

///|
fn Parser::ensure_no_pending_heredocs(self : Parser) -> Unit raise ParseError {
  if self.pending_heredocs.length() > 0 {
    if self.eof() {
      self.read_pending_heredocs()
      return
    }
    raise ParseError::Message(
      pos=self.position(),
      message="missing here-document body",
    )
  }
}

///|
fn Parser::starts_brace_group(self : Parser) -> Bool {
  self.peek() == Some('{') && !self.next_starts_redirection()
}

///|
fn Parser::unexpected_reserved_word(self : Parser) -> String? {
  if self.peek() == Some('}') && is_keyword_boundary(self.peek_n(1)) {
    return Some("}")
  }
  for
    keyword in [
      "then", "else", "elif", "fi", "do", "done", "esac", "in", "function",
    ] {
    if self.starts_keyword_token(keyword) {
      return Some(keyword)
    }
  }
  None
}

///|
fn trim_ascii_space(text : String) -> String {
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
  text.view(start_offset=start, end_offset=end_).to_string()
}

///|
fn advance_position_columns(pos : Position, columns : Int) -> Position {
  { offset: pos.offset + columns, line: pos.line, column: pos.column + columns }
}

///|
fn retreat_position_columns(pos : Position, columns : Int) -> Position {
  {
    offset: pos.offset - columns,
    line: pos.line,
    column: if pos.column > columns {
      pos.column - columns
    } else {
      1
    },
  }
}

///|
fn split_once(text : String, separator : UInt16) -> (String, String)? {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    if view[i] == separator {
      let left = text.view(end_offset=i).to_string()
      let right = text.view(start_offset=i + 1).to_string()
      return Some((left, right))
    }
    i += 1
  }
  None
}

///|
fn split_shell_words(text : String) -> Array[String] {
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
fn split_shell_words_strict(
  text : String,
  base : Position,
) -> Array[String] raise ParseError {
  let values : Array[String] = []
  let current = StringBuilder::new()
  let view = text[:]
  let mut i = 0
  let mut quote : UInt16? = None
  let mut quote_start = 0
  while i < view.length() {
    let ch = view[i]
    match quote {
      Some(current_quote) => {
        current.write_char(ch.unsafe_to_char())
        if ch == current_quote {
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
          if ch == '\'' || ch == '"' {
            quote = Some(ch)
            quote_start = i
          }
        }
    }
    i += 1
  }
  match quote {
    Some(_) =>
      raise ParseError::Message(
        pos=advance_position_columns(base, quote_start),
        message="missing terminating quote for directive",
      )
    None => ()
  }
  let tail = current.to_string()
  if tail != "" {
    values.push(tail)
  }
  values
}

///|
fn parse_annotation_bool(text : String) -> Bool? {
  match text {
    "true" => Some(true)
    "false" => Some(false)
    _ => None
  }
}

///|
fn is_supported_shell_annotation(text : String) -> Bool {
  match text {
    "sh"
    | "bash"
    | "bats"
    | "busybox"
    | "busybox sh"
    | "busybox ash"
    | "dash"
    | "ash"
    | "ksh"
    | "ksh88"
    | "ksh93"
    | "oksh" => true
    _ => false
  }
}

///|
fn is_annotation_key_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '-' || ch == '_'
}

///|
fn is_valid_annotation_key(text : String) -> Bool {
  if text == "" {
    return false
  }
  for ch in text {
    if !is_annotation_key_char(ch) {
      return false
    }
  }
  true
}

///|
fn split_directive_csv(text : String) -> Array[String]? {
  let values : Array[String] = []
  let view = text[:]
  let mut start = 0
  let mut i = 0
  while i <= view.length() {
    if i == view.length() || view[i] == ',' {
      if i == start {
        return None
      }
      let item = text.view(start_offset=start, end_offset=i).to_string()
      if trim_ascii_space(item) != item {
        return None
      }
      values.push(item)
      start = i + 1
    }
    i += 1
  }
  Some(values)
}

///|
fn directive_value_source(raw : String) -> String {
  let view = raw[:]
  if view.length() >= 2 &&
    (
      (view[0] == '"' && view[view.length() - 1] == '"') ||
      (view[0] == '\'' && view[view.length() - 1] == '\'')
    ) {
    raw.view(start_offset=1, end_offset=view.length() - 1).to_string()
  } else {
    raw
  }
}

///|
fn is_disable_code(text : String) -> Bool {
  let view = text[:]
  let start = if text.has_prefix("SC") { 2 } else { 0 }
  if start >= view.length() {
    return false
  }
  let mut i = start
  while i < view.length() {
    let ch = view[i]
    if ch < '0' || ch > '9' {
      return false
    }
    i += 1
  }
  true
}

///|
fn is_disable_value(text : String) -> Bool {
  if text == "all" {
    return true
  }
  match split_once(text, '-') {
    Some((left, right)) => is_disable_code(left) && is_disable_code(right)
    None => is_disable_code(text)
  }
}

///|
fn parse_disable_code_number(text : String) -> Int? {
  let start = if text.has_prefix("SC") { 2 } else { 0 }
  let digits = text.view(start_offset=start).to_string()
  if digits == "" || !is_disable_code(text) {
    return None
  }
  Some(digits_to_int(digits))
}

///|
fn disable_value_matches_code(value : String, code : Int) -> Bool {
  if value == "all" {
    return true
  }
  match split_once(value, '-') {
    Some((left, right)) =>
      match
        (parse_disable_code_number(left), parse_disable_code_number(right)) {
        (Some(start), Some(end_)) =>
          if start <= end_ {
            start <= code && code <= end_
          } else {
            end_ <= code && code <= start
          }
        _ => false
      }
    None =>
      match parse_disable_code_number(value) {
        Some(parsed) => parsed == code
        None => false
      }
  }
}

///|
fn annotations_disable_code(
  annotations : Array[Annotation],
  code : Int?,
) -> Bool {
  match code {
    Some(value) => {
      for annotation in annotations {
        match annotation {
          Annotation::Disable(disabled) if disable_value_matches_code(
              disabled, value,
            ) => return true
          _ => ()
        }
      }
      false
    }
    None => false
  }
}

///|
fn copy_annotations(annotations : Array[Annotation]) -> Array[Annotation] {
  let copied : Array[Annotation] = []
  for annotation in annotations {
    copied.push(annotation)
  }
  copied
}

///|
fn parse_annotation_entries(
  line : String,
  pos : Position,
  options : ParseOptions,
) -> (Array[Annotation], Array[Diagnostic]) raise ParseError {
  let view = line[:]
  let mut start = 0
  while start < view.length() && is_space_char(view[start]) {
    start += 1
  }
  let rest = line.view(start_offset=start).to_string()
  let annotations : Array[Annotation] = []
  let diagnostics : Array[Diagnostic] = []
  let base = advance_position_columns(pos, start)
  let entries = split_shell_words_strict(rest, base)
  for entry in entries {
    if entry.has_prefix("#") {
      break
    }
    match split_once(entry, '=') {
      Some((key, value)) if key != "" &&
        value != "" &&
        is_valid_annotation_key(key) =>
        match key {
          "disable" =>
            match split_directive_csv(directive_value_source(value)) {
              Some(codes) if codes.length() > 0 => {
                let mut valid = true
                for code in codes {
                  if !is_disable_value(code) {
                    valid = false
                    break
                  }
                }
                if !valid {
                  diagnostics.push({
                    span: span_at(base),
                    severity: DiagnosticSeverity::Error,
                    code: Some(1125),
                    message: "invalid disable directive value '\{directive_value_source(value)}'",
                  })
                  break
                }
                for code in codes {
                  annotations.push(Annotation::Disable(code))
                }
              }
              _ => {
                diagnostics.push({
                  span: span_at(base),
                  severity: DiagnosticSeverity::Error,
                  code: Some(1125),
                  message: "invalid disable directive value '\{directive_value_source(value)}'",
                })
                break
              }
            }
          "enable" =>
            match split_directive_csv(directive_value_source(value)) {
              Some(names) if names.length() > 0 => {
                let mut valid = true
                for name in names {
                  if !is_enable_value(name) {
                    valid = false
                    break
                  }
                }
                if !valid {
                  diagnostics.push({
                    span: span_at(base),
                    severity: DiagnosticSeverity::Error,
                    code: Some(1125),
                    message: "invalid enable directive value '\{directive_value_source(value)}'",
                  })
                  break
                }
                for name in names {
                  annotations.push(Annotation::Enable(name))
                }
              }
              _ => {
                diagnostics.push({
                  span: span_at(base),
                  severity: DiagnosticSeverity::Error,
                  code: Some(1125),
                  message: "invalid enable directive value '\{directive_value_source(value)}'",
                })
                break
              }
            }
          "shell" => {
            let shell = directive_value_source(value)
            if !is_supported_shell_annotation(shell) {
              diagnostics.push({
                span: span_at(base),
                severity: DiagnosticSeverity::Error,
                code: Some(1103),
                message: "unknown shell directive value '\{shell}'; use e.g. sh or bash",
              })
            } else {
              annotations.push(Annotation::Shell(shell))
            }
          }
          "source" =>
            annotations.push(Annotation::Source(directive_value_source(value)))
          "source-path" | "source_path" =>
            annotations.push(
              Annotation::SourcePath(directive_value_source(value)),
            )
          "external-sources" | "external_sources" =>
            match parse_annotation_bool(directive_value_source(value)) {
              Some(true) =>
                if options.allow_inline_external_sources {
                  annotations.push(Annotation::ExternalSources(true))
                } else {
                  diagnostics.push({
                    span: span_at(base),
                    severity: DiagnosticSeverity::Error,
                    code: Some(1144),
                    message: "external-sources can only be enabled in parse options, not in individual files",
                  })
                }
              Some(false) =>
                annotations.push(Annotation::ExternalSources(false))
              None =>
                diagnostics.push({
                  span: span_at(base),
                  severity: DiagnosticSeverity::Error,
                  code: Some(1145),
                  message: "unknown external-sources value '\{directive_value_source(value)}'; expected true/false",
                })
            }
          "extended-analysis" | "extended_analysis" =>
            match parse_annotation_bool(directive_value_source(value)) {
              Some(flag) => annotations.push(Annotation::ExtendedAnalysis(flag))
              None =>
                diagnostics.push({
                  span: span_at(base),
                  severity: DiagnosticSeverity::Error,
                  code: Some(1146),
                  message: "unknown extended-analysis value '\{directive_value_source(value)}'; expected true/false",
                })
            }
          _ =>
            diagnostics.push({
              span: span_at(base),
              severity: DiagnosticSeverity::Warning,
              code: Some(1107),
              message: "This directive is unknown. It will be ignored.",
            })
        }
      _ => {
        diagnostics.push({
          span: span_at(base),
          severity: DiagnosticSeverity::Error,
          code: Some(1125),
          message: "invalid key=value pair in shellcheck directive; ignoring the rest of this line",
        })
        break
      }
    }
  }
  (annotations, diagnostics)
}

///|
fn is_enable_value(text : String) -> Bool {
  if text == "" {
    return false
  }
  for ch in text {
    if !((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '-') {
      return false
    }
  }
  true
}

///|
fn parse_annotation_line(
  line : String,
  pos : Position,
  options : ParseOptions,
) -> (Array[Annotation], Array[Diagnostic]) raise ParseError {
  let prefix = "# shellcheck"
  let compact_prefix = "#shellcheck"
  let rest_offset = if line.has_prefix(prefix) {
    prefix.length()
  } else if line.has_prefix(compact_prefix) {
    compact_prefix.length()
  } else {
    return ([], [])
  }
  parse_annotation_entries(
    line.view(start_offset=rest_offset).to_string(),
    advance_position_columns(pos, rest_offset),
    options,
  )
}

///|
fn is_shellcheck_annotation_comment(line : String) -> Bool {
  line.has_prefix("# shellcheck") || line.has_prefix("#shellcheck")
}

///|
fn classify_shebang_line(line : String) -> ShebangLineKind? {
  let view = line[:]
  let mut start = 0
  while start < view.length() && is_space_char(view[start]) {
    start += 1
  }
  if start >= view.length() {
    return None
  }
  let has_leading_spaces = start > 0
  if view[start] == '!' {
    if start + 1 < view.length() && view[start + 1] == '#' {
      return Some(ShebangLineKind::Swapped)
    }
    let mut path = start + 1
    while path < view.length() && is_space_char(view[path]) {
      path += 1
    }
    if path < view.length() && view[path] == '/' {
      return Some(ShebangLineKind::MissingHash)
    }
    return None
  }
  if view[start] != '#' {
    return None
  }
  if start + 1 < view.length() && view[start + 1] == '!' {
    if has_leading_spaces {
      return Some(ShebangLineKind::LeadingSpaces)
    }
    return Some(ShebangLineKind::Correct)
  }
  let mut bang = start + 1
  while bang < view.length() && is_space_char(view[bang]) {
    bang += 1
  }
  if bang < view.length() && view[bang] == '!' {
    if has_leading_spaces {
      return Some(ShebangLineKind::LeadingSpaces)
    }
    return Some(ShebangLineKind::SpacesBetweenHashBang)
  }
  if bang < view.length() && view[bang] == '/' {
    return Some(ShebangLineKind::MissingBang)
  }
  None
}

///|
fn shebang_leading_space_count(line : String) -> Int {
  let view = line[:]
  let mut count = 0
  while count < view.length() && is_space_char(view[count]) {
    count += 1
  }
  count
}

///|
fn shebang_hash_bang_gap_count(line : String) -> Int {
  let view = line[:]
  let start = shebang_leading_space_count(line)
  if start >= view.length() || view[start] != '#' {
    return 0
  }
  let mut bang = start + 1
  while bang < view.length() && is_space_char(view[bang]) {
    bang += 1
  }
  if bang < view.length() && view[bang] == '!' {
    bang - start - 1
  } else {
    0
  }
}

///|
fn is_any_shebang_line(kind : ShebangLineKind) -> Bool {
  match kind {
    ShebangLineKind::MissingBang => false
    _ => true
  }
}

///|
fn basename(text : String) -> String {
  let view = text[:]
  let mut start = 0
  let mut i = 0
  while i < view.length() {
    if view[i] == '/' {
      start = i + 1
    }
    i += 1
  }
  text.view(start_offset=start).to_string()
}

///|
fn env_shell_from_args(args : Array[String], start : Int) -> String {
  let mut i = start
  while i < args.length() {
    let arg = quote_removed_source(args[i])
    if arg.has_prefix("--split-string=") {
      let head = arg.view(start_offset="--split-string=".length()).to_string()
      if head != "" && !head.has_prefix("-") && !head.contains("=") {
        return basename(head)
      }
      i += 1
      continue
    }
    if arg.has_prefix("-") || arg.contains("=") {
      i += 1
      continue
    }
    return basename(arg)
  }
  ""
}

///|
fn executable_from_shebang(line : String) -> String {
  let command = if line.has_prefix("#!") {
    trim_ascii_space(line.view(start_offset=2).to_string())
  } else {
    trim_ascii_space(line)
  }
  let words = split_shell_words(command)
  if words.length() == 0 {
    return ""
  }
  let first = basename(quote_removed_source(words[0]))
  if first == "busybox" {
    if words.length() < 2 {
      return first
    }
    let second = basename(quote_removed_source(words[1]))
    match second {
      "sh" => "busybox sh"
      "ash" => "busybox ash"
      _ => second
    }
  } else if first == "env" {
    env_shell_from_args(words, 1)
  } else {
    first
  }
}

///|
fn classify_shebang_shell(shell : String) -> ShebangShellStatus {
  if shell == "" ||
    shell.has_prefix("sh") ||
    shell.has_prefix("ash") ||
    shell.has_prefix("dash") ||
    shell.has_prefix("busybox sh") ||
    shell.has_prefix("busybox ash") ||
    shell.has_prefix("bash") ||
    shell.has_prefix("bats") ||
    shell.has_prefix("ksh") ||
    shell.has_prefix("oksh") {
    return ShebangShellStatus::Supported
  }
  if shell.has_prefix("awk") ||
    shell.has_prefix("csh") ||
    shell.has_prefix("expect") ||
    shell.has_prefix("fish") ||
    shell.has_prefix("perl") ||
    shell.has_prefix("python") ||
    shell.has_prefix("python3") ||
    shell.has_prefix("ruby") ||
    shell.has_prefix("tcsh") ||
    shell.has_prefix("zsh") {
    return ShebangShellStatus::Unsupported
  }
  ShebangShellStatus::Unknown
}

///|
// CHECK THIS: THUNK
fn initial_position() -> Position {
  { offset: 0, line: 1, column: 1 }
}

///|
fn has_shell_annotation(annotations : Array[Annotation]) -> Bool {
  for annotation in annotations {
    match annotation {
      Annotation::Shell(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn shebang_position(has_bom : Bool) -> Position {
  {
    offset: if has_bom {
      1
    } else {
      0
    },
    line: 1,
    column: if has_bom {
      2
    } else {
      1
    },
  }
}

///|
fn Parser::parse_leading_metadata(
  self : Parser,
) -> (Bool, String?, Array[Annotation]) raise ParseError {
  let annotations : Array[Annotation] = []
  let mut has_bom = false
  let mut shebang : String? = None
  if self.peek() == Some(65279) {
    ignore(self.advance_one())
    has_bom = true
  }
  let shebang_pos = self.position()
  let first_line = self.peek_line()
  match classify_shebang_line(first_line) {
    Some(kind) =>
      match kind {
        ShebangLineKind::Correct => {
          let (line, _) = self.read_line()
          shebang = Some(line)
        }
        ShebangLineKind::LeadingSpaces
        | ShebangLineKind::SpacesBetweenHashBang => {
          let leading_spaces = shebang_leading_space_count(first_line)
          if leading_spaces > 0 {
            self.emit_diagnostic(
              DiagnosticSeverity::Error,
              shebang_pos,
              "Remove leading spaces before the shebang.",
              Some(1114),
            )
          }
          let hash_bang_gap = shebang_hash_bang_gap_count(first_line)
          if hash_bang_gap > 0 {
            self.emit_diagnostic(
              DiagnosticSeverity::Error,
              advance_position_columns(shebang_pos, leading_spaces + 1),
              "Remove spaces between # and ! in the shebang.",
              Some(1115),
            )
          }
          ignore(self.read_line())
        }
        ShebangLineKind::Swapped => {
          self.emit_diagnostic(
            DiagnosticSeverity::Error,
            shebang_pos,
            "Use #!, not !#, for the shebang.",
            Some(1084),
          )
          ignore(self.read_line())
        }
        ShebangLineKind::MissingHash => {
          self.emit_diagnostic(
            DiagnosticSeverity::Error,
            shebang_pos,
            "Use #!, not just !, for the shebang.",
            Some(1104),
          )
          ignore(self.read_line())
        }
        ShebangLineKind::MissingBang => {
          self.emit_diagnostic(
            DiagnosticSeverity::Error,
            advance_position_columns(shebang_pos, 1),
            "Use #!, not just #, for the shebang.",
            Some(1113),
          )
          ignore(self.read_line())
        }
      }
    None => ()
  }
  while true {
    let mark = self.mark()
    let line_pos = self.position()
    match classify_shebang_line(self.peek_line()) {
      Some(kind) if is_any_shebang_line(kind) =>
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          line_pos,
          "The shebang must be on the first line. Delete blanks and move comments.",
          Some(1128),
        )
      _ => ()
    }
    while self.peek() == Some(' ') || self.peek() == Some('\t') {
      ignore(self.advance_one())
    }
    if self.consume_newline() {
      continue
    }
    if self.peek() == Some('#') {
      let comment_pos = self.position()
      let (line, _) = self.read_line()
      let (line_annotations, line_diagnostics) = parse_annotation_line(
        line,
        comment_pos,
        self.options,
      )
      for diagnostic in line_diagnostics {
        self.diagnostics.push(diagnostic)
      }
      for annotation in line_annotations {
        annotations.push(annotation)
      }
      continue
    }
    self.reset(mark)
    break
  }
  (has_bom, shebang, annotations)
}

///|
fn Parser::parse_script(
  self : Parser,
  stop_keywords : Array[String],
  stop_char : UInt16?,
) -> Script raise ParseError {
  let start = self.position()
  let items : Array[ListItem] = []
  let mut pending_annotations = self.discard_orphaned_annotations(
    self.skip_list_gaps(),
    stop_keywords,
    stop_char,
  )
  while !self.eof() && !self.is_at_stop(stop_keywords, stop_char) {
    let item = self.parse_list_item(pending_annotations)
    items.push(item)
    if item.terminator is None &&
      !self.eof() &&
      !self.is_at_stop(stop_keywords, stop_char) {
      let pos = self.position()
      match trailing_command_parse_stop_message(item) {
        Some((code, message)) => {
          self.emit_diagnostic(
            DiagnosticSeverity::Error,
            pos,
            message,
            Some(code),
          )
          self.recover_after_parse_stop()
          pending_annotations = self.discard_orphaned_annotations(
            self.skip_list_gaps(),
            stop_keywords,
            stop_char,
          )
          continue
        }
        None =>
          raise ParseError::Message(
            pos~,
            message="unexpected tokens after command; missing ;/&&/||/|?",
          )
      }
    }
    pending_annotations = self.discard_orphaned_annotations(
      self.skip_list_gaps(),
      stop_keywords,
      stop_char,
    )
  }
  {
    span: make_span(start, self.position()),
    has_bom: false,
    shebang: None,
    annotations: [],
    items,
  }
}

///|
fn trailing_command_kind(item : ListItem) -> CommandKind {
  let pipeline = if item.and_or.tail.length() == 0 {
    item.and_or.head
  } else {
    item.and_or.tail[item.and_or.tail.length() - 1].1
  }
  pipeline.segments[pipeline.segments.length() - 1].command.kind
}

///|
fn trailing_command_parse_stop_message(item : ListItem) -> (Int, String)? {
  match trailing_command_kind(item) {
    CommandKind::Condition(_) =>
      Some(
        (
          1070, "Parsing stopped here. Mismatched keywords or invalid parentheses?",
        ),
      )
    CommandKind::Subshell(_) =>
      Some((1088, "Parsing stopped here. Invalid use of parentheses?"))
    CommandKind::BraceGroup(_)
    | CommandKind::If(_)
    | CommandKind::While(_)
    | CommandKind::Until(_)
    | CommandKind::ForIn(_)
    | CommandKind::ForArithmetic(_)
    | CommandKind::Select(_)
    | CommandKind::Case(_)
    | CommandKind::Function(_)
    | CommandKind::CoProc(_)
    | CommandKind::BatsTest(_) =>
      Some(
        (1089, "Parsing stopped here. Is this keyword correctly matched up?"),
      )
    _ => None
  }
}

///|
fn Parser::recover_after_parse_stop(self : Parser) -> Unit {
  while !self.eof() {
    match self.peek() {
      Some('\n') | Some('\r') => {
        ignore(self.consume_newline())
        if self.pending_heredocs.length() > 0 {
          self.read_pending_heredocs()
        }
        return
      }
      _ => ignore(self.advance_one())
    }
  }
}

///|
fn Parser::discard_orphaned_annotations(
  self : Parser,
  annotations : Array[Annotation],
  stop_keywords : Array[String],
  stop_char : UInt16?,
) -> Array[Annotation] raise ParseError {
  if annotations.length() == 0 {
    return annotations
  }
  if !self.eof() && !self.is_at_stop(stop_keywords, stop_char) {
    return annotations
  }
  let pos = self.position()
  if self.eof() {
    let message = "Expected a command. Fix any mentioned problems and try again."
    self.diagnostics.push({
      span: span_at(pos),
      severity: DiagnosticSeverity::Error,
      code: Some(1072),
      message,
    })
    raise ParseError::Message(pos~, message~)
  }
  self.diagnostics.push({
    span: span_at(pos),
    severity: DiagnosticSeverity::Error,
    code: Some(1123),
    message: "ShellCheck directives are only valid in front of complete compound commands, like 'if', not e.g. individual 'elif' branches.",
  })
  []
}

///|
fn Parser::skip_list_gaps(self : Parser) -> Array[Annotation] raise ParseError {
  let annotations : Array[Annotation] = []
  while true {
    while self.peek() == Some(' ') || self.peek() == Some('\t') {
      ignore(self.advance_one())
    }
    if self.consume_newline() {
      if self.pending_heredocs.length() > 0 {
        self.read_pending_heredocs()
      }
      continue
    }
    if self.peek() == Some('#') {
      let comment_pos = self.position()
      let (line, _) = self.read_line()
      let (line_annotations, line_diagnostics) = parse_annotation_line(
        line,
        comment_pos,
        self.options,
      )
      for diagnostic in line_diagnostics {
        self.diagnostics.push(diagnostic)
      }
      for annotation in line_annotations {
        annotations.push(annotation)
      }
      continue
    }
    break
  }
  annotations
}

///|
fn Parser::parse_list_item(
  self : Parser,
  annotations : Array[Annotation],
) -> ListItem raise ParseError {
  let start = self.position()
  let saved_annotations = self.current_annotations
  self.current_annotations = merge_annotations(
    self.file_annotations,
    annotations,
  )
  try {
    let and_or = self.parse_and_or()
    let terminator = self.parse_terminator()
    let item = {
      span: make_span(start, self.position()),
      annotations,
      and_or,
      terminator,
    }
    self.current_annotations = saved_annotations
    item
  } catch {
    err => {
      self.current_annotations = saved_annotations
      raise err
    }
  }
}

///|
fn Parser::parse_terminator(self : Parser) -> Terminator? {
  match self.peek_comment_after_inline_space() {
    Some((comment_pos, line)) if is_shellcheck_annotation_comment(line) =>
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        comment_pos,
        "Place shellcheck directives before commands, not after.",
        Some(1126),
      )
    _ => ()
  }
  self.skip_inline_space()
  if self.starts_with("&&") || self.starts_with("||") || self.starts_with("|") {
    return None
  }
  match self.peek() {
    Some('&') => {
      let amp_pos = self.position()
      ignore(self.advance_one())
      if self.starts_with("amp;") ||
        self.starts_with("gt;") ||
        self.starts_with("lt;") {
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          amp_pos,
          "This is an unquoted HTML entity. Replace with corresponding character.",
          Some(1109),
        )
      } else {
        match self.peek() {
          Some(ch) if is_name_start(ch) =>
            self.emit_diagnostic(
              DiagnosticSeverity::Warning,
              amp_pos,
              "This & terminates the command. Escape it or add space after & to silence.",
              Some(1132),
            )
          _ => ()
        }
      }
      self.skip_inline_space()
      if self.peek() == Some(';') && self.peek_n(1) != Some(';') {
        let semi_pos = self.position()
        ignore(self.advance_one())
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          semi_pos,
          "It's not 'foo &; bar', just 'foo & bar'.",
          Some(1045),
        )
      }
      Some(Terminator::Background)
    }
    Some(';') => {
      ignore(self.advance_one())
      Some(Terminator::Sequential)
    }
    Some('\n') | Some('\r') => {
      ignore(self.consume_newline())
      if self.pending_heredocs.length() > 0 {
        self.read_pending_heredocs()
      }
      match self.peek_after_linebreak_gaps() {
        Some((pos, idx)) =>
          if idx < self.source.length() &&
            (
              self.source[idx] == '|' ||
              (
                self.source[idx] == '&' &&
                (idx + 1 >= self.source.length() || self.source[idx + 1] != '>')
              )
            ) {
            self.emit_diagnostic(
              DiagnosticSeverity::Error,
              pos,
              "Unexpected start of line. If breaking lines, |/||/&& should be at the end of the previous one.",
              Some(1133),
            )
          }
        None => ()
      }
      Some(Terminator::Sequential)
    }
    _ => None
  }
}

///|
fn Parser::parse_and_or(self : Parser) -> AndOrList raise ParseError {
  let start = self.position()
  let head = self.parse_pipeline()
  let tail : Array[(AndOrOperator, Pipeline)] = []
  while true {
    self.skip_inline_space()
    if self.starts_with("&&") {
      self.advance_n(2)
      self.skip_command_gaps()
      tail.push((AndOrOperator::AndIf, self.parse_pipeline()))
      continue
    }
    if self.starts_with("||") {
      self.advance_n(2)
      self.skip_command_gaps()
      tail.push((AndOrOperator::OrIf, self.parse_pipeline()))
      continue
    }
    break
  }
  { span: make_span(start, self.position()), head, tail }
}

///|
fn Parser::parse_pipeline(self : Parser) -> Pipeline raise ParseError {
  let start = self.position()
  let segments : Array[PipelineSegment] = [self.parse_pipeline_segment()]
  let operators : Array[PipeOperator] = []
  while true {
    self.skip_inline_space()
    if self.starts_with("|&") {
      self.advance_n(2)
      self.skip_command_gaps()
      operators.push(PipeOperator::PipeAndStderr)
      segments.push(self.parse_pipeline_segment())
      continue
    }
    if self.peek() == Some('|') && !self.starts_with("||") {
      ignore(self.advance_one())
      self.skip_command_gaps()
      operators.push(PipeOperator::Pipe)
      segments.push(self.parse_pipeline_segment())
      continue
    }
    break
  }
  { span: make_span(start, self.position()), segments, operators }
}

///|
fn Parser::parse_pipeline_segment(
  self : Parser,
) -> PipelineSegment raise ParseError {
  let start = self.position()
  let mut bangs = 0
  self.skip_inline_space()
  while self.peek() == Some('!') && !self.starts_with("!=") {
    bangs += 1
    ignore(self.advance_one())
    if !is_bang_gap_char(self.peek()) {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        self.position(),
        "You are missing a required space after the !.",
        Some(1035),
      )
    }
    self.skip_command_gaps()
  }
  let command = self.parse_command()
  { span: make_span(start, self.position()), bangs, command }
}

///|
fn Parser::parse_command(self : Parser) -> Command raise ParseError {
  self.skip_command_gaps()
  let start = self.position()
  match self.try_parse_function_definition() {
    Some(command) => command
    None =>
      match self.try_parse_timed_command() {
        Some(command) => command
        None =>
          match self.try_parse_compound_command() {
            Some(kind) => {
              let redirects = self.parse_trailing_redirections()
              match kind {
                CommandKind::Condition(_) =>
                  self.maybe_emit_post_condition_command_diagnostic()
                _ => self.maybe_emit_post_compound_command_diagnostic()
              }
              let end = self.position()
              { span: make_span(start, end), kind, redirects }
            }
            None =>
              match self.unexpected_reserved_word() {
                Some(word) =>
                  raise ParseError::Message(
                    pos=self.position(),
                    message="unexpected reserved word '\{word}'",
                  )
                None => self.parse_simple_command()
              }
          }
      }
  }
}

///|
fn Parser::starts_reserved_word_token(self : Parser) -> Bool {
  for
    keyword in [
      "if", "then", "else", "elif", "fi", "for", "select", "while", "until", "do",
      "done", "case", "esac", "coproc", "function",
    ] {
    if self.starts_keyword_token(keyword) {
      return true
    }
  }
  false
}

///|
fn Parser::condition_separator_hint(self : Parser) -> (String, String)? {
  if self.starts_with("-o") && is_keyword_boundary(self.peek_n(2)) {
    return Some(("-o", "||"))
  }
  if self.starts_with("-a") && is_keyword_boundary(self.peek_n(2)) {
    return Some(("-a", "&&"))
  }
  if self.starts_with("or") && is_keyword_boundary(self.peek_n(2)) {
    return Some(("or", "||"))
  }
  if self.starts_with("and") && is_keyword_boundary(self.peek_n(3)) {
    return Some(("and", "&&"))
  }
  None
}

///|
fn Parser::maybe_emit_post_condition_command_diagnostic(self : Parser) -> Unit {
  let mark = self.mark()
  self.skip_inline_space()
  let pos = self.position()
  match self.condition_separator_hint() {
    Some((token, replacement)) =>
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        pos,
        "Use \{replacement} instead of '\{token}' between test commands.",
        Some(1139),
      )
    None =>
      if self.next_starts_word() && !self.starts_reserved_word_token() {
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          pos,
          "Unexpected parameters after condition. Missing &&/||, or bad expression?",
          Some(1140),
        )
      }
  }
  self.reset(mark)
}

///|
fn Parser::maybe_emit_post_compound_command_diagnostic(self : Parser) -> Unit {
  let mark = self.mark()
  self.skip_inline_space()
  let pos = self.position()
  match self.peek() {
    Some('}') | Some(')') => {
      self.reset(mark)
      return
    }
    _ => ()
  }
  if self.next_starts_word() &&
    !self.starts_reserved_word_token() &&
    self.peek() != Some('{') {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      pos,
      "Unexpected tokens after compound command. Bad redirection or missing ;/&&/||/|?",
      Some(1141),
    )
  }
  self.reset(mark)
}

///|
fn is_time_gap_char(ch : UInt16?) -> Bool {
  match ch {
    Some(' ') | Some('\t') | Some('\n') | Some('\r') | Some('#') => true
    _ => false
  }
}

///|
fn is_bang_gap_char(ch : UInt16?) -> Bool {
  match ch {
    None | Some(' ') | Some('\t') | Some('\n') | Some('\r') | Some('#') => true
    _ => false
  }
}

///|
fn Parser::starts_timed_command(self : Parser) -> Bool {
  self.starts_with("time") &&
  self.is_keyword_boundary_after(4) &&
  (self.has_line_continuation_at(4) || is_time_gap_char(self.peek_n(4)))
}

///|
fn Parser::starts_timed_body(self : Parser) -> Bool {
  if self.eof() {
    return false
  }
  if self.starts_with("&&") || self.starts_with("||") || self.starts_with("|") {
    return false
  }
  match self.peek() {
    Some(';') | Some('&') | Some(')') | Some('}') => false
    _ => true
  }
}

///|
fn Parser::try_parse_timed_command(self : Parser) -> Command? raise ParseError {
  let mark = self.mark()
  let start = self.position()
  if !self.starts_timed_command() {
    return None
  }
  self.advance_n(4)
  self.skip_command_gaps()

  let flags : Array[Word] = []
  while self.next_starts_word() {
    let word_mark = self.mark()
    let word = self.parse_word()
    match word_plain_text(word) {
      Some(text) if text.has_prefix("-") => {
        flags.push(word)
        self.skip_command_gaps()
      }
      _ => {
        self.reset(word_mark)
        break
      }
    }
  }

  if !self.starts_timed_body() {
    self.reset(mark)
    return None
  }

  let body = self.parse_pipeline()
  let redirects = self.parse_trailing_redirections()
  let end = self.position()
  Some({
    span: make_span(start, end),
    kind: CommandKind::Time({ flags, body }),
    redirects,
  })
}

///|
fn Parser::try_parse_function_definition(
  self : Parser,
) -> Command? raise ParseError {
  let mark = self.mark()
  let start = self.position()
  let mut uses_keyword = false
  if self.eat_keyword("function") {
    uses_keyword = true
    self.skip_command_gaps()
  }
  let name = match self.parse_function_name_token(uses_keyword) {
    Some(name) => name
    None => {
      self.reset(mark)
      return None
    }
  }
  if !uses_keyword && (is_reserved_word(name) || name == "time") {
    self.reset(mark)
    return None
  }
  let name_end = self.offset
  self.skip_inline_space()
  let had_inline_space = self.offset != name_end
  let has_parentheses = if self.peek() == Some('(') {
    ignore(self.advance_one())
    self.skip_inline_space()
    if self.peek() != Some(')') {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        self.position(),
        "Trying to declare parameters? Don't. Use () and refer to params as $1, $2..",
        Some(1065),
      )
      while self.peek() is Some(ch) {
        if ch == ')' || ch == '\n' || ch == '{' {
          break
        }
        ignore(self.advance_one())
      }
      if self.peek() != Some(')') {
        raise self.unexpected(")")
      }
    }
    ignore(self.advance_one())
    true
  } else if uses_keyword {
    false
  } else {
    self.reset(mark)
    return None
  }
  if uses_keyword && !has_parentheses && !had_inline_space {
    match self.peek() {
      Some('{') | Some('(') =>
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          self.position(),
          "You need a space or linefeed between the function name and body.",
          Some(1095),
        )
      _ => ()
    }
  }
  self.skip_command_gaps()
  let body_start = self.position()
  if self.peek() != Some('{') && self.peek() != Some('(') {
    let end_message = " Fix any mentioned problems and try again."
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      start,
      "Couldn't parse this function. Fix to allow more checks.",
      Some(1073),
    )
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      body_start,
      "Expected a { to open the function definition.",
      Some(1064),
    )
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      body_start,
      end_message,
      Some(1072),
    )
    raise ParseError::Message(pos=body_start, message=end_message)
  }
  let body_kind = match self.try_parse_non_coproc_compound_command() {
    Some(kind) => kind
    None =>
      raise ParseError::Message(
        pos=self.position(),
        message="function body must start with a compound command (for example { ...; }, ( ... ), if ..., while ..., or case ...)",
      )
  }
  let body_command = {
    let body_end = self.position()
    { span: make_span(body_start, body_end), kind: body_kind, redirects: [] }
  }
  let redirects = self.parse_trailing_redirections()
  let end = self.position()
  Some({
    span: make_span(start, end),
    kind: CommandKind::Function({
      name,
      uses_keyword,
      has_parentheses,
      body: body_command,
    }),
    redirects,
  })
}

///|
fn Parser::try_parse_group_like_command(
  self : Parser,
) -> CommandKind? raise ParseError {
  match self.peek() {
    Some('{') if self.starts_brace_group() =>
      Some(CommandKind::BraceGroup(self.parse_brace_group()))
    Some('(') if !self.starts_with("((") =>
      Some(CommandKind::Subshell(self.parse_subshell()))
    _ => None
  }
}

///|
fn Parser::try_parse_non_coproc_compound_command(
  self : Parser,
) -> CommandKind? raise ParseError {
  if self.starts_with("[[") && is_word_boundary(self.peek_n(2)) {
    return Some(CommandKind::Condition(self.parse_condition_command(true)))
  }
  if self.peek() == Some('[') &&
    self.peek_n(1) != Some('[') &&
    is_word_boundary(self.peek_n(1)) {
    return Some(CommandKind::Condition(self.parse_condition_command(false)))
  }
  if self.starts_with("((") {
    let start = self.position()
    let mark = self.mark()
    try {
      return Some(CommandKind::Arithmetic(self.parse_arithmetic_command()))
    } catch {
      _ => {
        self.reset(mark)
        try {
          let subshell = self.parse_subshell()
          self.emit_diagnostic(
            DiagnosticSeverity::Error,
            start,
            "Shells disambiguate (( differently or not at all. For subshell, add spaces around ( . For ((, fix parsing errors.",
            Some(1105),
          )
          return Some(CommandKind::Subshell(subshell))
        } catch {
          _ => {
            self.reset(mark)
            return Some(
              CommandKind::Arithmetic(self.parse_arithmetic_command()),
            )
          }
        }
      }
    }
  }
  match self.try_parse_group_like_command() {
    Some(kind) => return Some(kind)
    None => ()
  }
  match self.try_parse_bats_test() {
    Some(kind) => return Some(kind)
    None => ()
  }
  if self.starts_keyword_token("if") {
    return Some(CommandKind::If(self.parse_if_clause()))
  }
  if self.starts_keyword_token("while") {
    return Some(CommandKind::While(self.parse_while_clause()))
  }
  if self.starts_keyword_token("until") {
    return Some(CommandKind::Until(self.parse_until_clause()))
  }
  if self.starts_keyword_token("for") {
    return Some(self.parse_for_command())
  }
  if self.starts_keyword_token("select") {
    return Some(CommandKind::Select(self.parse_select_clause()))
  }
  if self.starts_keyword_token("case") {
    return Some(CommandKind::Case(self.parse_case_clause()))
  }
  None
}

///|
fn Parser::find_bats_test_name_end(self : Parser, start : Int) -> Int? {
  let mut i = start
  let mut brace_offset : Int? = None
  let mut quote : UInt16? = None
  while i < self.source.length() {
    let ch = self.source[i]
    match quote {
      Some(current_quote) => {
        if ch == '\\' && current_quote == '"' && i + 1 < self.source.length() {
          i += 2
          continue
        }
        if ch == current_quote {
          quote = None
        }
      }
      None => {
        if ch == '\n' || ch == '\r' {
          break
        }
        if ch == '\\' && i + 1 < self.source.length() {
          i += 2
          continue
        }
        if ch == '\'' || ch == '"' {
          quote = Some(ch)
        } else if ch == '{' && (i == start || is_space_char(self.source[i - 1])) {
          brace_offset = Some(i)
        }
      }
    }
    i += 1
  }
  match brace_offset {
    None => None
    Some(offset) => {
      let mut end_ = offset
      while end_ > start && is_space_char(self.source[end_ - 1]) {
        end_ -= 1
      }
      Some(end_)
    }
  }
}

///|
fn Parser::try_parse_bats_test(self : Parser) -> CommandKind? raise ParseError {
  if !self.starts_with("@test") {
    return None
  }
  match self.peek_n(5) {
    Some(ch) if is_space_char(ch) => ()
    _ => return None
  }
  let start = self.position()
  let mark = self.mark()
  self.advance_n(5)
  self.skip_inline_space()
  let name_start = self.offset
  let name_end = match self.find_bats_test_name_end(name_start) {
    Some(end_) => end_
    None => {
      self.reset(mark)
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        start,
        "Couldn't parse this bats @test. Fix to allow more checks.",
        Some(1073),
      )
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        advance_position_columns(start, 6),
        " Fix any mentioned problems and try again.",
        Some(1072),
      )
      return None
    }
  }
  self.advance_n(name_end - self.offset)
  let name = self.source
    .view(start_offset=name_start, end_offset=name_end)
    .to_string()
  self.skip_inline_space()
  if self.peek() != Some('{') {
    self.reset(mark)
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      start,
      "Couldn't parse this bats @test. Fix to allow more checks.",
      Some(1073),
    )
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      advance_position_columns(start, 6),
      " Fix any mentioned problems and try again.",
      Some(1072),
    )
    return None
  }
  Some(CommandKind::BatsTest({ name, body: self.parse_brace_group() }))
}

///|
fn Parser::next_starts_coproc_name_target(self : Parser) -> Bool {
  if self.starts_brace_group() {
    return true
  }
  if self.peek() == Some('(') && !self.starts_with("((") {
    return true
  }
  if self.starts_with("[[") || self.starts_with("((") {
    return true
  }
  if self.starts_keyword_token("if") {
    return true
  }
  if self.starts_keyword_token("while") {
    return true
  }
  if self.starts_keyword_token("until") {
    return true
  }
  if self.starts_keyword_token("for") {
    return true
  }
  if self.starts_keyword_token("select") {
    return true
  }
  if self.starts_keyword_token("case") {
    return true
  }
  false
}

///|
fn Parser::try_parse_compound_command(
  self : Parser,
) -> CommandKind? raise ParseError {
  match self.try_parse_non_coproc_compound_command() {
    Some(kind) => return Some(kind)
    None => ()
  }
  if self.starts_keyword_token("coproc") {
    return Some(CommandKind::CoProc(self.parse_coproc_clause()))
  }
  None
}

///|
fn Parser::parse_brace_group(self : Parser) -> Script raise ParseError {
  if self.peek() != Some('{') {
    raise self.unexpected("{")
  }
  ignore(self.advance_one())
  let after_open = self.position()
  match self.peek() {
    Some('(') | Some(' ') | Some('\t') | Some('\n') | Some('\r') | Some('#') =>
      ()
    Some('\\') if self.peek_n(1) == Some('\n') ||
      (self.peek_n(1) == Some('\r') && self.peek_n(2) == Some('\n')) => ()
    Some('}') =>
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        after_open,
        "empty brace groups require at least one command",
        Some(1055),
      )
    _ =>
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        after_open,
        "You need a space after the '{'.",
        Some(1054),
      )
  }
  let body = self.parse_script([], Some('}'))
  if self.peek() != Some('}') {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      self.position(),
      "Expected a '}'. If you have one, try a ; or \\n in front of it.",
      Some(1056),
    )
    return body
  }
  ignore(self.advance_one())
  body
}

///|
fn Parser::parse_subshell(self : Parser) -> Script raise ParseError {
  if self.peek() != Some('(') {
    raise self.unexpected("(")
  }
  ignore(self.advance_one())
  let body = self.parse_script([], Some(')'))
  if self.peek() != Some(')') {
    raise self.unexpected(")")
  }
  ignore(self.advance_one())
  body
}

///|
fn Parser::parse_if_clause(self : Parser) -> IfClause raise ParseError {
  let if_pos = self.position()
  self.expect_keyword("if")
  let arms : Array[IfArm] = []
  let condition = self.parse_script(["then", "elif", "else", "fi"], None)
  if !self.is_at_keyword("then") {
    if self.is_at_any_keyword(["elif", "else", "fi"]) {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        if_pos,
        "Did you forget the 'then' for this 'if'?",
        Some(1049),
      )
    }
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      self.position(),
      "Expected 'then'.",
      Some(1050),
    )
  } else {
    ignore(self.eat_keyword("then"))
  }
  self.accept_but_warn_semicolon(
    1051, "Semicolons directly after 'then' are not allowed. Just remove it.",
  )
  self.warn_if_empty_clause("then", ["elif", "else", "fi"])
  let body = self.parse_script(["elif", "else", "fi"], None)
  arms.push({ condition, body })
  while true {
    let elif_pos = self.position()
    if !self.eat_keyword("elif") {
      break
    }
    let elif_condition = self.parse_script(["then", "elif", "else", "fi"], None)
    if !self.is_at_keyword("then") {
      if self.is_at_any_keyword(["elif", "else", "fi"]) {
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          elif_pos,
          "Did you forget the 'then' for this 'elif'?",
          Some(1049),
        )
      }
    } else {
      ignore(self.eat_keyword("then"))
    }
    self.accept_but_warn_semicolon(
      1052, "Semicolons directly after 'then' are not allowed. Just remove it.",
    )
    self.warn_if_empty_clause("then", ["elif", "else", "fi"])
    let elif_body = self.parse_script(["elif", "else", "fi"], None)
    arms.push({ condition: elif_condition, body: elif_body })
  }
  let else_body = if self.is_at_keyword("else") {
    let else_pos = self.position()
    ignore(self.eat_keyword("else"))
    let mark = self.mark()
    self.skip_inline_space()
    if self.eat_keyword("if") {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        else_pos,
        "Use 'elif' instead of 'else if' (or put 'if' on new line if nesting).",
        Some(1075),
      )
    }
    self.reset(mark)
    self.accept_but_warn_semicolon(
      1053, "Semicolons directly after 'else' are not allowed. Just remove it.",
    )
    self.warn_if_empty_clause("else", ["fi"])
    Some(self.parse_script(["fi"], None))
  } else {
    None
  }
  if !self.eat_keyword("fi") {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      if_pos,
      "Couldn't find 'fi' for this 'if'.",
      Some(1046),
    )
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      self.position(),
      "Expected 'fi' matching previously mentioned 'if'.",
      Some(1047),
    )
  }
  { arms, else_body }
}

///|
fn Parser::parse_while_clause(self : Parser) -> LoopClause raise ParseError {
  let loop_pos = self.position()
  self.expect_keyword("while")
  let condition = self.parse_script(["do", "done"], None)
  let body = self.parse_do_group_body(loop_pos)
  { condition, body }
}

///|
fn Parser::parse_until_clause(self : Parser) -> LoopClause raise ParseError {
  let loop_pos = self.position()
  self.expect_keyword("until")
  let condition = self.parse_script(["do", "done"], None)
  let body = self.parse_do_group_body(loop_pos)
  { condition, body }
}

///|
fn Parser::parse_do_group_body(
  self : Parser,
  loop_pos : Position,
) -> Script raise ParseError {
  let do_pos = self.position()
  if self.is_at_keyword("done") {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      loop_pos,
      "Did you forget the 'do' for this loop?",
      Some(1057),
    )
  }
  if !self.eat_keyword("do") {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      self.position(),
      "Expected 'do'.",
      Some(1058),
    )
  }
  self.accept_but_warn_semicolon(
    1059, "Semicolon is not allowed directly after 'do'. You can just delete it.",
  )
  let empty_mark = self.mark()
  ignore(self.skip_list_gaps())
  let empty_pos = self.position()
  let empty_body = self.is_at_keyword("done")
  self.reset(empty_mark)
  if empty_body {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      empty_pos,
      "Can't have empty do clauses (use 'true' as a no-op).",
      Some(1060),
    )
  }
  let body = self.parse_script(["done"], None)
  if !self.eat_keyword("done") {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      do_pos,
      "Couldn't find 'done' for this 'do'.",
      Some(1061),
    )
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      self.position(),
      "Expected 'done' matching previously mentioned 'do'.",
      Some(1062),
    )
  }
  let mark = self.mark()
  self.skip_inline_space()
  if self.starts_with("<(") {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      self.position(),
      "Use 'done < <(cmd)' to redirect from process substitution (currently missing one '<').",
      Some(1142),
    )
    ignore(self.parse_word())
    return body
  }
  self.reset(mark)
  body
}

///|
fn Parser::finish_loop_header(
  self : Parser,
  keyword : String,
  saw_in_clause : Bool,
  require_separator_without_in : Bool,
  saw_linebreak_without_in : Bool,
) -> Unit raise ParseError {
  self.skip_inline_space()
  if self.peek() == Some(';') {
    ignore(self.advance_one())
    self.skip_command_gaps()
    return
  }
  if self.peek() == Some('\n') ||
    self.peek() == Some('\r') ||
    self.peek() == Some('#') {
    self.skip_command_gaps()
    return
  }
  if saw_in_clause && self.starts_keyword_token("do") {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      self.position(),
      "You need a line feed or semicolon before the 'do'.",
      Some(1063),
    )
    return
  }
  if !saw_in_clause && require_separator_without_in && saw_linebreak_without_in {
    return
  }
  if require_separator_without_in {
    let message = if self.starts_keyword_token("do") {
      "expected ';' or linefeed before 'do' in \{keyword} loop"
    } else {
      "expected 'in' or separator after \{keyword} variable"
    }
    raise ParseError::Message(pos=self.position(), message~)
  }
  self.skip_command_gaps()
}

///|
fn Parser::parse_for_values_and_body_after_keyword(
  self : Parser,
  keyword : String,
  allow_paren_values : Bool,
  allow_brace_group : Bool,
  require_separator_without_in : Bool,
  loop_pos : Position,
) -> (String, Array[Word], Script) raise ParseError {
  self.skip_command_gaps()
  if self.peek() == Some('$') {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      self.position(),
      "Don't use $ on the iterator name in for loops.",
      Some(1086),
    )
    ignore(self.advance_one())
  }
  let name = self.parse_identifier_token("for loop variable")
  let saw_header_linebreak = self.skip_command_gaps_with_state()
  let values : Array[Word] = []
  if allow_paren_values && self.peek() == Some('(') && !self.starts_with("((") {
    ignore(self.advance_one())
    self.skip_command_gaps()
    while self.peek() != Some(')') {
      values.push(self.parse_word())
      self.skip_command_gaps()
    }
    if self.peek() != Some(')') {
      raise self.unexpected(")")
    }
    ignore(self.advance_one())
    self.finish_loop_header(
      keyword, false, require_separator_without_in, saw_header_linebreak,
    )
    return (name, values, self.parse_script([], None))
  }
  let mut saw_in_clause = false
  if self.eat_keyword("in") {
    saw_in_clause = true
    self.skip_command_gaps()
    while true {
      if self.eof() ||
        self.peek() == Some(';') ||
        self.peek() == Some('\n') ||
        self.peek() == Some('\r') ||
        self.starts_keyword_token("do") {
        break
      }
      values.push(self.parse_word())
      self.skip_inline_space()
    }
  }
  self.finish_loop_header(
    keyword, saw_in_clause, require_separator_without_in, saw_header_linebreak,
  )
  let body = if allow_brace_group && self.starts_brace_group() {
    self.parse_brace_group()
  } else {
    self.parse_do_group_body(loop_pos)
  }
  (name, values, body)
}

///|
fn Parser::parse_for_values_and_body(
  self : Parser,
  keyword : String,
) -> (String, Array[Word], Script) raise ParseError {
  let loop_pos = self.position()
  self.expect_keyword(keyword)
  self.parse_for_values_and_body_after_keyword(
    keyword,
    false,
    false,
    keyword == "select",
    loop_pos,
  )
}

///|
fn split_top_level_semicolons(text : String) -> Array[String] {
  let parts : Array[String] = []
  let parser = Parser::new(text.view(), ParseOptions::default(), [])
  let mut start = 0
  let mut paren_depth = 0
  while parser.peek() is Some(ch) {
    let nested = parser.skip_shell_nested_segment("arithmetic for loop") catch {
      _ => false
    }
    if nested {
      continue
    }
    if ch == '\\' {
      parser.advance_n(2)
      continue
    }
    if ch == '(' {
      paren_depth += 1
    } else if ch == ')' && paren_depth > 0 {
      paren_depth -= 1
    } else if ch == ';' && paren_depth == 0 {
      parts.push(
        trim_ascii_space(
          text.view(start_offset=start, end_offset=parser.offset).to_string(),
        ),
      )
      ignore(parser.advance_one())
      start = parser.offset
      continue
    }
    ignore(parser.advance_one())
  }
  parts.push(trim_ascii_space(text.view(start_offset=start).to_string()))
  parts
}

///|
fn Parser::read_arithmetic_for_delimiter(
  self : Parser,
  ch : UInt16,
  missing_message : String,
) -> Bool {
  if self.peek() != Some(ch) {
    return false
  }
  ignore(self.advance_one())
  let gap_start = self.position()
  self.skip_inline_space()
  let gap_end = self.position()
  if self.peek() != Some(ch) {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      gap_start,
      missing_message,
      Some(1137),
    )
    return false
  }
  if gap_end.offset != gap_start.offset {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      gap_start,
      "Remove spaces between \{char_display(ch)}\{char_display(ch)} in arithmetic for loop.",
      Some(1138),
    )
  }
  ignore(self.advance_one())
  true
}

///|
fn Parser::read_arithmetic_for_loop_raw(
  self : Parser,
) -> String raise ParseError {
  let content = StringBuilder::new()
  let mut depth = 1
  while self.peek() is Some(ch) {
    if ch == '\'' || ch == '"' {
      ignore(self.advance_one())
      content.write_char(ch.unsafe_to_char())
      content.write_string(self.read_until_matching_quote(ch))
      if self.peek() != Some(ch) {
        raise self.unexpected_end("arithmetic for loop")
      }
      ignore(self.advance_one())
      content.write_char(ch.unsafe_to_char())
      continue
    }
    if ch == '(' {
      depth += 1
      ignore(self.advance_one())
      content.write_char('(')
      continue
    }
    if ch == ')' {
      if depth == 1 {
        ignore(self.advance_one())
        let gap_start = self.position()
        self.skip_inline_space()
        let gap_end = self.position()
        if self.peek() == Some(')') {
          if gap_end.offset != gap_start.offset {
            self.emit_diagnostic(
              DiagnosticSeverity::Error,
              gap_start,
              "Remove spaces between )) in arithmetic for loop.",
              Some(1138),
            )
          }
          ignore(self.advance_one())
          return content.to_string()
        }
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          gap_start,
          "Missing second ')' to terminate 'for ((;;))' loop condition",
          Some(1137),
        )
        return content.to_string()
      }
      depth -= 1
      ignore(self.advance_one())
      content.write_char(')')
      continue
    }
    if ch == '\\' {
      ignore(self.advance_one())
      content.write_char('\\')
      match self.peek() {
        Some(next) => {
          ignore(self.advance_one())
          content.write_char(next.unsafe_to_char())
        }
        None => raise self.unexpected_end("arithmetic for loop")
      }
      continue
    }
    ignore(self.advance_one())
    content.write_char(ch.unsafe_to_char())
  }
  raise self.unexpected_end("arithmetic for loop")
}

///|
fn Parser::parse_for_command(self : Parser) -> CommandKind raise ParseError {
  let loop_pos = self.position()
  self.expect_keyword("for")
  self.skip_command_gaps()
  if self.peek() == Some('(') {
    if !self.read_arithmetic_for_delimiter(
        '(', "Missing second '(' to start arithmetic for ((;;)) loop",
      ) {
      raise ParseError::Message(
        pos=self.position(),
        message="expected arithmetic for loop",
      )
    }
    let raw = self.read_arithmetic_for_loop_raw()
    let parts = split_top_level_semicolons(raw)
    if parts.length() != 3 {
      raise ParseError::Message(
        pos=self.position(),
        message="expected three arithmetic clauses in for loop",
      )
    }
    self.skip_inline_space()
    if self.peek() == Some(';') {
      ignore(self.advance_one())
    }
    self.skip_command_gaps()
    let body = if self.starts_brace_group() {
      self.parse_brace_group()
    } else {
      self.parse_do_group_body(loop_pos)
    }
    return CommandKind::ForArithmetic({
      init: parse_arithmetic_expr(parts[0]),
      condition: parse_arithmetic_expr(parts[1]),
      step: parse_arithmetic_expr(parts[2]),
      body,
    })
  }
  let (name, values, body) = self.parse_for_values_and_body_after_keyword(
    "for", true, true, false, loop_pos,
  )
  CommandKind::ForIn({ name, values, body })
}

///|
fn Parser::parse_select_clause(self : Parser) -> SelectClause raise ParseError {
  let (name, values, body) = self.parse_for_values_and_body("select")
  { name, values, body }
}

///|
fn Parser::skip_condition_space(self : Parser, double_bracket : Bool) -> Unit {
  while true {
    match self.peek() {
      Some(ch) if is_unicode_space_char(ch) =>
        ignore(self.consume_unicode_space())
      Some(' ') | Some('\t') => ignore(self.advance_one())
      Some('\n') | Some('\r') => {
        if !double_bracket {
          self.emit_diagnostic(
            DiagnosticSeverity::Error,
            self.position(),
            "When breaking lines in [ ], you need \\ before the linefeed.",
            Some(1080),
          )
        }
        ignore(self.consume_newline())
      }
      Some('\\') if self.peek_n(1) == Some('\n') => {
        self.advance_n(2)
        self.maybe_emit_comment_line_continuation_diagnostic()
      }
      Some('\\') if self.peek_n(1) == Some('\r') && self.peek_n(2) == Some('\n') => {
        self.advance_n(3)
        self.maybe_emit_comment_line_continuation_diagnostic()
      }
      _ => break
    }
  }
}

///|
fn ConditionCursor::peek(self : ConditionCursor) -> ConditionToken? {
  if self.index >= self.tokens.length() {
    None
  } else {
    Some(self.tokens[self.index])
  }
}

///|
fn ConditionCursor::advance(self : ConditionCursor) -> ConditionToken? {
  if self.index >= self.tokens.length() {
    None
  } else {
    let token = self.tokens[self.index]
    self.index += 1
    Some(token)
  }
}

///|
fn is_unary_condition_operator(text : String) -> Bool {
  match text {
    "-a"
    | "-b"
    | "-c"
    | "-d"
    | "-e"
    | "-f"
    | "-g"
    | "-h"
    | "-k"
    | "-L"
    | "-n"
    | "-N"
    | "-o"
    | "-O"
    | "-p"
    | "-r"
    | "-s"
    | "-S"
    | "-t"
    | "-u"
    | "-v"
    | "-w"
    | "-x"
    | "-z"
    | "-G" => true
    _ => false
  }
}

///|
fn is_condition_operator_like_unknown_unary(text : String) -> Bool {
  if is_unary_condition_operator(text) || !text.has_prefix("-") {
    return false
  }
  let view = text[:]
  if view.length() < 2 {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if !is_ascii_alpha(view[i]) {
      return false
    }
    i += 1
  }
  true
}

///|
fn is_binary_condition_operator(text : String) -> Bool {
  match text {
    "="
    | "=="
    | "!="
    | "<="
    | ">="
    | "<"
    | ">"
    | "=~"
    | "-eq"
    | "-ne"
    | "-lt"
    | "-le"
    | "-gt"
    | "-ge"
    | "-nt"
    | "-ot"
    | "-ef" => true
    _ => false
  }
}

///|
fn is_condition_operator_like_unknown_binary(text : String) -> Bool {
  if is_binary_condition_operator(text) ||
    text == "-a" ||
    text == "-o" ||
    !text.has_prefix("-") {
    return false
  }
  let view = text[:]
  if view.length() < 2 {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if !is_ascii_alpha(view[i]) {
      return false
    }
    i += 1
  }
  true
}

///|
fn Parser::condition_starts_closing(
  self : Parser,
  double_bracket : Bool,
) -> Bool {
  if double_bracket {
    self.starts_with("]]")
  } else {
    self.peek() == Some(']')
  }
}

///|
fn Parser::condition_closing_delimiter(
  self : Parser,
  double_bracket : Bool,
  regex_rhs_expected : Bool,
  group_depth : Int,
) -> String? {
  if self.starts_with("]]") {
    return Some("]]")
  }
  if self.peek() == Some(']') &&
    (!double_bracket || (!regex_rhs_expected && group_depth == 0)) {
    return Some("]")
  }
  None
}

///|
fn Parser::condition_regex_has_boundary_after_space(
  self : Parser,
  double_bracket : Bool,
) -> Bool {
  let cursor = self.mark()
  self.skip_condition_space(double_bracket)
  let result = self.eof() ||
    self.condition_starts_closing(double_bracket) ||
    (
      double_bracket &&
      (
        self.starts_with("&&") ||
        self.starts_with("||") ||
        self.peek() == Some(')')
      )
    )
  self.reset(cursor)
  result
}

///|
fn Parser::parse_condition_regex_word(
  self : Parser,
  double_bracket : Bool,
) -> Word raise ParseError {
  let start = self.position()
  let start_offset = self.offset
  let parts : Array[WordPart] = []
  let literal = StringBuilder::new()
  let mut paren_depth = 0
  let mut bracket_depth = 0
  while self.peek() is Some(ch) {
    if paren_depth == 0 &&
      bracket_depth == 0 &&
      self.condition_starts_closing(double_bracket) {
      break
    }
    if paren_depth == 0 &&
      bracket_depth == 0 &&
      is_condition_regex_boundary(Some(ch)) &&
      self.condition_regex_has_boundary_after_space(double_bracket) {
      break
    }
    match ch {
      '[' => {
        ignore(self.advance_one())
        literal.write_char('[')
        bracket_depth += 1
      }
      ']' => {
        ignore(self.advance_one())
        literal.write_char(']')
        if bracket_depth > 0 {
          bracket_depth -= 1
        }
      }
      '(' => {
        ignore(self.advance_one())
        literal.write_char('(')
        paren_depth += 1
      }
      ')' => {
        if paren_depth == 0 {
          break
        }
        ignore(self.advance_one())
        literal.write_char(')')
        paren_depth -= 1
      }
      '\'' => {
        push_literal(parts, literal)
        let quote_start = self.position()
        ignore(self.advance_one())
        parts.push(
          WordPart::SingleQuoted(self.read_until_single_quote(quote_start)),
        )
      }
      '"' => {
        push_literal(parts, literal)
        let quote_start = self.position()
        ignore(self.advance_one())
        parts.push(
          WordPart::DoubleQuoted(self.read_double_quoted_parts(quote_start)),
        )
      }
      ch if is_backquote_char(ch) => {
        push_literal(parts, literal)
        let quote_start = self.position()
        self.consume_backquote_start()
        parts.push(
          WordPart::BackQuoted(self.read_backquoted_script(false, quote_start)),
        )
      }
      '$' =>
        match self.parse_dollar_part() {
          Some(part) => {
            push_literal(parts, literal)
            parts.push(part)
          }
          None => {
            ignore(self.advance_one())
            literal.write_char('$')
          }
        }
      '\\' => {
        ignore(self.advance_one())
        match self.peek() {
          Some('\n') | Some('\r') => {
            if paren_depth == 0 &&
              bracket_depth == 0 &&
              self.condition_regex_has_boundary_after_space(double_bracket) {
              break
            }
            ignore(self.consume_newline())
          }
          Some(next) => {
            ignore(self.advance_one())
            literal.write_char('\\')
            literal.write_char(next.unsafe_to_char())
          }
          None => raise self.unexpected_end("escaped character")
        }
      }
      ' ' | '\t' => {
        ignore(self.advance_one())
        literal.write_char(ch.unsafe_to_char())
      }
      '\r' => {
        ignore(self.consume_newline())
        literal.write_char('\n')
      }
      '\n' => {
        ignore(self.advance_one())
        literal.write_char('\n')
      }
      _ => {
        self.maybe_emit_unicode_quote(ch)
        ignore(self.advance_one())
        literal.write_char(ch.unsafe_to_char())
      }
    }
  }
  push_literal(parts, literal)
  if self.offset == start_offset {
    raise self.unexpected("word")
  }
  {
    span: make_span(start, self.position()),
    source: self.current_slice(start_offset),
    parts,
  }
}

///|
fn Parser::read_condition_tokens(
  self : Parser,
  double_bracket : Bool,
  context : String,
) -> (String, Array[ConditionToken], String, Position) raise ParseError {
  let start_offset = self.offset
  let tokens : Array[ConditionToken] = []
  let mut regex_rhs_expected = false
  let mut group_depth = 0
  self.skip_condition_space(double_bracket)
  while true {
    match
      self.condition_closing_delimiter(
        double_bracket, regex_rhs_expected, group_depth,
      ) {
      Some(closing) =>
        if group_depth > 0 {
          raise ParseError::Message(
            pos=self.position(),
            message="missing ')' in condition expression",
          )
        } else {
          return (
            trim_ascii_space(self.current_slice(start_offset)),
            tokens,
            closing,
            self.position(),
          )
        }
      None => ()
    }
    if self.eof() {
      raise self.unexpected_end(context)
    }
    if regex_rhs_expected {
      tokens.push(
        ConditionToken::Word(self.parse_condition_regex_word(double_bracket)),
      )
      regex_rhs_expected = false
    } else if double_bracket && self.starts_with("\\(") {
      let pos = self.position()
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        pos,
        "In [[..]] you shouldn't escape ( or ).",
        Some(1029),
      )
      self.advance_n(2)
      group_depth += 1
      tokens.push(ConditionToken::LParen)
    } else if double_bracket && self.starts_with("\\)") {
      let pos = self.position()
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        pos,
        "In [[..]] you shouldn't escape ( or ).",
        Some(1029),
      )
      if group_depth == 0 {
        raise ParseError::Message(
          pos~,
          message="unexpected ')' in condition expression",
        )
      }
      self.advance_n(2)
      group_depth -= 1
      tokens.push(ConditionToken::RParen)
    } else if double_bracket && self.starts_with("&&") {
      self.advance_n(2)
      tokens.push(ConditionToken::And)
    } else if double_bracket && self.starts_with("||") {
      self.advance_n(2)
      tokens.push(ConditionToken::Or)
    } else if double_bracket && self.peek() == Some('(') {
      ignore(self.advance_one())
      group_depth += 1
      tokens.push(ConditionToken::LParen)
    } else if double_bracket && self.peek() == Some(')') {
      if group_depth == 0 {
        raise ParseError::Message(
          pos=self.position(),
          message="unexpected ')' in condition expression",
        )
      }
      ignore(self.advance_one())
      group_depth -= 1
      tokens.push(ConditionToken::RParen)
    } else if !double_bracket && self.peek() == Some('(') {
      let pos = self.position()
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        pos,
        "In [..] you have to escape \\( \\) or preferably combine [..] expressions.",
        Some(1028),
      )
      ignore(self.advance_one())
      group_depth += 1
      tokens.push(ConditionToken::LParen)
    } else if !double_bracket && self.peek() == Some(')') {
      let pos = self.position()
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        pos,
        "In [..] you have to escape \\( \\) or preferably combine [..] expressions.",
        Some(1028),
      )
      if group_depth == 0 {
        raise ParseError::Message(
          pos~,
          message="unexpected ')' in condition expression",
        )
      }
      ignore(self.advance_one())
      group_depth -= 1
      tokens.push(ConditionToken::RParen)
    } else if !double_bracket && self.starts_with("\\(") {
      self.advance_n(2)
      group_depth += 1
      tokens.push(ConditionToken::LParen)
    } else if !double_bracket && self.starts_with("\\)") {
      if group_depth == 0 {
        raise ParseError::Message(
          pos=self.position(),
          message="unexpected ')' in condition expression",
        )
      }
      self.advance_n(2)
      group_depth -= 1
      tokens.push(ConditionToken::RParen)
    } else if !double_bracket && self.peek() == Some('[') {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        self.position(),
        "If grouping expressions inside [..], use \\( ..\\).",
        Some(1026),
      )
      ignore(self.advance_one())
      self.skip_condition_space(double_bracket)
      raise ParseError::Message(
        pos=self.position(),
        message=condition_internal_message("1026"),
      )
    } else if double_bracket &&
      (self.starts_with("<=") || self.starts_with(">=")) {
      let start = self.position()
      let start_offset = self.offset
      self.advance_n(2)
      let source = self.current_slice(start_offset)
      tokens.push(
        ConditionToken::Word({
          span: make_span(start, self.position()),
          source,
          parts: [WordPart::Literal(source)],
        }),
      )
    } else if double_bracket &&
      (self.peek() == Some('<') || self.peek() == Some('>')) {
      let start = self.position()
      let start_offset = self.offset
      ignore(self.advance_one())
      let source = self.current_slice(start_offset)
      tokens.push(
        ConditionToken::Word({
          span: make_span(start, self.position()),
          source,
          parts: [WordPart::Literal(source)],
        }),
      )
    } else if self.peek() is Some(ch) &&
      is_unicode_dash_char(ch) &&
      self.peek_n(1) is Some(next) &&
      is_ascii_alpha(next) {
      let start = self.position()
      let start_offset = self.offset
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        start,
        "This is a unicode dash. Delete and retype as ASCII minus.",
        Some(1100),
      )
      ignore(self.advance_one())
      while self.peek() is Some(current) && is_ascii_alpha(current) {
        ignore(self.advance_one())
      }
      let source = self.current_slice(start_offset)
      let normalized = "-" + source.view(start_offset=1).to_string()
      tokens.push(
        ConditionToken::Word({
          span: make_span(start, self.position()),
          source: normalized,
          parts: [WordPart::Literal(normalized)],
        }),
      )
    } else {
      let word = self.parse_word()
      match word_trailing_unquoted_literal(word) {
        Some(text) if !double_bracket &&
          text.has_suffix("]") &&
          !word_is_literal_array_index(word) &&
          !word_contains_unquoted_literal_fragment(word, "[") =>
          raise ParseError::Message(
            pos=word.span.end,
            message=condition_internal_message("1020"),
          )
        Some(text) if !double_bracket && text.has_suffix(")") =>
          raise ParseError::Message(
            pos=word.span.end,
            message=condition_internal_message("1021"),
          )
        _ => ()
      }
      if word_literal_text(word) == Some("=~") {
        regex_rhs_expected = true
      }
      tokens.push(ConditionToken::Word(word))
    }
    self.skip_condition_space(double_bracket)
  }
  raise self.unexpected_end(context)
}

///|
fn parse_condition_word_token(cursor : ConditionCursor) -> Word? {
  match cursor.peek() {
    Some(ConditionToken::Word(word)) => {
      ignore(cursor.advance())
      Some(word)
    }
    _ => None
  }
}

///|
fn is_single_bracket_group_open_word(word : Word) -> Bool {
  word_literal_text(word) == Some("(") && word.source != "("
}

///|
fn is_single_bracket_group_close_word(word : Word) -> Bool {
  word_literal_text(word) == Some(")") && word.source != ")"
}

///|
fn condition_token_position(
  token : ConditionToken?,
  fallback : Position,
) -> Position {
  match token {
    Some(ConditionToken::Word(word)) => word.span.start
    _ => fallback
  }
}

///|
fn condition_specific_diagnostic(
  severity : DiagnosticSeverity,
  pos : Position,
  code : Int,
  message : String,
) -> Diagnostic {
  { span: span_at(pos), severity, code: Some(code), message }
}

///|
fn condition_token_word_text(token : ConditionToken?) -> String? {
  match token {
    Some(ConditionToken::Word(word)) => word_plain_text(word)
    _ => None
  }
}

///|
let common_condition_command_table : Array[String] = [
  "admin", "alias", "ar", "asa", "at", "awk", "basename", "batch", "bc", "bg", "break",
  "c99", "cal", "cat", "cd", "cflow", "chgrp", "chmod", "chown", "cksum", "cmp",
  "colon", "comm", "command", "compress", "continue", "cp", "crontab", "csplit",
  "ctags", "cut", "cxref", "date", "dd", "delta", "df", "diff", "dirname", "dot",
  "du", "echo", "ed", "env", "eval", "ex", "exec", "exit", "expand", "export", "expr",
  "fc", "fg", "file", "find", "fold", "fuser", "gencat", "get", "getconf", "getopts",
  "gettext", "grep", "hash", "head", "iconv", "ipcrm", "ipcs", "jobs", "join", "kill",
  "lex", "link", "ln", "locale", "localedef", "logger", "logname", "lp", "ls", "m4",
  "mailx", "make", "man", "mesg", "mkdir", "mkfifo", "more", "msgfmt", "mv", "newgrp",
  "ngettext", "nice", "nl", "nm", "nohup", "od", "paste", "patch", "pathchk", "pax",
  "pr", "printf", "prs", "ps", "pwd", "read", "readlink", "readonly", "realpath",
  "renice", "return", "rm", "rmdel", "rmdir", "sact", "sccs", "sed", "set", "sh",
  "shift", "sleep", "sort", "split", "strings", "strip", "stty", "tabs", "tail",
  "talk", "tee", "test", "time", "timeout", "times", "touch", "tput", "tr", "trap",
  "tsort", "tty", "type", "ulimit", "umask", "unalias", "uname", "uncompress", "unexpand",
  "unget", "uniq", "unlink", "unset", "uucp", "uudecode", "uuencode", "uustat", "uux",
  "val", "vi", "wait", "wc", "what", "who", "write", "xargs", "xgettext", "yacc",
  "zcat",
]

///|
fn is_common_condition_command(name : String) -> Bool {
  common_condition_command_table.contains(name)
}

///|
fn trailing_condition_operator(text : String) -> String? {
  for
    op in [
      "<=", ">=", "==", "!=", "=~", "-eq", "-ne", "-lt", "-le", "-gt", "-ge", "-nt",
      "-ot", "-ef", "<", ">", "=",
    ] {
    if text.has_suffix(op) {
      return Some(op)
    }
  }
  None
}

///|
fn is_condition_arithmetic_operator(text : String) -> Bool {
  text == "+" || text == "-" || text == "*" || text == "/" || text == "%"
}

///|
fn next_condition_is_logical_and(cursor : ConditionCursor) -> Bool {
  match cursor.peek() {
    Some(ConditionToken::And) => true
    Some(ConditionToken::Word(word)) if cursor.kind ==
      ConditionKind::SingleBracket &&
      word_plain_text(word) == Some("-a") => true
    _ => false
  }
}

///|
fn next_condition_is_logical_or(cursor : ConditionCursor) -> Bool {
  match cursor.peek() {
    Some(ConditionToken::Or) => true
    Some(ConditionToken::Word(word)) if cursor.kind ==
      ConditionKind::SingleBracket &&
      word_plain_text(word) == Some("-o") => true
    _ => false
  }
}

///|
fn consume_condition_logical(
  cursor : ConditionCursor,
  fallback : Position,
) -> Position {
  let pos = condition_token_position(cursor.peek(), fallback)
  ignore(cursor.advance())
  pos
}

///|
fn parse_condition_primary(
  cursor : ConditionCursor,
  fallback : Position,
) -> ConditionExpr raise ParseError {
  match cursor.peek() {
    Some(ConditionToken::Word(word)) if cursor.kind ==
      ConditionKind::SingleBracket &&
      is_single_bracket_group_open_word(word) => {
      ignore(cursor.advance())
      match cursor.peek() {
        Some(ConditionToken::RParen) =>
          raise ParseError::Message(
            pos=word.span.start,
            message="empty grouped condition expression",
          )
        Some(ConditionToken::Word(close)) if is_single_bracket_group_close_word(
            close,
          ) =>
          raise ParseError::Message(
            pos=word.span.start,
            message="empty grouped condition expression",
          )
        _ => ()
      }
      let inner = parse_condition_or_expr(cursor, word.span.start)
      match cursor.peek() {
        Some(ConditionToken::RParen) => ignore(cursor.advance())
        Some(ConditionToken::Word(close)) if is_single_bracket_group_close_word(
            close,
          ) => ignore(cursor.advance())
        _ =>
          raise ParseError::Message(
            pos=condition_token_position(cursor.peek(), fallback),
            message="unexpected tokens inside grouped condition expression",
          )
      }
      return ConditionExpr::Group(inner)
    }
    Some(ConditionToken::LParen) => {
      ignore(cursor.advance())
      match cursor.peek() {
        Some(ConditionToken::RParen) =>
          raise ParseError::Message(
            pos=fallback,
            message="empty grouped condition expression",
          )
        _ => ()
      }
      let inner = parse_condition_or_expr(cursor, fallback)
      match cursor.peek() {
        Some(ConditionToken::RParen) => ignore(cursor.advance())
        _ =>
          raise ParseError::Message(
            pos=condition_token_position(cursor.peek(), fallback),
            message="unexpected tokens inside grouped condition expression",
          )
      }
      return ConditionExpr::Group(inner)
    }
    _ => ()
  }
  let word = match parse_condition_word_token(cursor) {
    Some(word) => word
    None =>
      raise ParseError::Message(
        pos=fallback,
        message="expected condition expression",
      )
  }
  match word_plain_text(word) {
    Some(op) =>
      if is_unary_condition_operator(op) ||
        is_condition_operator_like_unknown_unary(op) {
        match parse_condition_word_token(cursor) {
          Some(operand) => ConditionExpr::Unary(op, word.span, operand)
          None =>
            raise ParseError::Message(
              pos=fallback,
              message=condition_internal_message("1019"),
            )
        }
      } else {
        ConditionExpr::Word(word)
      }
    _ => ConditionExpr::Word(word)
  }
}

///|
fn parse_condition_comparison(
  cursor : ConditionCursor,
  fallback : Position,
) -> ConditionExpr raise ParseError {
  let left = parse_condition_primary(cursor, fallback)
  match left {
    ConditionExpr::Word(word) =>
      match cursor.peek() {
        Some(ConditionToken::Word(op_word)) =>
          match word_literal_text(op_word) {
            Some(op) =>
              if is_binary_condition_operator(op) ||
                is_condition_operator_like_unknown_binary(op) {
                ignore(cursor.advance())
                match parse_condition_word_token(cursor) {
                  Some(right) =>
                    ConditionExpr::Binary(op, op_word.span, word, right)
                  None =>
                    raise ParseError::Message(
                      pos=op_word.span.start,
                      message=condition_internal_message("1027"),
                    )
                }
              } else {
                left
              }
            _ => left
          }
        _ => left
      }
    _ => left
  }
}

///|
fn parse_condition_negation(
  cursor : ConditionCursor,
  fallback : Position,
) -> ConditionExpr raise ParseError {
  match cursor.peek() {
    Some(ConditionToken::Word(word)) if word_plain_text(word) == Some("!") => {
      ignore(cursor.advance())
      ConditionExpr::Not(parse_condition_comparison(cursor, word.span.start))
    }
    _ => parse_condition_comparison(cursor, fallback)
  }
}

///|
fn parse_condition_and_expr(
  cursor : ConditionCursor,
  fallback : Position,
) -> ConditionExpr raise ParseError {
  let mut expr = parse_condition_negation(cursor, fallback)
  while next_condition_is_logical_and(cursor) {
    let op_pos = consume_condition_logical(cursor, fallback)
    let right = parse_condition_negation(cursor, op_pos)
    expr = ConditionExpr::And(expr, right)
  }
  expr
}

///|
fn parse_condition_or_expr(
  cursor : ConditionCursor,
  fallback : Position,
) -> ConditionExpr raise ParseError {
  let mut expr = parse_condition_and_expr(cursor, fallback)
  while next_condition_is_logical_or(cursor) {
    let op_pos = consume_condition_logical(cursor, fallback)
    let right = parse_condition_and_expr(cursor, op_pos)
    expr = ConditionExpr::Or(expr, right)
  }
  expr
}

///|
fn parse_condition_expression_from_tokens(
  tokens : Array[ConditionToken],
  kind : ConditionKind,
  fallback : Position,
) -> (ConditionExpr, Int) raise ParseError {
  if tokens.length() == 0 {
    return (ConditionExpr::Empty, 0)
  }
  let cursor = { tokens, kind, index: 0 }
  let expr = parse_condition_or_expr(cursor, fallback)
  (expr, cursor.index)
}

///|
fn Parser::emit_condition_parse_failure(
  self : Parser,
  start : Position,
  specifics : Array[Diagnostic],
  end_pos : Position,
  end_message : String,
) -> Unit raise ParseError {
  self.emit_diagnostic(
    DiagnosticSeverity::Error,
    start,
    "Couldn't parse this test expression. Fix to allow more checks.",
    Some(1073),
  )
  for diagnostic in specifics {
    self.diagnostics.push(diagnostic)
  }
  self.emit_diagnostic(
    DiagnosticSeverity::Error,
    end_pos,
    end_message,
    Some(1072),
  )
  raise ParseError::Message(pos=end_pos, message=end_message)
}

///|
fn Parser::rethrow_condition_parse_error(
  self : Parser,
  start : Position,
  err : ParseError,
) -> Unit raise ParseError {
  match err {
    ParseError::Message(pos~, message~) => {
      if is_condition_internal_message(message, "1019") {
        self.emit_condition_parse_failure(
          start,
          [
            condition_specific_diagnostic(
              DiagnosticSeverity::Error,
              pos,
              1019,
              "Expected this to be an argument to the unary condition.",
            ),
          ],
          self.position(),
          "Unexpected . Fix any mentioned problems and try again.",
        )
      }
      if is_condition_internal_message(message, "1020") {
        self.emit_condition_parse_failure(
          start,
          [
            condition_specific_diagnostic(
              DiagnosticSeverity::Error,
              pos,
              1020,
              "You need a space before the ].",
            ),
          ],
          pos,
          "Missing space before ]. Fix any mentioned problems and try again.",
        )
      }
      if is_condition_internal_message(message, "1021") {
        self.emit_condition_parse_failure(
          start,
          [
            condition_specific_diagnostic(
              DiagnosticSeverity::Error,
              pos,
              1021,
              "You need a space before the \\)",
            ),
          ],
          pos,
          "Missing space before ). Fix any mentioned problems and try again.",
        )
      }
      if is_condition_internal_message(message, "1026") {
        self.emit_condition_parse_failure(
          start,
          [],
          pos,
          "Expected test to end here (don't wrap commands in []/[[]]). Fix any mentioned problems and try again.",
        )
      }
      if is_condition_internal_message(message, "1027") {
        self.emit_condition_parse_failure(
          start,
          [
            condition_specific_diagnostic(
              DiagnosticSeverity::Error,
              pos,
              1027,
              "Expected another argument for this operator.",
            ),
          ],
          self.position(),
          "Unexpected . Fix any mentioned problems and try again.",
        )
      }
      raise err
    }
    _ => raise err
  }
}

///|
fn Parser::handle_condition_trailing_tokens(
  self : Parser,
  start : Position,
  kind : ConditionKind,
  expr : ConditionExpr,
  next_token : ConditionToken?,
  fallback : Position,
) -> Unit raise ParseError {
  let diagnostics : Array[Diagnostic] = []
  let end_pos = condition_token_position(next_token, fallback)
  match expr {
    ConditionExpr::Word(word) => {
      match word_plain_text(word) {
        Some(name) if is_common_condition_command(name) =>
          diagnostics.push(
            condition_specific_diagnostic(
              DiagnosticSeverity::Warning,
              word.span.start,
              1014,
              "Use 'if cmd; then ..' to check exit code, or 'if [[ $(cmd) == .. ]]' to check output.",
            ),
          )
        _ => ()
      }
      match word_literal_text(word) {
        Some(text) => {
          if kind == ConditionKind::SingleBracket && text == "[" {
            diagnostics.push(
              condition_specific_diagnostic(
                DiagnosticSeverity::Error,
                word.span.start,
                1026,
                "If grouping expressions inside [..], use \\( ..\\).",
              ),
            )
          }
          match trailing_condition_operator(text) {
            Some(op) =>
              diagnostics.push(
                condition_specific_diagnostic(
                  DiagnosticSeverity::Error,
                  word.span.start,
                  1108,
                  "You need a space before and after the \{op} .",
                ),
              )
            None => ()
          }
        }
        None => ()
      }
    }
    _ => ()
  }
  match condition_token_word_text(next_token) {
    Some(text) if is_condition_arithmetic_operator(text) =>
      diagnostics.push(
        condition_specific_diagnostic(
          DiagnosticSeverity::Error,
          end_pos,
          1076,
          if kind == ConditionKind::SingleBracket {
            "Trying to do math? Use e.g. [ $((i/2+7)) -ge 18 ]."
          } else {
            "Trying to do math? Use e.g. [[ $((i/2+7)) -ge 18 ]]."
          },
        ),
      )
    _ => ()
  }
  if diagnostics.length() != 0 {
    self.emit_condition_parse_failure(
      start, diagnostics, end_pos, "Expected test to end here (don't wrap commands in []/[[]]). Fix any mentioned problems and try again.",
    )
  }
  raise ParseError::Message(
    pos=end_pos,
    message="unexpected tokens after condition expression",
  )
}

///|
fn Parser::parse_condition_command(
  self : Parser,
  double_bracket : Bool,
) -> ConditionCommand raise ParseError {
  let (opening, closing, kind, context) = if double_bracket {
    ("[[", "]]", ConditionKind::DoubleBracket, "double-bracket condition")
  } else {
    ("[", "]", ConditionKind::SingleBracket, "single-bracket condition")
  }
  let start = self.position()
  self.advance_n(opening.length())
  let fallback = self.position()
  let (raw, tokens, actual_closing, closing_pos) = self.read_condition_tokens(
    double_bracket, context,
  ) catch {
    err => {
      self.rethrow_condition_parse_error(start, err)
      raise err
    }
  }
  self.advance_n(actual_closing.length())
  let (expr, next_index) = parse_condition_expression_from_tokens(
    tokens, kind, closing_pos,
  ) catch {
    err => {
      self.rethrow_condition_parse_error(start, err)
      raise err
    }
  }
  if actual_closing != closing {
    match kind {
      ConditionKind::DoubleBracket =>
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          closing_pos,
          "Test expression was opened with double [[ but closed with single ]. Make sure they match.",
          Some(1033),
        )
      ConditionKind::SingleBracket =>
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          start,
          "Test expression was opened with single [ but closed with double ]]. Make sure they match.",
          Some(1034),
        )
    }
  }
  if next_index != tokens.length() {
    self.handle_condition_trailing_tokens(
      start,
      kind,
      expr,
      Some(tokens[next_index]),
      fallback,
    )
  }
  { kind, raw, expr }
}

///|
fn Parser::parse_arithmetic_command(
  self : Parser,
) -> ArithmeticCommand raise ParseError {
  self.advance_n(2)
  let raw = trim_ascii_space(self.read_arithmetic_expansion())
  self.advance_n(2)
  { raw, expr: parse_arithmetic_expr(raw) }
}

///|
fn Parser::is_at_case_item_end(self : Parser) -> Bool {
  self.starts_with(";;&") ||
  self.starts_with(";&") ||
  self.starts_with(";;") ||
  self.starts_keyword_token("esac")
}

///|
fn Parser::parse_case_terminator(self : Parser) -> Terminator? {
  self.skip_inline_space()
  if self.is_at_case_item_end() {
    return None
  }
  self.parse_terminator()
}

///|
fn Parser::parse_case_list_item(
  self : Parser,
  annotations : Array[Annotation],
) -> ListItem raise ParseError {
  let start = self.position()
  let and_or = self.parse_and_or()
  let terminator = self.parse_case_terminator()
  { span: make_span(start, self.position()), annotations, and_or, terminator }
}

///|
fn Parser::parse_case_item_body(self : Parser) -> Script raise ParseError {
  let start = self.position()
  let items : Array[ListItem] = []
  let mut pending_annotations = self.skip_list_gaps()
  while !self.eof() &&
        !self.is_at_case_item_end() &&
        !self.current_case_line_looks_like_pattern() {
    items.push(self.parse_case_list_item(pending_annotations))
    pending_annotations = self.skip_list_gaps()
  }
  {
    span: make_span(start, self.position()),
    has_bom: false,
    shebang: None,
    annotations: [],
    items,
  }
}

///|
fn Parser::skip_case_item_gaps(self : Parser) -> Array[Position] {
  let annotation_positions : Array[Position] = []
  while true {
    while self.peek() == Some(' ') || self.peek() == Some('\t') {
      ignore(self.advance_one())
    }
    if self.consume_newline() {
      if self.pending_heredocs.length() > 0 {
        self.read_pending_heredocs()
      }
      continue
    }
    if self.peek() == Some('#') {
      let comment_pos = self.position()
      let (line, _) = self.read_line()
      if is_shellcheck_annotation_comment(line) {
        annotation_positions.push(comment_pos)
      }
      continue
    }
    break
  }
  annotation_positions
}

///|
fn Parser::emit_case_item_context_diagnostics(
  self : Parser,
  case_pos : Position,
  annotation_positions : Array[Position],
) -> Unit {
  if annotation_positions.length() == 0 {
    return
  }
  let item_pos = annotation_positions[0]
  self.emit_diagnostic(
    DiagnosticSeverity::Info,
    case_pos,
    "The mentioned syntax error was in this case expression.",
    Some(1009),
  )
  self.emit_diagnostic(
    DiagnosticSeverity::Error,
    item_pos,
    "Couldn't parse this case item. Fix to allow more checks.",
    Some(1073),
  )
  for annotation_pos in annotation_positions {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      annotation_pos,
      "ShellCheck directives are only valid in front of complete commands like 'case' statements, not individual case branches.",
      Some(1124),
    )
  }
  let expected_pos = advance_position_columns(item_pos, 2)
  self.emit_diagnostic(
    DiagnosticSeverity::Error,
    expected_pos,
    "Expected ) to open a new case item. Fix any mentioned problems and try again.",
    Some(1072),
  )
  self.emit_diagnostic(
    DiagnosticSeverity::Error,
    expected_pos,
    "Did you forget to move the ;; after extending this case item?",
    Some(1085),
  )
}

///|
fn Parser::current_case_line_looks_like_pattern(self : Parser) -> Bool {
  let parser = Parser::new(
    self.source.view(start_offset=self.offset),
    self.options,
    [],
  )
  while parser.peek() == Some(' ') || parser.peek() == Some('\t') {
    ignore(parser.advance_one())
  }
  if parser.peek() == Some('(') {
    ignore(parser.advance_one())
    parser.skip_inline_space()
  }
  try {
    ignore(parser.parse_word_with_terminators(["esac"]))
    parser.skip_inline_space()
    while parser.peek() == Some('|') {
      ignore(parser.advance_one())
      parser.skip_inline_space()
      ignore(parser.parse_word_with_terminators(["esac"]))
      parser.skip_inline_space()
    }
    parser.peek() == Some(')')
  } catch {
    _ => false
  }
}

///|
fn Parser::parse_case_separator(
  self : Parser,
) -> CaseSeparator raise ParseError {
  if self.starts_with(";;&") {
    self.advance_n(3)
    return CaseSeparator::Continue
  }
  if self.starts_with(";&") {
    self.advance_n(2)
    return CaseSeparator::FallThrough
  }
  if self.starts_with(";;") {
    self.advance_n(2)
    return CaseSeparator::Break
  }
  if self.starts_keyword_token("esac") {
    return CaseSeparator::Break
  }
  if self.current_case_line_looks_like_pattern() {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      self.position(),
      "Did you forget the ;; after the previous case item?",
      Some(1074),
    )
    return CaseSeparator::Break
  }
  raise self.unexpected("case item terminator")
}

///|
fn Parser::parse_case_clause(self : Parser) -> CaseClause raise ParseError {
  let case_pos = self.position()
  self.expect_keyword("case")
  self.skip_command_gaps()
  let word = self.parse_word()
  self.skip_command_gaps()
  self.expect_keyword("in")
  let items : Array[CaseItem] = []
  let mut invalid_annotation_positions = self.skip_case_item_gaps()
  while !self.eof() {
    if self.eat_keyword("esac") {
      return { word, items }
    }
    self.emit_case_item_context_diagnostics(
      case_pos, invalid_annotation_positions,
    )
    if self.peek() == Some('(') {
      ignore(self.advance_one())
      self.skip_inline_space()
    }
    let patterns : Array[Word] = [self.parse_word_with_terminators(["esac"])]
    self.skip_inline_space()
    while self.peek() == Some('|') {
      ignore(self.advance_one())
      self.skip_inline_space()
      patterns.push(self.parse_word_with_terminators(["esac"]))
      self.skip_inline_space()
    }
    if self.peek() != Some(')') {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        self.position(),
        "Did you forget to move the ;; after extending this case item?",
        Some(1085),
      )
      raise self.unexpected(")")
    }
    ignore(self.advance_one())
    self.skip_command_gaps()
    let body = self.parse_case_item_body()
    let separator = self.parse_case_separator()
    items.push({ patterns, body, separator })
    invalid_annotation_positions = self.skip_case_item_gaps()
  }
  raise self.unexpected_end("case clause")
}

///|
fn Parser::parse_coproc_clause(self : Parser) -> CoProcClause raise ParseError {
  self.expect_keyword("coproc")
  self.skip_command_gaps()
  let mut name : Word? = None
  let mark = self.mark()
  let diagnostics_len = self.diagnostics.length()
  if self.next_starts_word() {
    let candidate = self.parse_word()
    self.skip_command_gaps()
    if self.next_starts_coproc_name_target() {
      name = Some(candidate)
    } else {
      self.reset(mark)
      self.diagnostics.truncate(diagnostics_len)
    }
  }
  let body = self.parse_command()
  { name, body }
}

///|
fn Parser::parse_simple_command(self : Parser) -> Command raise ParseError {
  let start = self.position()
  let saved_context = self.simple_command_context
  self.simple_command_context = Some(start)
  let assignments : Array[Assignment] = []
  let words : Array[Word] = []
  let redirects : Array[Redirection] = []
  let mut saw_word = false
  try {
    while true {
      if saw_word {
        match self.peek_comment_after_inline_space() {
          Some((comment_pos, line)) if is_shellcheck_annotation_comment(line) =>
            self.emit_diagnostic(
              DiagnosticSeverity::Error,
              comment_pos,
              "Place shellcheck directives before commands, not after.",
              Some(1126),
            )
          _ => ()
        }
      }
      self.skip_inline_space()
      if self.next_starts_redirection() {
        redirects.push(
          self.parse_redirection(
            redirects,
            Some(start),
            Some("The mentioned syntax error was in this simple command."),
          ),
        )
        continue
      }
      if !saw_word || simple_command_accepts_suffix_assignments(words) {
        match self.try_parse_assignment() {
          Some(assignment) => {
            assignments.push(assignment)
            continue
          }
          None => ()
        }
      }
      if self.next_starts_word() {
        if saw_word {
          words.push(self.parse_word())
        } else {
          words.push(self.parse_command_name_word())
        }
        saw_word = true
        continue
      }
      break
    }
    if assignments.length() == 0 &&
      words.length() == 0 &&
      redirects.length() == 0 {
      raise self.unexpected("command")
    }
    self.validate_simple_command(assignments, words)
    let kind = classify_simple_command(assignments, words)
    self.simple_command_context = saved_context
    { span: make_span(start, self.position()), kind, redirects }
  } catch {
    err => {
      self.simple_command_context = saved_context
      raise err
    }
  }
}

///|
fn is_alias_suppressed_command_char(ch : UInt16) -> Bool {
  is_name_part(ch) || ch == ':' || ch == '.'
}

///|
fn Parser::parse_command_name_word(self : Parser) -> Word raise ParseError {
  if self.peek() == Some('\\') {
    match self.peek_n(1) {
      Some(ch) if is_alias_suppressed_command_char(ch) =>
        ignore(self.advance_one())
      _ => ()
    }
  }
  self.parse_word()
}

///|
fn word_plain_text(word : Word) -> String? {
  if word.parts.length() != 1 {
    return None
  }
  match word.parts[0] {
    WordPart::Literal(text) => Some(text)
    _ => None
  }
}

///|
fn append_literal_word_parts_text(
  parts : Array[WordPart],
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
fn append_literal_word_part_text(part : WordPart, buf : StringBuilder) -> Bool {
  match part {
    WordPart::Literal(text)
    | WordPart::SingleQuoted(text)
    | WordPart::DollarSingleQuoted(text) => {
      buf.write_string(text)
      true
    }
    WordPart::DoubleQuoted(parts) | WordPart::DollarDoubleQuoted(parts) =>
      append_literal_word_parts_text(parts, buf)
    _ => false
  }
}

///|
fn word_literal_text(word : Word) -> String? {
  let buf = StringBuilder::new()
  if !append_literal_word_parts_text(word.parts, buf) {
    return None
  }
  Some(buf.to_string())
}

///|
fn word_trailing_unquoted_literal(word : Word) -> String? {
  if word.parts.length() == 0 {
    return None
  }
  match word.parts[word.parts.length() - 1] {
    WordPart::Literal(text) => Some(text)
    _ => None
  }
}

///|
fn word_contains_unquoted_literal_fragment(
  word : Word,
  fragment : String,
) -> Bool {
  for part in word.parts {
    match part {
      WordPart::Literal(text) if text.contains(fragment) => return true
      _ => ()
    }
  }
  false
}

///|
fn word_is_literal_array_index(word : Word) -> Bool {
  if word.parts.length() < 2 {
    return false
  }
  match word.parts[1] {
    WordPart::Literal(text) => text == "["
    _ => false
  }
}

///|
fn word_starts_comment_glob(word : Word) -> Bool {
  word.source.has_prefix("/*")
}

///|
fn Parser::validate_trap_handler(self : Parser, word : Word) -> Unit {
  match word_literal_text(word) {
    Some(text) if !text.has_prefix("-") => {
      let report = parse_script_report(text)
      let mut saw_error = false
      for diagnostic in report.diagnostics {
        let translated = {
          ..diagnostic,
          span: translate_span(word.span.start, diagnostic.span),
        }
        match diagnostic.severity {
          DiagnosticSeverity::Error => {
            saw_error = true
            self.diagnostics.push(translated)
          }
          _ => self.diagnostics.push(translated)
        }
      }
      if !saw_error && report.script is None {
        self.diagnostics.push({
          span: word.span,
          severity: DiagnosticSeverity::Error,
          code: None,
          message: "trap handler could not be parsed",
        })
      }
    }
    _ => ()
  }
}

///|
fn strip_matching_outer_quotes(text : String) -> String {
  if text.length() >= 2 &&
    (
      (text[0] == '"' && text[text.length() - 1] == '"') ||
      (text[0] == '\'' && text[text.length() - 1] == '\'')
    ) {
    text.view(start_offset=1, end_offset=text.length() - 1).to_string()
  } else {
    text
  }
}

///|
fn arithmetic_legacy_comparison(text : String) -> (String, String)? {
  let view = text[:]
  let mut i = 0
  while i + 3 <= view.length() {
    if view[i] == '-' {
      let alt = if text.view(start_offset=i).has_prefix("-lt") {
        Some("<")
      } else if text.view(start_offset=i).has_prefix("-gt") {
        Some(">")
      } else if text.view(start_offset=i).has_prefix("-le") {
        Some("<=")
      } else if text.view(start_offset=i).has_prefix("-ge") {
        Some(">=")
      } else if text.view(start_offset=i).has_prefix("-eq") {
        Some("==")
      } else if text.view(start_offset=i).has_prefix("-ne") {
        Some("!=")
      } else {
        None
      }
      match alt {
        Some(op) => {
          let end_ = i + 3
          let before_ok = i == 0 || !is_name_part(view[i - 1])
          let after_ok = end_ < view.length() &&
            (
              view[end_] == ' ' ||
              view[end_] == '\t' ||
              view[end_] == '\n' ||
              view[end_] == '\r'
            )
          if before_ok && after_ok {
            return Some(
              (text.view(start_offset=i, end_offset=end_).to_string(), op),
            )
          }
        }
        None => ()
      }
    }
    i += 1
  }
  None
}

///|
fn Parser::validate_let_words(self : Parser, words : Array[Word]) -> Unit {
  let mut i = 1
  while i < words.length() {
    let raw = strip_matching_outer_quotes(words[i].source)
    match arithmetic_legacy_comparison(raw) {
      Some((legacy, alt)) =>
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          words[i].span.start,
          "In arithmetic contexts, use \{alt} instead of \{legacy}",
          Some(1106),
        )
      None => ()
    }
    i += 1
  }
}

///|
fn assignment_value_is_empty(value : AssignmentValue) -> Bool {
  match value {
    AssignmentValue::Empty => true
    _ => false
  }
}

///|
fn assignment_value_starts_with_equals(value : AssignmentValue) -> Bool {
  match value {
    AssignmentValue::Word(word) => word.source.has_prefix("=")
    _ => false
  }
}

///|
fn word_is_dollar_assignment_lhs(word : Word) -> Bool {
  let source = word.source
  if source.length() < 3 || source[0] != '$' {
    return false
  }
  let parser = Parser::new(
    source.view(start_offset=1),
    ParseOptions::default(),
    [],
  )
  if parser.parse_bare_identifier() is None {
    return false
  }
  while parser.peek() == Some('[') {
    if (parser.read_assignment_index() catch { _ => None }) is None {
      return false
    }
  }
  let mut i = 1 + parser.offset
  if source.view(start_offset=i).has_prefix("+=") {
    i += 2
  } else if i < source.length() && source[i] == '=' {
    i += 1
  } else {
    return false
  }
  i == source.length()
}

///|
fn assignment_like_word_start(
  words : Array[Word],
  assignments_len : Int,
) -> Int {
  if words.length() == 0 {
    return 0
  }
  match word_plain_text(words[0]) {
    Some(name) if is_modifier_command_name(name) => 1
    Some("builtin") if words.length() > 1 =>
      match word_plain_text(words[1]) {
        Some(name) if is_modifier_command_name(name) => 2
        _ => if assignments_len == 0 { 0 } else { words.length() }
      }
    _ => if assignments_len == 0 { 0 } else { words.length() }
  }
}

///|
fn Parser::validate_assignments(
  self : Parser,
  assignments : Array[Assignment],
  words : Array[Word],
) -> Unit {
  for assignment in assignments {
    if assignment.name != "IFS" &&
      assignment_value_is_empty(assignment.value) &&
      words.length() > 0 {
      self.emit_diagnostic(
        DiagnosticSeverity::Warning,
        assignment.span.end,
        "Remove space after = if trying to assign a value (for empty string, use var='' ... ).",
        Some(1007),
      )
    }
    if assignment_value_starts_with_equals(assignment.value) {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        assignment.span.end,
        "Unexpected ==. For assignment, use =. For comparison, use [/[[. Or quote for literal string.",
        Some(1097),
      )
    }
  }
  let start = assignment_like_word_start(words, assignments.length())
  let mut i = start
  while i < words.length() {
    if self.peek() == Some('(') && word_is_dollar_assignment_lhs(words[i]) {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        words[i].span.start,
        "Don't use $ on the left side of assignments.",
        Some(1066),
      )
    }
    i += 1
  }
}

///|
fn keyword_spacing_diagnostic(name : String) -> (Int, String)? {
  if name.length() > 2 &&
    lower_ascii_string(name.view(end_offset=2).to_string()) == "if" &&
    name[2] == '[' {
    return Some((1069, "You need a space before the [."))
  }
  if name.length() > 4 &&
    lower_ascii_string(name.view(end_offset=4).to_string()) == "then" &&
    name[4] == '#' {
    return Some((1099, "You need a space before the #."))
  }
  if name.length() > 4 &&
    lower_ascii_string(name.view(end_offset=4).to_string()) == "else" &&
    name[4] == '!' {
    return Some((1129, "You need a space before the !."))
  }
  if name.length() > 2 &&
    lower_ascii_string(name.view(end_offset=2).to_string()) == "do" &&
    name[2] == ':' {
    return Some((1130, "You need a space before the :."))
  }
  None
}

///|
fn keyword_case_diagnostic(name : String) -> String? {
  for
    keyword in [
      "if", "then", "else", "elif", "fi", "do", "done", "case", "esac", "while",
      "until", "for", "select", "in",
    ] {
    if lower_ascii_string(name) == keyword && name != keyword {
      return Some(keyword)
    }
  }
  None
}

///|
fn Parser::validate_simple_command(
  self : Parser,
  assignments : Array[Assignment],
  words : Array[Word],
) -> Unit {
  self.validate_assignments(assignments, words)
  if words.length() == 0 {
    return
  }
  let command_source = words[0].source
  let command_name_source = lower_ascii_alpha_prefix(command_source)
  match keyword_spacing_diagnostic(command_source) {
    Some((code, message)) =>
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        words[0].span.start,
        message,
        Some(code),
      )
    None => ()
  }
  match keyword_case_diagnostic(command_source) {
    Some(keyword) =>
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        words[0].span.start,
        "Scripts are case sensitive. Use '\{keyword}', not '\{command_source}' (or quote if literal).",
        Some(1081),
      )
    None => ()
  }
  match word_plain_text(words[0]) {
    Some("//") =>
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        words[0].span.start,
        "Was this intended as a comment? Use # in sh.",
        Some(1127),
      )
    Some(name) => {
      if name == "trap" && words.length() > 1 {
        self.validate_trap_handler(words[1])
      }
      if name == "let" {
        self.validate_let_words(words)
      }
      if name == "eval" && self.peek() == Some('(') {
        self.emit_diagnostic(
          DiagnosticSeverity::Warning,
          self.position(),
          "Quote/escape special characters when using eval, e.g. eval \"a=(b)\".",
          Some(1098),
        )
      }
      if (name == "command" || name == "builtin") &&
        words.length() > 1 &&
        word_plain_text(words[1]) == Some("eval") &&
        self.peek() == Some('(') {
        self.emit_diagnostic(
          DiagnosticSeverity::Warning,
          self.position(),
          "Quote/escape special characters when using eval, e.g. eval \"a=(b)\".",
          Some(1098),
        )
      }
    }
    None =>
      if word_starts_comment_glob(words[0]) {
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          words[0].span.start,
          "Was this intended as a comment? Use # in sh.",
          Some(1127),
        )
      }
  }
  if command_name_source == "elsif" || command_name_source == "elseif" {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      words[0].span.start,
      "Use 'elif' to start another branch.",
      Some(1131),
    )
  }
}

///|
fn is_modifier_command_name(name : String) -> Bool {
  match name {
    "declare" | "export" | "local" | "readonly" | "typeset" => true
    _ => false
  }
}

///|
fn simple_command_accepts_suffix_assignments(words : Array[Word]) -> Bool {
  if words.length() == 0 {
    return false
  }
  match word_plain_text(words[0]) {
    Some(name) if is_modifier_command_name(name) => true
    Some("builtin") if words.length() > 1 =>
      match word_plain_text(words[1]) {
        Some(name) if is_modifier_command_name(name) => true
        _ => false
      }
    _ => false
  }
}

///|
fn classify_simple_command(
  assignments : Array[Assignment],
  words : Array[Word],
) -> CommandKind {
  match parse_source_command(assignments, words) {
    Some(source) => return CommandKind::Source(source)
    None => ()
  }
  CommandKind::Simple({ assignments, words })
}

///|
fn parse_source_command(
  assignments : Array[Assignment],
  words : Array[Word],
) -> SourceCommand? {
  if words.length() < 2 {
    return None
  }
  let keyword = match word_plain_text(words[0]) {
    Some(keyword) if keyword == "." || keyword == "source" => keyword
    _ => return None
  }
  let options : Array[Word] = []
  let mut path_index = 1
  match word_literal_text(words[1]) {
    Some("-p") => {
      options.push(words[1])
      if words.length() < 4 {
        return None
      }
      options.push(words[2])
      path_index = 3
    }
    Some("--") => {
      options.push(words[1])
      path_index = 2
    }
    _ => ()
  }
  if path_index >= words.length() {
    return None
  }
  let args : Array[Word] = []
  let mut i = path_index + 1
  while i < words.length() {
    args.push(words[i])
    i += 1
  }
  Some({
    assignments,
    keyword,
    options,
    path: words[path_index],
    args,
    resolved_path: None,
    included: None,
  })
}

///|
fn Parser::parse_trailing_redirections(
  self : Parser,
) -> Array[Redirection] raise ParseError {
  let redirects : Array[Redirection] = []
  while true {
    self.skip_inline_space()
    if !self.next_starts_redirection() {
      break
    }
    redirects.push(self.parse_redirection(redirects, None, None))
  }
  redirects
}

///|
fn Parser::next_starts_word(self : Parser) -> Bool {
  if self.starts_with("<(") || self.starts_with(">(") {
    return true
  }
  if self.starts_brace_expansion() {
    return true
  }
  match self.peek() {
    None => false
    Some(ch) => !is_word_boundary(Some(ch))
  }
}

///|
fn redirect_operator_len_at(source : StringView, start : Int) -> Int {
  if start >= source.length() {
    return 0
  }
  let view = source.view(start_offset=start)
  if view.has_prefix("<(") || view.has_prefix(">(") {
    return 0
  }
  if view.has_prefix("&>>") {
    return 3
  }
  if view.has_prefix("&>") {
    return 2
  }
  if view.has_prefix("<<<") || view.has_prefix("<<-") {
    return 3
  }
  if view.has_prefix(">>") ||
    view.has_prefix("<<") ||
    view.has_prefix("<&") ||
    view.has_prefix(">&") ||
    view.has_prefix("<>") ||
    view.has_prefix(">|") {
    return 2
  }
  if view.has_prefix("<") || view.has_prefix(">") {
    return 1
  }
  0
}

///|
fn Parser::next_starts_redirection(self : Parser) -> Bool {
  let direct = redirect_operator_len_at(self.source, self.offset)
  if direct > 0 {
    return true
  }
  let mut i = self.offset
  while i < self.source.length() && is_digit(self.source[i]) {
    i += 1
  }
  if i > self.offset && redirect_operator_len_at(self.source, i) > 0 {
    return true
  }
  if self.peek() == Some('{') {
    let mut j = self.offset + 1
    if j < self.source.length() && is_name_start(self.source[j]) {
      j += 1
      while j < self.source.length() && is_name_part(self.source[j]) {
        j += 1
      }
      return j < self.source.length() &&
        self.source[j] == '}' &&
        redirect_operator_len_at(self.source, j + 1) > 0
    }
  }
  false
}

///|
fn Parser::parse_redirection(
  self : Parser,
  redirects : Array[Redirection],
  owner_context_pos : Position?,
  owner_context_message : String?,
) -> Redirection raise ParseError {
  let start = self.position()
  let source = self.parse_optional_redirection_source()
  let (op, op_len) = self.parse_redirection_operator()
  self.advance_n(op_len)
  let gap_start = self.offset
  self.skip_inline_space()
  let index = redirects.length()
  match op {
    RedirectionOperator::HereDoc | RedirectionOperator::HereDocStrip => {
      if self.offset != gap_start && self.peek() == Some('(') {
        let spacing = self.source
          .view(start_offset=gap_start, end_offset=self.offset)
          .to_string()
        self.emit_simple_command_context_diagnostic()
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          start,
          "Shells are space sensitive. Use '< <(cmd)', not '<<\{spacing}(cmd)'.",
          Some(1038),
        )
        let end_message = " Fix any mentioned problems and try again."
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          start,
          "Couldn't parse this here document. Fix to allow more checks.",
          Some(1073),
        )
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          self.position(),
          end_message,
          Some(1072),
        )
        raise ParseError::Message(pos=self.position(), message=end_message)
      }
      let delimiter_pos = self.position()
      let diagnostics_len = self.diagnostics.length()
      let word = self.parse_word()
      self.diagnostics.truncate(diagnostics_len)
      let gap_start = self.offset
      let gap_mark = self.mark()
      self.skip_inline_space()
      if self.offset != gap_start && self.peek() == Some('\r') {
        raise ParseError::Message(
          pos=self.position(),
          message="unexpected carriage return after here-document delimiter",
        )
      }
      self.reset(gap_mark)
      let delimiter = quote_removed_source(word.source)
      let quoted = word.source.contains("\"") ||
        word.source.contains("'") ||
        word.source.contains("\\")
      let strip_tabs = op == RedirectionOperator::HereDocStrip
      let redirection = {
        span: make_span(start, self.position()),
        source,
        op,
        target: RedirectionTarget::HereDoc({
          delimiter,
          quoted,
          strip_tabs,
          body: "",
          parts: None,
        }),
      }
      self.pending_heredocs.push({
        redirections: redirects,
        index,
        delimiter,
        quoted,
        strip_tabs,
        annotations: copy_annotations(self.current_annotations),
        owner_context_pos,
        owner_context_message,
        redirection_pos: start,
        delimiter_pos,
      })
      redirection
    }
    _ => {
      let target = self.parse_word()
      {
        span: make_span(start, self.position()),
        source,
        op,
        target: RedirectionTarget::Word(target),
      }
    }
  }
}

///|
fn Parser::parse_optional_redirection_source(
  self : Parser,
) -> RedirectionSource? {
  if self.starts_with("&>>") || self.starts_with("&>") {
    ignore(self.advance_one())
    return Some(RedirectionSource::All)
  }
  if self.peek() == Some('{') {
    let mark = self.mark()
    ignore(self.advance_one())
    let name = match self.parse_bare_identifier() {
      Some(name) => name
      None => {
        self.reset(mark)
        return None
      }
    }
    if self.peek() != Some('}') ||
      redirect_operator_len_at(self.source, self.offset + 1) == 0 {
      self.reset(mark)
      return None
    }
    ignore(self.advance_one())
    return Some(RedirectionSource::Named(name))
  }
  let start = self.offset
  let mut i = self.offset
  while i < self.source.length() && is_digit(self.source[i]) {
    i += 1
  }
  if i == start || redirect_operator_len_at(self.source, i) == 0 {
    return None
  }
  let digits = self.source.view(start_offset=start, end_offset=i).to_string()
  self.offset = i
  self.column += i - start
  Some(RedirectionSource::Fd(digits_to_int(digits)))
}

///|
fn Parser::parse_redirection_operator(
  self : Parser,
) -> (RedirectionOperator, Int) raise ParseError {
  let view = self.source.view(start_offset=self.offset)
  if view.has_prefix("&>>") {
    return (RedirectionOperator::Append, 3)
  }
  if view.has_prefix("&>") {
    return (RedirectionOperator::Write, 2)
  }
  if view.has_prefix("<<<") {
    return (RedirectionOperator::HereString, 3)
  }
  if view.has_prefix("<<-") {
    return (RedirectionOperator::HereDocStrip, 3)
  }
  if view.has_prefix("<<") {
    return (RedirectionOperator::HereDoc, 2)
  }
  if view.has_prefix(">>") {
    return (RedirectionOperator::Append, 2)
  }
  if view.has_prefix("<>") {
    return (RedirectionOperator::ReadWrite, 2)
  }
  if view.has_prefix(">|") {
    return (RedirectionOperator::Clobber, 2)
  }
  if view.has_prefix("<&") {
    return (RedirectionOperator::DupInput, 2)
  }
  if view.has_prefix(">&") {
    return (RedirectionOperator::DupOutput, 2)
  }
  if view.has_prefix("<") {
    return (RedirectionOperator::Read, 1)
  }
  if view.has_prefix(">") {
    return (RedirectionOperator::Write, 1)
  }
  raise self.unexpected("redirection operator")
}

///|
fn Parser::parse_assignment_operator(self : Parser) -> Bool? {
  if self.starts_with("+=") {
    self.advance_n(2)
    return Some(true)
  }
  if self.peek() == Some('=') {
    ignore(self.advance_one())
    return Some(false)
  }
  None
}

///|
fn Parser::parse_assignment_value(
  self : Parser,
  allow_empty : Bool,
) -> AssignmentValue raise ParseError {
  if self.peek() == Some('(') {
    return AssignmentValue::ArrayLiteral(self.read_assignment_array_literal())
  }
  if self.next_starts_word() {
    return AssignmentValue::Word(self.parse_word())
  }
  if allow_empty {
    return AssignmentValue::Empty
  }
  raise self.unexpected("assignment value")
}

///|
fn Parser::try_parse_assignment(self : Parser) -> Assignment? raise ParseError {
  let mark = self.mark()
  let start = self.position()
  let name = match self.parse_bare_identifier() {
    Some(name) => name
    None => return None
  }
  let indexes : Array[ArrayIndex] = []
  while self.peek() == Some('[') {
    try {
      match self.read_assignment_index() {
        Some(index) => indexes.push(index)
        None => {
          self.reset(mark)
          return None
        }
      }
    } catch {
      _ => {
        self.reset(mark)
        return None
      }
    }
  }
  let append = match self.parse_assignment_operator() {
    Some(append) => append
    None => {
      self.reset(mark)
      return None
    }
  }
  let value = self.parse_assignment_value(true)
  Some({ span: make_span(start, self.position()), name, indexes, append, value })
}

///|
fn Parser::parse_function_name_token(
  self : Parser,
  uses_keyword : Bool,
) -> String? {
  let start = self.offset
  match self.peek() {
    None => None
    Some(ch) if !is_function_name_start_char(ch, uses_keyword) => None
    Some(_) => {
      while self.peek() is Some(ch) {
        if !is_function_name_part_char(ch, uses_keyword) {
          break
        }
        ignore(self.advance_one())
      }
      let name = self.current_slice(start)
      if name == "" {
        None
      } else {
        Some(name)
      }
    }
  }
}

///|
fn Parser::parse_identifier_token(
  self : Parser,
  context : String,
) -> String raise ParseError {
  match self.parse_bare_identifier() {
    Some(name) => name
    None =>
      raise ParseError::Message(
        pos=self.position(),
        message="expected \{context}",
      )
  }
}

///|
fn Parser::parse_bare_identifier(self : Parser) -> String? {
  let start = self.offset
  match self.peek() {
    Some(ch) if is_name_start(ch) => {
      ignore(self.advance_one())
      while self.peek() is Some(next) && is_name_part(next) {
        ignore(self.advance_one())
      }
      Some(self.current_slice(start))
    }
    _ => None
  }
}

///|
fn Parser::skip_backquoted_text(
  self : Parser,
  context : String,
) -> Unit raise ParseError {
  while self.peek() is Some(ch) {
    if is_backquote_char(ch) {
      if ch == '´' {
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          self.position(),
          "For command expansion, the tick should slant left (` vs ´). Use $(..) instead.",
          Some(1077),
        )
      }
      ignore(self.advance_one())
      return
    }
    if ch == '\\' {
      ignore(self.advance_one())
      match self.peek() {
        Some(_) => ignore(self.advance_one())
        None => raise self.unexpected_end(context)
      }
      continue
    }
    ignore(self.advance_one())
  }
  raise self.unexpected_end(context)
}

///|
fn Parser::skip_shell_nested_segment(
  self : Parser,
  context : String,
) -> Bool raise ParseError {
  if self.starts_with("$((") {
    self.advance_n(3)
    ignore(self.read_arithmetic_expansion())
    self.advance_n(2)
    return true
  }
  if self.starts_with("$(") {
    self.advance_n(1)
    ignore(self.read_balanced_paren_content(context))
    return true
  }
  if self.starts_with("${") {
    self.advance_n(2)
    ignore(self.read_braced_parameter())
    return true
  }
  if self.starts_with("$[") {
    self.advance_n(2)
    ignore(self.read_dollar_bracket_content(context))
    return true
  }
  if self.starts_with("<(") || self.starts_with(">(") {
    ignore(self.advance_one())
    ignore(self.read_balanced_paren_content(context))
    return true
  }
  match self.peek() {
    Some('\'') => {
      let quote_start = self.position()
      ignore(self.advance_one())
      ignore(self.read_until_single_quote(quote_start))
      true
    }
    Some('"') => {
      ignore(self.advance_one())
      ignore(self.read_until_matching_quote('"'))
      if self.peek() != Some('"') {
        raise self.unexpected_end(context)
      }
      ignore(self.advance_one())
      true
    }
    Some(ch) if is_backquote_char(ch) => {
      self.consume_backquote_start()
      self.skip_backquoted_text(context)
      true
    }
    _ => false
  }
}

///|
fn Parser::starts_brace_expansion(self : Parser) -> Bool {
  if self.peek() != Some('{') {
    return false
  }
  let mark = self.mark()
  let diagnostics_len = self.diagnostics.length()
  let result = try {
    ignore(self.read_brace_expansion())
    true
  } catch {
    _ => false
  }
  self.reset(mark)
  self.diagnostics.truncate(diagnostics_len)
  result
}

///|
fn Parser::read_brace_expansion(
  self : Parser,
) -> BraceExpansion raise ParseError {
  if self.peek() != Some('{') {
    raise self.unexpected("brace expansion")
  }
  let start_pos = self.position()
  let start = self.offset
  let mut depth = 0
  let mut saw_separator = false
  while self.peek() is Some(ch) {
    if self.skip_shell_nested_segment("brace expansion") {
      continue
    }
    if depth == 1 && (ch == ',' || (ch == '.' && self.peek_n(1) == Some('.'))) {
      saw_separator = true
    }
    if ch == '\\' {
      self.advance_n(2)
      continue
    }
    ignore(self.advance_one())
    if ch == '{' {
      depth += 1
    } else if ch == '}' {
      depth -= 1
      if depth == 0 {
        let raw = self.current_slice(start)
        if !saw_separator {
          raise ParseError::Message(
            pos=start_pos,
            message="expected brace expansion",
          )
        }
        return parse_brace_expansion(raw)
      }
    }
  }
  raise self.unexpected_end("brace expansion")
}

///|
fn Parser::read_assignment_index(self : Parser) -> ArrayIndex? raise ParseError {
  if self.peek() != Some('[') {
    return None
  }
  let start = self.offset
  let mut depth = 0
  ignore(self.advance_one())
  while self.peek() is Some(ch) {
    if self.skip_shell_nested_segment("array index") {
      continue
    }
    if ch == '\\' {
      self.advance_n(2)
      continue
    }
    ignore(self.advance_one())
    if ch == '[' {
      depth += 1
      continue
    }
    if ch == ']' {
      if depth == 0 {
        let raw = self.source
          .view(start_offset=start + 1, end_offset=self.offset - 1)
          .to_string()
        return Some(parse_array_index(raw))
      }
      depth -= 1
      continue
    }
  }
  raise self.unexpected_end("array index")
}

///|
fn Parser::read_balanced_paren_content(
  self : Parser,
  context : String,
) -> String raise ParseError {
  if self.peek() != Some('(') {
    raise self.unexpected("(")
  }
  let start = self.offset
  let mut depth = 0
  while self.peek() is Some(ch) {
    if self.skip_shell_nested_segment(context) {
      continue
    }
    if ch == '\\' {
      self.advance_n(2)
      continue
    }
    ignore(self.advance_one())
    if ch == '(' {
      depth += 1
    } else if ch == ')' {
      depth -= 1
      if depth == 0 {
        return self.current_slice(start)
      }
    }
  }
  raise self.unexpected_end(context)
}

///|
fn Parser::read_array_element(self : Parser) -> ArrayElement raise ParseError {
  let mark = self.mark()
  let indexes : Array[ArrayIndex] = []
  while self.peek() == Some('[') {
    try {
      match self.read_assignment_index() {
        Some(index) => indexes.push(index)
        None => break
      }
    } catch {
      _ => {
        self.reset(mark)
        return {
          indexes: [],
          append: false,
          value: self.parse_assignment_value(false),
        }
      }
    }
  }
  let append = if indexes.length() == 0 {
    false
  } else {
    match self.parse_assignment_operator() {
      Some(append) => append
      None => {
        self.reset(mark)
        return {
          indexes: [],
          append: false,
          value: self.parse_assignment_value(false),
        }
      }
    }
  }
  let value = self.parse_assignment_value(indexes.length() > 0)
  { indexes, append, value }
}

///|
fn Parser::read_assignment_array_literal(
  self : Parser,
) -> Array[ArrayElement] raise ParseError {
  if self.peek() != Some('(') {
    raise self.unexpected("(")
  }
  let opening = self.position()
  ignore(self.advance_one())
  if self.peek() == Some('(') {
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      opening,
      "Missing $ on a $((..)) expression? (or use ( ( for arrays).",
      Some(1116),
    )
  }
  let elements : Array[ArrayElement] = []
  self.skip_command_gaps()
  while self.peek() != Some(')') {
    if self.eof() {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        self.position(),
        "expected ')' to end array literal",
        None,
      )
      return elements
    }
    elements.push(self.read_array_element())
    self.skip_command_gaps()
  }
  ignore(self.advance_one())
  elements
}

///|
fn is_parameter_reference_start(ch : UInt16) -> Bool {
  is_name_start(ch) || is_digit(ch) || is_special_parameter_char(ch)
}

///|
fn find_unescaped_char(text : String, separator : UInt16) -> Int? {
  let parser = Parser::new(text.view(), ParseOptions::default(), [])
  let mut bracket_depth = 0
  while parser.peek() is Some(ch) {
    let nested = parser.skip_shell_nested_segment("parameter operator") catch {
      _ => false
    }
    if nested {
      continue
    }
    if ch == '\\' {
      parser.advance_n(2)
      continue
    }
    if ch == '[' {
      bracket_depth += 1
    } else if ch == ']' && bracket_depth > 0 {
      bracket_depth -= 1
    } else if ch == separator && bracket_depth == 0 {
      return Some(parser.offset)
    }
    ignore(parser.advance_one())
  }
  None
}

///|
fn split_unescaped_once(text : String, separator : UInt16) -> (String, String)? {
  match find_unescaped_char(text, separator) {
    None => None
    Some(index) =>
      Some(
        (
          text.view(end_offset=index).to_string(),
          text.view(start_offset=index + 1).to_string(),
        ),
      )
  }
}

///|
fn read_parameter_index(raw : String, start : Int) -> (String, Int)? {
  if start >= raw.length() || raw[start] != '[' {
    return None
  }
  let parser = Parser::new(
    raw.view(start_offset=start),
    ParseOptions::default(),
    [],
  )
  try {
    match parser.read_assignment_index() {
      Some(index) => Some((index.raw, start + parser.offset))
      None => None
    }
  } catch {
    _ => None
  }
}

///|
fn parse_parameter_reference(
  raw : String,
  start : Int,
) -> (String?, ArrayIndex?, Int) {
  let view = raw[:]
  if start >= view.length() {
    return (None, None, start)
  }
  let mut i = start
  if is_name_start(view[i]) {
    i += 1
    while i < view.length() && is_name_part(view[i]) {
      i += 1
    }
  } else if is_digit(view[i]) || is_special_parameter_char(view[i]) {
    i += 1
  } else {
    return (None, None, start)
  }
  let name = raw.view(start_offset=start, end_offset=i).to_string()
  match read_parameter_index(raw, i) {
    Some((index, end_)) => (Some(name), Some(parse_array_index(index)), end_)
    None => (Some(name), None, i)
  }
}

///|
fn parse_parameter_operator(text : String) -> ParameterOperator? {
  if text == "" {
    return None
  }
  if text.has_prefix(":-") {
    return Some(
      ParameterOperator::DefaultValue(text.view(start_offset=2).to_string()),
    )
  }
  if text.has_prefix(":=") {
    return Some(
      ParameterOperator::AssignDefault(text.view(start_offset=2).to_string()),
    )
  }
  if text.has_prefix(":?") {
    return Some(
      ParameterOperator::ErrorValue(text.view(start_offset=2).to_string()),
    )
  }
  if text.has_prefix(":+") {
    return Some(
      ParameterOperator::AlternateValue(text.view(start_offset=2).to_string()),
    )
  }
  if text.has_prefix(":") {
    let rest = text.view(start_offset=1).to_string()
    match split_unescaped_once(rest, ':') {
      None => return Some(ParameterOperator::Slice(rest, None))
      Some((offset, length)) =>
        return Some(ParameterOperator::Slice(offset, Some(length)))
    }
  }
  if text.has_prefix("##") {
    return Some(
      ParameterOperator::RemoveLongestPrefix(
        text.view(start_offset=2).to_string(),
      ),
    )
  }
  if text.has_prefix("#") {
    return Some(
      ParameterOperator::RemoveShortestPrefix(
        text.view(start_offset=1).to_string(),
      ),
    )
  }
  if text.has_prefix("%%") {
    return Some(
      ParameterOperator::RemoveLongestSuffix(
        text.view(start_offset=2).to_string(),
      ),
    )
  }
  if text.has_prefix("%") {
    return Some(
      ParameterOperator::RemoveShortestSuffix(
        text.view(start_offset=1).to_string(),
      ),
    )
  }
  if text.has_prefix("/") {
    let (mode, offset) = if text.has_prefix("//") {
      (ParameterReplaceMode::All, 2)
    } else if text.has_prefix("/#") {
      (ParameterReplaceMode::Prefix, 2)
    } else if text.has_prefix("/%") {
      (ParameterReplaceMode::Suffix, 2)
    } else {
      (ParameterReplaceMode::First, 1)
    }
    let rest = text.view(start_offset=offset).to_string()
    match split_unescaped_once(rest, '/') {
      None => return Some(ParameterOperator::Replace(mode, rest, None))
      Some((pattern, replacement)) =>
        return Some(
          ParameterOperator::Replace(mode, pattern, Some(replacement)),
        )
    }
  }
  if text.has_prefix("@") {
    return Some(
      ParameterOperator::Transform(text.view(start_offset=1).to_string()),
    )
  }
  let (case_mode, offset) = if text.has_prefix("^^") {
    (Some(ParameterCaseMode::UpperAll), 2)
  } else if text.has_prefix("^") {
    (Some(ParameterCaseMode::UpperFirst), 1)
  } else if text.has_prefix(",,") {
    (Some(ParameterCaseMode::LowerAll), 2)
  } else if text.has_prefix(",") {
    (Some(ParameterCaseMode::LowerFirst), 1)
  } else if text.has_prefix("~~") {
    (Some(ParameterCaseMode::ToggleAll), 2)
  } else if text.has_prefix("~") {
    (Some(ParameterCaseMode::ToggleFirst), 1)
  } else {
    (None, 0)
  }
  match case_mode {
    Some(mode) => {
      let pattern = text.view(start_offset=offset).to_string()
      return Some(
        ParameterOperator::CaseModify(
          mode,
          if pattern == "" {
            None
          } else {
            Some(pattern)
          },
        ),
      )
    }
    None => ()
  }
  Some(ParameterOperator::Raw(text))
}

///|
fn parse_parameter_expansion(raw : String) -> ParameterExpansion {
  let view = raw[:]
  let mut i = 0
  let mut length_prefix = false
  let mut indirect = false
  if i < view.length() &&
    view[i] == '#' &&
    i + 1 < view.length() &&
    is_parameter_reference_start(view[i + 1]) {
    length_prefix = true
    i += 1
  }
  if i < view.length() && view[i] == '!' {
    indirect = true
    i += 1
  }
  let (name, index, next) = parse_parameter_reference(raw, i)
  let operator = if next < view.length() {
    parse_parameter_operator(raw.view(start_offset=next).to_string())
  } else {
    None
  }
  let operator = match operator {
    Some(ParameterOperator::Transform(kind)) if indirect && kind == "" =>
      Some(ParameterOperator::Names(ParameterNamesMode::At))
    Some(ParameterOperator::Raw("*")) if indirect =>
      Some(ParameterOperator::Names(ParameterNamesMode::Star))
    _ => operator
  }
  { raw, length_prefix, indirect, name, index, operator }
}

///|
fn parse_text_parts(text : String) -> Array[WordPart] {
  let parser = Parser::new(text.view(), ParseOptions::default(), [])
  parser.parse_text_parts_until_eof() catch {
    _ => [WordPart::Literal(text)]
  }
}

///|
/// Parses a string as a single shell word fragment.
pub fn parse_text_as_word(text : String) -> Word {
  let parser = Parser::new(text.view(), ParseOptions::default(), [])
  try {
    let parts = parser.parse_text_parts_until_eof()
    {
      span: { start: { offset: 0, line: 1, column: 1 }, end: parser.position() },
      source: text,
      parts,
    }
  } catch {
    _ =>
      {
        span: {
          start: { offset: 0, line: 1, column: 1 },
          end: { offset: text.length(), line: 1, column: text.length() + 1 },
        },
        source: text,
        parts: if text == "" {
          []
        } else {
          [WordPart::Literal(text)]
        },
      }
  }
}

///|
fn parse_arithmetic_index(raw : String) -> ArrayIndex {
  {
    raw,
    parts: parse_text_parts(raw),
    arithmetic: Some(parse_arithmetic_expr(raw)),
  }
}

///|
fn parse_array_index(raw : String) -> ArrayIndex {
  { raw, parts: parse_text_parts(raw), arithmetic: None }
}

///|
fn push_arithmetic_literal(
  tokens : Array[ArithmeticToken],
  literal : StringBuilder,
) -> Unit {
  let text = literal.to_string()
  if text != "" {
    tokens.push(ArithmeticToken::Literal(text))
    literal.reset()
  }
}

///|
fn arithmetic_literal_end(raw : String, start : Int) -> Int {
  let view = raw[:]
  let mut i = start
  while i < view.length() {
    let ch = view[i]
    if is_digit(ch) || is_name_start(ch) || (i > start && ch == '#') {
      i += 1
      continue
    }
    break
  }
  i
}

///|
fn make_fragment_word(
  source : String,
  end_ : Position,
  parts : Array[WordPart],
) -> Word {
  {
    span: { start: { offset: 0, line: 1, column: 1 }, end: end_ },
    source,
    parts,
  }
}

///|
fn read_arithmetic_fragment(raw : String, start : Int) -> (Word, Int)? {
  let source = raw.view(start_offset=start).to_string()
  let parser = Parser::new(source.view(), ParseOptions::default(), [])
  try {
    match parser.peek() {
      Some('\'') => {
        let quote_start = parser.position()
        ignore(parser.advance_one())
        let text = parser.read_until_single_quote(quote_start)
        let end_ = parser.position()
        let fragment = source.view(end_offset=parser.offset).to_string()
        Some(
          (
            make_fragment_word(fragment, end_, [WordPart::SingleQuoted(text)]),
            start + parser.offset,
          ),
        )
      }
      Some('"') => {
        let quote_start = parser.position()
        ignore(parser.advance_one())
        let parts = parser.read_double_quoted_parts(quote_start)
        let end_ = parser.position()
        let fragment = source.view(end_offset=parser.offset).to_string()
        Some(
          (
            make_fragment_word(fragment, end_, [WordPart::DoubleQuoted(parts)]),
            start + parser.offset,
          ),
        )
      }
      Some(ch) if is_backquote_char(ch) => {
        let quote_start = parser.position()
        parser.consume_backquote_start()
        let script = parser.read_backquoted_script(false, quote_start)
        let end_ = parser.position()
        let fragment = source.view(end_offset=parser.offset).to_string()
        Some(
          (
            make_fragment_word(fragment, end_, [WordPart::BackQuoted(script)]),
            start + parser.offset,
          ),
        )
      }
      Some('$') =>
        match parser.parse_dollar_part() {
          Some(part) => {
            let end_ = parser.position()
            let fragment = source.view(end_offset=parser.offset).to_string()
            Some(
              (
                make_fragment_word(fragment, end_, [part]),
                start + parser.offset,
              ),
            )
          }
          None => None
        }
      Some('\\') => {
        ignore(parser.advance_one())
        match parser.peek() {
          Some(next) => {
            ignore(parser.advance_one())
            let end_ = parser.position()
            let fragment = source.view(end_offset=parser.offset).to_string()
            Some(
              (
                make_fragment_word(fragment, end_, [single_char_literal(next)]),
                start + parser.offset,
              ),
            )
          }
          None => None
        }
      }
      _ => None
    }
  } catch {
    _ => None
  }
}

///|
fn split_top_level_shell_text(
  text : String,
  separator : UInt16,
) -> Array[String] {
  let parts : Array[String] = []
  let view = text[:]
  let mut start = 0
  let mut i = 0
  let mut brace_depth = 0
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut quote : UInt16? = None
  while i < view.length() {
    let ch = view[i]
    match quote {
      Some(current_quote) => {
        if ch == '\\' &&
          (current_quote == '"' || is_backquote_char(current_quote)) &&
          i + 1 < view.length() {
          i += 2
          continue
        }
        if (is_backquote_char(current_quote) && is_backquote_char(ch)) ||
          ch == current_quote {
          quote = None
        }
      }
      None => {
        if ch == '\\' {
          i += 2
          continue
        }
        if ch == '\'' || ch == '"' || is_backquote_char(ch) {
          quote = Some(ch)
        } else if ch == '{' {
          brace_depth += 1
        } else if ch == '}' && brace_depth > 0 {
          brace_depth -= 1
        } else if ch == '(' {
          paren_depth += 1
        } else if ch == ')' && paren_depth > 0 {
          paren_depth -= 1
        } else if ch == '[' {
          bracket_depth += 1
        } else if ch == ']' && bracket_depth > 0 {
          bracket_depth -= 1
        } else if ch == separator &&
          brace_depth == 0 &&
          paren_depth == 0 &&
          bracket_depth == 0 {
          parts.push(text.view(start_offset=start, end_offset=i).to_string())
          start = i + 1
        }
      }
    }
    i += 1
  }
  parts.push(text.view(start_offset=start).to_string())
  parts
}

///|
fn parse_extglob_pattern(raw : String) -> ExtGlobPattern {
  let inner = if raw.length() >= 3 {
    raw.view(start_offset=2, end_offset=raw.length() - 1).to_string()
  } else {
    ""
  }
  let alternatives = split_top_level_shell_text(inner, '|').map(
    parse_text_as_word,
  )
  {
    raw,
    operator: if raw.length() > 0 {
      raw.view(end_offset=1).to_string()
    } else {
      ""
    },
    alternatives,
  }
}

///|
fn parse_brace_expansion(raw : String) -> BraceExpansion {
  let inner = if raw.length() >= 2 {
    raw.view(start_offset=1, end_offset=raw.length() - 1).to_string()
  } else {
    ""
  }
  {
    raw,
    elements: split_top_level_shell_text(inner, ',').map(parse_text_as_word),
  }
}

///|
fn arithmetic_operator_len_at(source : StringView, start : Int) -> Int {
  if start >= source.length() {
    return 0
  }
  let view = source.view(start_offset=start)
  for
    op in [
      ">>=", "<<=", "**", "++", "--", "&&", "||", "<<", ">>", "<=", ">=", "==", "!=",
      "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "?", ":", ",", "+", "-", "*",
      "/", "%", "&", "|", "^", "~", "!", "<", ">", "=",
    ] {
    if view.has_prefix(op) {
      return op.length()
    }
  }
  0
}

///|
fn read_balanced_paren_segment(raw : String, start : Int) -> (String, Int)? {
  let view = raw[:]
  if start >= view.length() || view[start] != '(' {
    return None
  }
  let parser = Parser::new(
    raw.view(start_offset=start),
    ParseOptions::default(),
    [],
  )
  ignore(parser.advance_one())
  let mut depth = 1
  while parser.peek() is Some(ch) {
    let nested = parser.skip_shell_nested_segment("arithmetic group") catch {
      _ => false
    }
    if nested {
      continue
    }
    if ch == '\\' {
      parser.advance_n(2)
      continue
    }
    if ch == '(' {
      depth += 1
    } else if ch == ')' {
      depth -= 1
      if depth == 0 {
        let end_ = start + parser.offset
        ignore(parser.advance_one())
        return Some(
          (
            raw.view(start_offset=start + 1, end_offset=end_).to_string(),
            start + parser.offset,
          ),
        )
      }
    }
    ignore(parser.advance_one())
  }
  None
}

///|
/// Parses shell arithmetic source into an `ArithmeticExpr`.
pub fn parse_arithmetic_expr(raw : String) -> ArithmeticExpr {
  let tokens : Array[ArithmeticToken] = []
  let literal = StringBuilder::new()
  let view = raw[:]
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch == '\\' && i + 1 < view.length() && view[i + 1] == '\n' {
      push_arithmetic_literal(tokens, literal)
      i += 2
      continue
    }
    if ch == '\\' &&
      i + 2 < view.length() &&
      view[i + 1] == '\r' &&
      view[i + 2] == '\n' {
      push_arithmetic_literal(tokens, literal)
      i += 3
      continue
    }
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      push_arithmetic_literal(tokens, literal)
      i += 1
      continue
    }
    let op_len = arithmetic_operator_len_at(raw[:], i)
    if op_len > 0 {
      push_arithmetic_literal(tokens, literal)
      tokens.push(
        ArithmeticToken::Operator(
          raw.view(start_offset=i, end_offset=i + op_len).to_string(),
        ),
      )
      i += op_len
      continue
    }
    if ch == '(' {
      push_arithmetic_literal(tokens, literal)
      match read_balanced_paren_segment(raw, i) {
        Some((inner, end_)) => {
          tokens.push(ArithmeticToken::Group(parse_arithmetic_expr(inner)))
          i = end_
          continue
        }
        None => ()
      }
    }
    if is_digit(ch) {
      push_arithmetic_literal(tokens, literal)
      let end_ = arithmetic_literal_end(raw, i)
      tokens.push(
        ArithmeticToken::Literal(
          raw.view(start_offset=i, end_offset=end_).to_string(),
        ),
      )
      i = end_
      continue
    }
    if is_name_start(ch) {
      push_arithmetic_literal(tokens, literal)
      let start = i
      i += 1
      while i < view.length() && is_name_part(view[i]) {
        i += 1
      }
      let name_end = i
      let indexes : Array[ArrayIndex] = []
      while true {
        match read_parameter_index(raw, i) {
          Some((index, end_)) => {
            indexes.push(parse_arithmetic_index(index))
            i = end_
          }
          None => break
        }
      }
      tokens.push(
        ArithmeticToken::Variable(
          raw.view(start_offset=start, end_offset=name_end).to_string(),
          indexes,
        ),
      )
      continue
    }
    match read_arithmetic_fragment(raw, i) {
      Some((word, end_)) => {
        push_arithmetic_literal(tokens, literal)
        tokens.push(ArithmeticToken::Expansion(word))
        i = end_
        continue
      }
      None => ()
    }
    literal.write_char(ch.unsafe_to_char())
    i += 1
  }
  push_arithmetic_literal(tokens, literal)
  { raw, tokens }
}

///|
fn ArithmeticCursor::peek(self : ArithmeticCursor) -> ArithmeticToken? {
  if self.index >= self.tokens.length() {
    None
  } else {
    Some(self.tokens[self.index])
  }
}

///|
fn ArithmeticCursor::advance(self : ArithmeticCursor) -> ArithmeticToken? {
  if self.index >= self.tokens.length() {
    None
  } else {
    let token = self.tokens[self.index]
    self.index += 1
    Some(token)
  }
}

///|
fn arithmetic_operator_token_text(token : ArithmeticToken?) -> String? {
  match token {
    Some(ArithmeticToken::Operator(op)) => Some(op)
    _ => None
  }
}

///|
fn arithmetic_cursor_consume_operator(
  cursor : ArithmeticCursor,
  op : String,
) -> Bool {
  match arithmetic_operator_token_text(cursor.peek()) {
    Some(text) if text == op => {
      ignore(cursor.advance())
      true
    }
    _ => false
  }
}

///|
fn arithmetic_cursor_consume_any_operator(
  cursor : ArithmeticCursor,
  ops : Array[String],
) -> String? {
  match arithmetic_operator_token_text(cursor.peek()) {
    Some(text) => {
      for op in ops {
        if text == op {
          ignore(cursor.advance())
          return Some(text)
        }
      }
      None
    }
    None => None
  }
}

///|
fn validate_arithmetic_primary_expression(cursor : ArithmeticCursor) -> Bool {
  while arithmetic_cursor_consume_any_operator(cursor, [
          "+", "-", "!", "~", "++", "--",
        ])
        is Some(_) {

  }
  let base_ok = match cursor.advance() {
    Some(ArithmeticToken::Literal(_))
    | Some(ArithmeticToken::Variable(_, _))
    | Some(ArithmeticToken::Expansion(_)) => true
    Some(ArithmeticToken::Group(expr)) => validate_arithmetic_expr(expr)
    _ => false
  }
  if !base_ok {
    return false
  }
  while arithmetic_cursor_consume_any_operator(cursor, ["++", "--"]) is Some(_) {

  }
  true
}

///|
fn validate_arithmetic_power_expression(cursor : ArithmeticCursor) -> Bool {
  if !validate_arithmetic_primary_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_operator(cursor, "**") {
    if !validate_arithmetic_primary_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_multiplicative_expression(
  cursor : ArithmeticCursor,
) -> Bool {
  if !validate_arithmetic_power_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_any_operator(cursor, ["*", "/", "%"])
        is Some(_) {
    if !validate_arithmetic_power_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_additive_expression(cursor : ArithmeticCursor) -> Bool {
  if !validate_arithmetic_multiplicative_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_any_operator(cursor, ["+", "-"]) is Some(_) {
    if !validate_arithmetic_multiplicative_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_shift_expression(cursor : ArithmeticCursor) -> Bool {
  if !validate_arithmetic_additive_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_any_operator(cursor, ["<<", ">>"]) is Some(_) {
    if !validate_arithmetic_additive_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_relational_expression(cursor : ArithmeticCursor) -> Bool {
  if !validate_arithmetic_shift_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_any_operator(cursor, ["<", "<=", ">", ">="])
        is Some(_) {
    if !validate_arithmetic_shift_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_equality_expression(cursor : ArithmeticCursor) -> Bool {
  if !validate_arithmetic_relational_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_any_operator(cursor, ["==", "!="]) is Some(_) {
    if !validate_arithmetic_relational_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_bitwise_and_expression(
  cursor : ArithmeticCursor,
) -> Bool {
  if !validate_arithmetic_equality_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_operator(cursor, "&") {
    if !validate_arithmetic_equality_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_bitwise_xor_expression(
  cursor : ArithmeticCursor,
) -> Bool {
  if !validate_arithmetic_bitwise_and_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_operator(cursor, "^") {
    if !validate_arithmetic_bitwise_and_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_bitwise_or_expression(cursor : ArithmeticCursor) -> Bool {
  if !validate_arithmetic_bitwise_xor_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_operator(cursor, "|") {
    if !validate_arithmetic_bitwise_xor_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_logical_and_expression(
  cursor : ArithmeticCursor,
) -> Bool {
  if !validate_arithmetic_bitwise_or_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_operator(cursor, "&&") {
    if !validate_arithmetic_bitwise_or_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_logical_or_expression(cursor : ArithmeticCursor) -> Bool {
  if !validate_arithmetic_logical_and_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_operator(cursor, "||") {
    if !validate_arithmetic_logical_and_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_conditional_expression(
  cursor : ArithmeticCursor,
) -> Bool {
  if !validate_arithmetic_logical_or_expression(cursor) {
    return false
  }
  if arithmetic_cursor_consume_operator(cursor, "?") {
    if !validate_arithmetic_comma_expression(cursor) {
      return false
    }
    if !arithmetic_cursor_consume_operator(cursor, ":") {
      return false
    }
    if !validate_arithmetic_conditional_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_assignment_expression(cursor : ArithmeticCursor) -> Bool {
  if !validate_arithmetic_conditional_expression(cursor) {
    return false
  }
  match
    arithmetic_cursor_consume_any_operator(cursor, [
      "=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>=",
    ]) {
    Some(_) => validate_arithmetic_assignment_expression(cursor)
    None => true
  }
}

///|
fn validate_arithmetic_comma_expression(cursor : ArithmeticCursor) -> Bool {
  if !validate_arithmetic_assignment_expression(cursor) {
    return false
  }
  while arithmetic_cursor_consume_operator(cursor, ",") {
    if !validate_arithmetic_assignment_expression(cursor) {
      return false
    }
  }
  true
}

///|
fn validate_arithmetic_expr(expr : ArithmeticExpr) -> Bool {
  if expr.tokens.length() == 0 {
    return true
  }
  let cursor = { tokens: expr.tokens, index: 0 }
  validate_arithmetic_comma_expression(cursor) &&
  cursor.index == cursor.tokens.length()
}

///|
fn contains_unescaped_glob(text : String) -> Bool {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch == '\\' {
      i += 2
      continue
    }
    if ch == '*' || ch == '?' || ch == '[' {
      return true
    }
    i += 1
  }
  false
}

///|
fn classify_unquoted_literal(text : String) -> WordPart {
  if contains_unescaped_glob(text) {
    return WordPart::Glob(text)
  }
  WordPart::Literal(text)
}

///|
fn push_literal(parts : Array[WordPart], literal : StringBuilder) -> Unit {
  let text = literal.to_string()
  if text != "" {
    parts.push(WordPart::Literal(text))
    literal.reset()
  }
}

///|
fn push_word_literal(parts : Array[WordPart], literal : StringBuilder) -> Unit {
  let text = literal.to_string()
  if text != "" {
    parts.push(classify_unquoted_literal(text))
    literal.reset()
  }
}

///|
fn single_char_literal(ch : UInt16) -> WordPart {
  let buf = StringBuilder::new()
  buf.write_char(ch.unsafe_to_char())
  WordPart::Literal(buf.to_string())
}

///|
fn is_shellcheck_named_escape_target(ch : UInt16) -> Bool {
  ch == 'n' || ch == 't' || ch == 'r'
}

///|
fn shellcheck_named_escape_name(ch : UInt16) -> String {
  match ch {
    'n' => "line feed"
    't' => "tab"
    'r' => "carriage return"
    _ => ""
  }
}

///|
fn shellcheck_named_escape_alternative(ch : UInt16) -> String {
  match ch {
    'n' => "a quoted, literal line feed"
    't' => "\"$(printf '\\t')\""
    'r' => "\"$(printf '\\r')\""
    _ => ""
  }
}

///|
fn is_safe_unquoted_escape_target(ch : UInt16) -> Bool {
  is_unicode_space_char(ch) ||
  ch == '|' ||
  ch == '&' ||
  ch == ';' ||
  ch == '<' ||
  ch == '>' ||
  ch == '(' ||
  ch == ')' ||
  ch == '\\' ||
  ch == ' ' ||
  ch == '\t' ||
  ch == '\n' ||
  ch == '\r' ||
  ch == '"' ||
  ch == '\'' ||
  ch == '$' ||
  ch == '`' ||
  ch == '?' ||
  ch == '*' ||
  ch == '@' ||
  ch == '!' ||
  ch == '+' ||
  ch == '[' ||
  ch == ']' ||
  ch == '{' ||
  ch == '}' ||
  ch == '.' ||
  ch == ',' ||
  ch == '~' ||
  ch == '#'
}

///|
fn is_double_quote_escape_target(ch : UInt16) -> Bool {
  ch == '$' || ch == '`' || ch == '"' || ch == '\\'
}

///|
fn is_here_doc_escape_target(ch : UInt16) -> Bool {
  ch == '$' || ch == '`' || ch == '\\'
}

///|
fn Parser::has_only_line_whitespace_until_break(self : Parser) -> Bool {
  let mut next = 1
  while self.peek_n(next) is Some(ch) && (ch == ' ' || ch == '\t') {
    next += 1
  }
  match self.peek_n(next) {
    None | Some('\n') => true
    Some('\r') => self.peek_n(next + 1) == Some('\n')
    _ => false
  }
}

///|
fn Parser::append_unquoted_escape(
  self : Parser,
  parts : Array[WordPart],
  literal : StringBuilder,
  context : String,
) -> Unit raise ParseError {
  let backslash_pos = self.position()
  ignore(self.advance_one())
  match self.peek() {
    Some('\n') | Some('\r') => ignore(self.consume_newline())
    Some(next) => {
      if next == ' ' && self.has_only_line_whitespace_until_break() {
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          backslash_pos,
          "Delete trailing spaces after \\ to break line (or use quotes for literal space).",
          Some(1101),
        )
      } else if !is_safe_unquoted_escape_target(next) {
        if is_shellcheck_named_escape_target(next) {
          self.emit_diagnostic(
            DiagnosticSeverity::Warning,
            backslash_pos,
            "\\\{next.unsafe_to_char()} is just literal '\{next.unsafe_to_char()}' here. For \{shellcheck_named_escape_name(next)}, use \{shellcheck_named_escape_alternative(next)} instead.",
            Some(1012),
          )
        } else {
          self.emit_diagnostic(
            DiagnosticSeverity::Info,
            backslash_pos,
            "This \\\{next.unsafe_to_char()} will be a regular '\{next.unsafe_to_char()}' in this context.",
            Some(1001),
          )
        }
      }
      push_word_literal(parts, literal)
      parts.push(single_char_literal(next))
      ignore(self.advance_one())
    }
    None => raise self.unexpected_end(context)
  }
}

///|
fn Parser::append_double_quoted_escape(
  self : Parser,
  literal : StringBuilder,
  context : String,
) -> Unit raise ParseError {
  ignore(self.advance_one())
  match self.peek() {
    Some('\n') | Some('\r') => ignore(self.consume_newline())
    Some(next) => {
      ignore(self.advance_one())
      if is_double_quote_escape_target(next) {
        literal.write_char(next.unsafe_to_char())
      } else {
        literal.write_char('\\')
        literal.write_char(next.unsafe_to_char())
      }
    }
    None => raise self.unexpected_end(context)
  }
}

///|
fn Parser::append_here_doc_escape(
  self : Parser,
  literal : StringBuilder,
  context : String,
) -> Unit raise ParseError {
  ignore(self.advance_one())
  match self.peek() {
    Some('\n') | Some('\r') => ignore(self.consume_newline())
    Some(next) => {
      ignore(self.advance_one())
      if is_here_doc_escape_target(next) {
        literal.write_char(next.unsafe_to_char())
      } else {
        literal.write_char('\\')
        literal.write_char(next.unsafe_to_char())
      }
    }
    None => raise self.unexpected_end(context)
  }
}

///|
fn Parser::starts_extglob(self : Parser) -> Bool {
  match self.peek() {
    Some('@') | Some('*') | Some('+') | Some('?') | Some('!') =>
      self.peek_n(1) == Some('(')
    _ => false
  }
}

///|
fn parse_nested_script_text(
  source : String,
  options : ParseOptions,
  source_stack : Array[String],
) -> NestedScriptParseResult raise ParseError {
  let parser = Parser::new(source.view(), options, source_stack)
  let script = parser.parse_script([], None)
  parser.skip_command_gaps()
  parser.ensure_no_pending_heredocs()
  if !parser.eof() {
    raise ParseError::Message(
      pos=parser.position(),
      message="unexpected trailing input in nested script",
    )
  }
  let root = {
    span: { start: { offset: 0, line: 1, column: 1 }, end: script.span.end },
    has_bom: false,
    shebang: None,
    annotations: [],
    items: script.items,
  }
  {
    script: resolve_script_sources(
      root,
      [],
      options,
      source_stack,
      parser.diagnostics,
    ),
    diagnostics: parser.diagnostics,
  }
}

///|
fn Parser::read_backquoted_script(
  self : Parser,
  quoted : Bool,
  open_pos : Position,
) -> Script raise ParseError {
  let start = self.position()
  let body = StringBuilder::new()
  while self.peek() is Some(ch) {
    if is_backquote_char(ch) {
      if ch == '´' {
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          self.position(),
          "For command expansion, the tick should slant left (` vs ´). Use $(..) instead.",
          Some(1077),
        )
      }
      ignore(self.advance_one())
      let nested = parse_nested_script_text(
        unescape_backquoted_body(body.to_string(), quoted),
        self.options,
        self.source_stack,
      ) catch {
        err => raise translate_parse_error(start, err)
      }
      for diagnostic in nested.diagnostics {
        self.diagnostics.push({
          ..diagnostic,
          span: translate_span(start, diagnostic.span),
        })
      }
      let raw = body.to_string()
      if self.has_suspect_char_after_quotes() &&
        string_contains_linefeed(raw) &&
        !string_starts_with_linefeed(raw) {
        self.emit_suspect_quote_close_diagnostics(
          open_pos, "backtick expansion",
        )
      }
      return translate_script(start, nested.script)
    }
    if ch == '\\' {
      ignore(self.advance_one())
      body.write_char('\\')
      match self.peek() {
        Some(next) => {
          ignore(self.advance_one())
          body.write_char(next.unsafe_to_char())
        }
        None => raise self.unexpected_end("backquoted command substitution")
      }
      continue
    }
    ignore(self.advance_one())
    body.write_char(ch.unsafe_to_char())
  }
  self.emit_simple_command_context_diagnostic()
  let parse_message = "Couldn't parse this backtick expansion. Fix to allow more checks."
  self.emit_diagnostic(
    DiagnosticSeverity::Error,
    open_pos,
    parse_message,
    Some(1073),
  )
  let end_message = "Expected end of backtick expansion. Fix any mentioned problems and try again."
  self.emit_diagnostic(
    DiagnosticSeverity::Error,
    self.position(),
    end_message,
    Some(1072),
  )
  raise ParseError::Message(pos=self.position(), message=end_message)
}

///|
fn Parser::parse_process_substitution(
  self : Parser,
) -> WordPart raise ParseError {
  let kind = if self.peek() == Some('<') { "<" } else { ">" }
  self.advance_n(2)
  let script = self.resolve_nested_script(self.parse_script([], Some(')')))
  self.ensure_no_pending_heredocs()
  if self.peek() != Some(')') {
    raise self.unexpected(")")
  }
  ignore(self.advance_one())
  WordPart::ProcessSubstitution(kind, script)
}

///|
fn Parser::read_extglob(self : Parser) -> ExtGlobPattern raise ParseError {
  let start = self.offset
  ignore(self.advance_one())
  ignore(self.read_balanced_paren_content("extended glob"))
  let raw = self.current_slice(start)
  parse_extglob_pattern(raw)
}

///|
fn Parser::read_dollar_single_quoted(self : Parser) -> String raise ParseError {
  let content = StringBuilder::new()
  while self.peek() is Some(ch) {
    if ch == '\'' {
      ignore(self.advance_one())
      return content.to_string()
    }
    if ch == '\\' {
      ignore(self.advance_one())
      match self.peek() {
        Some(next) => {
          ignore(self.advance_one())
          content.write_char('\\')
          content.write_char(next.unsafe_to_char())
        }
        None => raise self.unexpected_end("dollar-single-quoted string")
      }
      continue
    }
    ignore(self.advance_one())
    content.write_char(ch.unsafe_to_char())
  }
  raise self.unexpected_end("dollar-single-quoted string")
}

///|
fn Parser::read_until_closing_char(
  self : Parser,
  closing : UInt16,
  context : String,
) -> String raise ParseError {
  let content = StringBuilder::new()
  while self.peek() is Some(ch) {
    if ch == closing {
      ignore(self.advance_one())
      return content.to_string()
    }
    if ch == '\\' {
      ignore(self.advance_one())
      match self.peek() {
        Some(next) => {
          ignore(self.advance_one())
          content.write_char('\\')
          content.write_char(next.unsafe_to_char())
        }
        None => raise self.unexpected_end(context)
      }
      continue
    }
    ignore(self.advance_one())
    content.write_char(ch.unsafe_to_char())
  }
  raise self.unexpected_end(context)
}

///|
fn Parser::read_dollar_bracket_content(
  self : Parser,
  context : String,
) -> String raise ParseError {
  let content = StringBuilder::new()
  let mut bracket_depth = 0
  while self.peek() is Some(ch) {
    let nested_start = self.offset
    if self.skip_shell_nested_segment(context) {
      content.write_string(
        self.source
        .view(start_offset=nested_start, end_offset=self.offset)
        .to_string(),
      )
      continue
    }
    if ch == '[' {
      bracket_depth += 1
      ignore(self.advance_one())
      content.write_char('[')
      continue
    }
    if ch == ']' {
      if bracket_depth == 0 {
        ignore(self.advance_one())
        return content.to_string()
      }
      bracket_depth -= 1
      ignore(self.advance_one())
      content.write_char(']')
      continue
    }
    if ch == '\\' {
      ignore(self.advance_one())
      match self.peek() {
        Some(next) => {
          ignore(self.advance_one())
          content.write_char('\\')
          content.write_char(next.unsafe_to_char())
        }
        None => raise self.unexpected_end(context)
      }
      continue
    }
    ignore(self.advance_one())
    content.write_char(ch.unsafe_to_char())
  }
  raise self.unexpected_end(context)
}

///|
fn Parser::read_brace_command_substitution(
  self : Parser,
  start : Position,
) -> WordPart raise ParseError {
  let mut piped = false
  if self.peek() == Some('|') {
    piped = true
    ignore(self.advance_one())
  }
  let script = self.resolve_nested_script(self.parse_script([], Some('}'))) catch {
    err => {
      let message = "Couldn't parse this ksh ${ ..; } command expansion. Fix to allow more checks."
      self.emit_simple_command_context_diagnostic()
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        start,
        message,
        Some(1073),
      )
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        parse_error_position(err),
        "Expected } to end the ksh ${ ..; } command expansion. Fix any mentioned problems and try again.",
        Some(1072),
      )
      raise ParseError::Message(pos=start, message~)
    }
  }
  self.ensure_no_pending_heredocs()
  if self.peek() != Some('}') {
    let message = "Couldn't parse this ksh ${ ..; } command expansion. Fix to allow more checks."
    self.emit_simple_command_context_diagnostic()
    self.emit_diagnostic(DiagnosticSeverity::Error, start, message, Some(1073))
    self.emit_diagnostic(
      DiagnosticSeverity::Error,
      self.position(),
      "Expected } to end the ksh ${ ..; } command expansion. Fix any mentioned problems and try again.",
      Some(1072),
    )
    raise ParseError::Message(pos=start, message~)
  }
  ignore(self.advance_one())
  WordPart::BraceCommandSubstitution(piped, script)
}

///|
fn Parser::parse_here_doc_parts(
  self : Parser,
) -> Array[WordPart] raise ParseError {
  let parts : Array[WordPart] = []
  let literal = StringBuilder::new()
  while self.peek() is Some(ch) {
    match ch {
      ch if is_backquote_char(ch) => {
        push_literal(parts, literal)
        let quote_start = self.position()
        self.consume_backquote_start()
        parts.push(
          WordPart::BackQuoted(self.read_backquoted_script(false, quote_start)),
        )
      }
      '$' =>
        match self.parse_dollar_part_internal(false) {
          Some(part) => {
            push_literal(parts, literal)
            parts.push(part)
          }
          None => {
            ignore(self.advance_one())
            literal.write_char('$')
          }
        }
      '\\' => self.append_here_doc_escape(literal, "escaped character")
      _ => {
        self.maybe_emit_unicode_quote(ch)
        ignore(self.advance_one())
        literal.write_char(ch.unsafe_to_char())
      }
    }
  }
  push_literal(parts, literal)
  parts
}

///|
fn Parser::parse_text_parts_until_eof(
  self : Parser,
) -> Array[WordPart] raise ParseError {
  let parts : Array[WordPart] = []
  let literal = StringBuilder::new()
  while self.peek() is Some(ch) {
    if self.starts_with("<(") || self.starts_with(">(") {
      push_word_literal(parts, literal)
      parts.push(self.parse_process_substitution())
      continue
    }
    if self.starts_extglob() {
      push_word_literal(parts, literal)
      parts.push(WordPart::ExtGlob(self.read_extglob()))
      continue
    }
    if self.starts_brace_expansion() {
      push_word_literal(parts, literal)
      parts.push(WordPart::BraceExpansion(self.read_brace_expansion()))
      continue
    }
    match ch {
      '\'' => {
        push_word_literal(parts, literal)
        let quote_start = self.position()
        ignore(self.advance_one())
        let text = self.read_until_single_quote(quote_start)
        parts.push(WordPart::SingleQuoted(text))
        self.maybe_warn_after_single_quoted(quote_start, text)
      }
      '"' => {
        push_word_literal(parts, literal)
        let quote_start = self.position()
        ignore(self.advance_one())
        parts.push(
          WordPart::DoubleQuoted(self.read_double_quoted_parts(quote_start)),
        )
      }
      ch if is_backquote_char(ch) => {
        push_word_literal(parts, literal)
        let quote_start = self.position()
        self.consume_backquote_start()
        parts.push(
          WordPart::BackQuoted(self.read_backquoted_script(false, quote_start)),
        )
      }
      '$' =>
        match self.parse_dollar_part() {
          Some(part) => {
            push_word_literal(parts, literal)
            match part {
              WordPart::BracedParameter(_) if self.peek() == Some('}') =>
                self.emit_diagnostic(
                  DiagnosticSeverity::Warning,
                  self.position(),
                  "This } is literal. Check expression (missing ;/\\n?) or quote it.",
                  Some(1083),
                )
              _ => ()
            }
            parts.push(part)
          }
          None => {
            ignore(self.advance_one())
            literal.write_char('$')
          }
        }
      '{' | '}' =>
        if ch == '{' && self.peek_n(1) == Some('}') {
          self.advance_n(2)
          literal.write_string("{}")
        } else {
          self.emit_diagnostic(
            DiagnosticSeverity::Warning,
            self.position(),
            "This \{ch.unsafe_to_char()} is literal. Check expression (missing ;/\\n?) or quote it.",
            Some(1083),
          )
          ignore(self.advance_one())
          literal.write_char(ch.unsafe_to_char())
        }
      '\\' => self.append_unquoted_escape(parts, literal, "escaped character")
      _ => {
        self.maybe_emit_unicode_quote(ch)
        ignore(self.advance_one())
        literal.write_char(ch.unsafe_to_char())
      }
    }
  }
  push_word_literal(parts, literal)
  parts
}

///|
fn Parser::parse_word(self : Parser) -> Word raise ParseError {
  self.parse_word_with_terminators(["do", "done", "then", "fi", "esac"])
}

///|
fn Parser::maybe_emit_possible_termination_warning(
  self : Parser,
  start : Position,
  parts : Array[WordPart],
  terminators : Array[String],
) -> Unit {
  if terminators.length() != 0 && parts.length() == 1 {
    match parts[0] {
      WordPart::Literal(text) =>
        for terminator in terminators {
          if text == terminator {
            self.emit_diagnostic(
              DiagnosticSeverity::Warning,
              start,
              "Use semicolon or linefeed before '\{text}' (or quote to make it literal).",
              Some(1010),
            )
            return
          }
        }
      _ => ()
    }
  }
}

///|
fn Parser::parse_word_with_terminators(
  self : Parser,
  terminators : Array[String],
) -> Word raise ParseError {
  let start = self.position()
  let start_offset = self.offset
  let parts : Array[WordPart] = []
  let literal = StringBuilder::new()
  while self.peek() is Some(ch) {
    if self.starts_with("<(") || self.starts_with(">(") {
      push_word_literal(parts, literal)
      parts.push(self.parse_process_substitution())
      continue
    }
    if self.starts_extglob() {
      push_word_literal(parts, literal)
      parts.push(WordPart::ExtGlob(self.read_extglob()))
      continue
    }
    if self.starts_brace_expansion() {
      push_word_literal(parts, literal)
      parts.push(WordPart::BraceExpansion(self.read_brace_expansion()))
      continue
    }
    if ch == '(' {
      self.emit_diagnostic(
        DiagnosticSeverity::Error,
        self.position(),
        "'(' is invalid here. Did you forget to escape it?",
        Some(1036),
      )
      if self.offset == start_offset {
        raise self.unexpected("word")
      }
      break
    }
    if is_word_boundary(Some(ch)) {
      break
    }
    match ch {
      '\'' => {
        push_word_literal(parts, literal)
        let quote_start = self.position()
        ignore(self.advance_one())
        let text = self.read_until_single_quote(quote_start)
        parts.push(WordPart::SingleQuoted(text))
        self.maybe_warn_after_single_quoted(quote_start, text)
      }
      '"' => {
        push_word_literal(parts, literal)
        let quote_start = self.position()
        ignore(self.advance_one())
        parts.push(
          WordPart::DoubleQuoted(self.read_double_quoted_parts(quote_start)),
        )
      }
      ch if is_backquote_char(ch) => {
        push_word_literal(parts, literal)
        let quote_start = self.position()
        self.consume_backquote_start()
        parts.push(
          WordPart::BackQuoted(self.read_backquoted_script(false, quote_start)),
        )
      }
      '$' =>
        match self.parse_dollar_part() {
          Some(part) => {
            push_word_literal(parts, literal)
            match part {
              WordPart::BracedParameter(_) if self.peek() == Some('}') =>
                self.emit_diagnostic(
                  DiagnosticSeverity::Warning,
                  self.position(),
                  "This } is literal. Check expression (missing ;/\\n?) or quote it.",
                  Some(1083),
                )
              _ => ()
            }
            parts.push(part)
          }
          None => {
            ignore(self.advance_one())
            literal.write_char('$')
          }
        }
      '{' | '}' =>
        if ch == '{' && self.peek_n(1) == Some('}') {
          self.advance_n(2)
          literal.write_string("{}")
        } else {
          self.emit_diagnostic(
            DiagnosticSeverity::Warning,
            self.position(),
            "This \{ch.unsafe_to_char()} is literal. Check expression (missing ;/\\n?) or quote it.",
            Some(1083),
          )
          ignore(self.advance_one())
          literal.write_char(ch.unsafe_to_char())
        }
      '\\' => self.append_unquoted_escape(parts, literal, "escaped character")
      _ => {
        self.maybe_emit_unicode_quote(ch)
        ignore(self.advance_one())
        literal.write_char(ch.unsafe_to_char())
      }
    }
  }
  push_word_literal(parts, literal)
  if self.offset == start_offset {
    raise self.unexpected("word")
  }
  self.maybe_emit_possible_termination_warning(start, parts, terminators)
  {
    span: make_span(start, self.position()),
    source: self.current_slice(start_offset),
    parts,
  }
}

///|
fn Parser::read_until_single_quote(
  self : Parser,
  open_pos : Position,
) -> String raise ParseError {
  let content = StringBuilder::new()
  while self.peek() is Some(ch) {
    if ch == '\'' {
      ignore(self.advance_one())
      return content.to_string()
    }
    if ch == '\\' && self.peek_n(1) == Some('\'') {
      self.emit_diagnostic(
        DiagnosticSeverity::Info,
        self.position(),
        "Want to escape a single quote? echo 'This is how it'\\''s done'.",
        Some(1003),
      )
    }
    if is_unicode_single_quote_char(ch) {
      self.emit_diagnostic(
        DiagnosticSeverity::Warning,
        self.position(),
        "This is a unicode quote. Delete and retype it (or ignore/doublequote for literal).",
        Some(1112),
      )
    }
    ignore(self.advance_one())
    content.write_char(ch.unsafe_to_char())
  }
  self.emit_simple_command_context_diagnostic()
  let parse_message = "Couldn't parse this single quoted string. Fix to allow more checks."
  self.emit_diagnostic(
    DiagnosticSeverity::Error,
    open_pos,
    parse_message,
    Some(1073),
  )
  let end_message = "Expected end of single quoted string. Fix any mentioned problems and try again."
  self.emit_diagnostic(
    DiagnosticSeverity::Error,
    self.position(),
    end_message,
    Some(1072),
  )
  raise ParseError::Message(pos=self.position(), message=end_message)
}

///|
fn string_starts_with_linefeed(text : String) -> Bool {
  text.has_prefix("\n") ||
  text.has_prefix(
    (
      $|\{'\r'}
      $|
    ),
  )
}

///|
fn string_contains_linefeed(text : String) -> Bool {
  text.contains("\n")
}

///|
fn Parser::has_suspect_char_after_quotes(self : Parser) -> Bool {
  match self.peek() {
    Some(ch) => is_suspect_char_after_quotes(ch)
    None => false
  }
}

///|
fn Parser::emit_suspect_quote_close_diagnostics(
  self : Parser,
  start : Position,
  context : String,
) -> Unit {
  self.emit_diagnostic(
    DiagnosticSeverity::Warning,
    start,
    "Did you forget to close this \{context}?",
    Some(1078),
  )
  self.emit_diagnostic(
    DiagnosticSeverity::Info,
    retreat_position_columns(self.position(), 1),
    "This is actually an end quote, but due to next char it looks suspect.",
    Some(1079),
  )
}

///|
fn Parser::maybe_warn_after_single_quoted(
  self : Parser,
  start : Position,
  text : String,
) -> Unit {
  if !self.has_suspect_char_after_quotes() {
    return
  }
  if string_contains_linefeed(text) && !string_starts_with_linefeed(text) {
    self.emit_suspect_quote_close_diagnostics(start, "single quoted string")
    return
  }
  let view = text[:]
  match (view.length(), self.peek()) {
    (0, _) => ()
    (_, Some(next)) =>
      if is_ascii_alpha(view[view.length() - 1]) && is_ascii_alpha(next) {
        self.emit_diagnostic(
          DiagnosticSeverity::Warning,
          retreat_position_columns(self.position(), 1),
          "This apostrophe terminated the single quoted string!",
          Some(1011),
        )
      }
    _ => ()
  }
}

///|
fn double_quoted_parts_start_with_linefeed(parts : Array[WordPart]) -> Bool {
  if parts.length() == 0 {
    return false
  }
  match parts[0] {
    WordPart::Literal(text) => string_starts_with_linefeed(text)
    _ => false
  }
}

///|
fn double_quoted_parts_contain_linefeed(parts : Array[WordPart]) -> Bool {
  for part in parts {
    match part {
      WordPart::Literal(text) if string_contains_linefeed(text) => return true
      _ => ()
    }
  }
  false
}

///|
fn Parser::should_warn_double_quoted_literal_dollar(self : Parser) -> Bool {
  if self.peek() != Some('$') || self.peek_n(1) != Some('"') {
    return false
  }
  let mut next = 2
  if self.peek_n(next) == Some('"') {
    next += 1
  }
  match self.peek_n(next) {
    Some(ch) if is_name_start(ch) ||
      is_digit(ch) ||
      is_special_parameter_char(ch) => ch != '*' && ch != '$'
    _ => false
  }
}

///|
fn Parser::read_double_quoted_parts(
  self : Parser,
  open_pos : Position,
) -> Array[WordPart] raise ParseError {
  let parts : Array[WordPart] = []
  let literal = StringBuilder::new()
  while self.peek() is Some(ch) {
    match ch {
      '"' => {
        ignore(self.advance_one())
        push_literal(parts, literal)
        if self.has_suspect_char_after_quotes() &&
          double_quoted_parts_contain_linefeed(parts) &&
          !double_quoted_parts_start_with_linefeed(parts) {
          self.emit_suspect_quote_close_diagnostics(
            open_pos, "double quoted string",
          )
        }
        return parts
      }
      ch if is_backquote_char(ch) => {
        push_literal(parts, literal)
        let quote_start = self.position()
        self.consume_backquote_start()
        parts.push(
          WordPart::BackQuoted(self.read_backquoted_script(true, quote_start)),
        )
      }
      '$' =>
        match self.parse_dollar_part_internal(false) {
          Some(part) => {
            push_literal(parts, literal)
            parts.push(part)
          }
          None => {
            if self.should_warn_double_quoted_literal_dollar() {
              self.emit_diagnostic(
                DiagnosticSeverity::Warning,
                self.position(),
                "Prefer escape over ending quote to make $ literal. Instead of \"It costs $\"5, use \"It costs \\$5\".",
                Some(1135),
              )
            }
            ignore(self.advance_one())
            literal.write_char('$')
          }
        }
      '\\' => self.append_double_quoted_escape(literal, "escaped character")
      _ => {
        if is_unicode_double_quote_char(ch) {
          self.emit_diagnostic(
            DiagnosticSeverity::Warning,
            self.position(),
            "This is a unicode quote. Delete and retype it (or ignore/singlequote for literal).",
            Some(1111),
          )
        }
        ignore(self.advance_one())
        literal.write_char(ch.unsafe_to_char())
      }
    }
  }
  self.emit_simple_command_context_diagnostic()
  let parse_message = "Couldn't parse this double quoted string. Fix to allow more checks."
  self.emit_diagnostic(
    DiagnosticSeverity::Error,
    open_pos,
    parse_message,
    Some(1073),
  )
  let end_message = "Expected end of double quoted string. Fix any mentioned problems and try again."
  self.emit_diagnostic(
    DiagnosticSeverity::Error,
    self.position(),
    end_message,
    Some(1072),
  )
  raise ParseError::Message(pos=self.position(), message=end_message)
}

///|
fn Parser::parse_dollar_part_internal(
  self : Parser,
  allow_quoted_forms : Bool,
) -> WordPart? raise ParseError {
  if self.peek() != Some('$') {
    return None
  }
  let start_pos = self.position()
  if self.starts_with("$((") {
    let mark = self.mark()
    let try_arithmetic = fn() -> WordPart raise ParseError {
      self.advance_n(3)
      let content = self.read_arithmetic_expansion()
      self.advance_n(2)
      let expr = parse_arithmetic_expr(content)
      if !validate_arithmetic_expr(expr) {
        raise ParseError::Message(
          pos=start_pos,
          message="ambiguous dollar arithmetic expression",
        )
      }
      WordPart::ArithmeticExpansion(expr)
    }
    try {
      return Some(try_arithmetic())
    } catch {
      _ => {
        self.reset(mark)
        try {
          self.advance_n(2)
          let script = self.resolve_nested_script(
            self.parse_script([], Some(')')),
          )
          self.ensure_no_pending_heredocs()
          if self.peek() != Some(')') {
            raise self.unexpected(")")
          }
          ignore(self.advance_one())
          self.emit_diagnostic(
            DiagnosticSeverity::Error,
            start_pos,
            "Shells disambiguate $(( differently or not at all. For $(command substitution), add space after $( . For $((arithmetics)), fix parsing errors.",
            Some(1102),
          )
          return Some(WordPart::CommandSubstitution(script))
        } catch {
          _ => {
            self.reset(mark)
            return Some(try_arithmetic())
          }
        }
      }
    }
  }
  if self.starts_with("$(") {
    self.advance_n(2)
    let script = self.resolve_nested_script(self.parse_script([], Some(')')))
    self.ensure_no_pending_heredocs()
    if self.peek() != Some(')') {
      raise self.unexpected(")")
    }
    ignore(self.advance_one())
    return Some(WordPart::CommandSubstitution(script))
  }
  if allow_quoted_forms && self.starts_with("$'") {
    self.advance_n(2)
    return Some(WordPart::DollarSingleQuoted(self.read_dollar_single_quoted()))
  }
  if allow_quoted_forms && self.starts_with("$\"") {
    self.advance_n(2)
    return Some(
      WordPart::DollarDoubleQuoted(
        self.read_double_quoted_parts(advance_position_columns(start_pos, 1)),
      ),
    )
  }
  if self.starts_with("$[") {
    self.advance_n(2)
    return Some(
      WordPart::DollarBracket(
        parse_arithmetic_expr(
          self.read_dollar_bracket_content("dollar-bracket expansion"),
        ),
      ),
    )
  }
  if self.starts_with("${") {
    self.advance_n(2)
    if self.peek() == Some('|') ||
      self.peek() == Some(' ') ||
      self.peek() == Some('\t') ||
      self.peek() == Some('\n') ||
      self.peek() == Some('\r') {
      return Some(self.read_brace_command_substitution(start_pos))
    }
    return Some(
      WordPart::BracedParameter(
        parse_parameter_expansion(self.read_braced_parameter()),
      ),
    )
  }
  match self.peek_n(1) {
    Some(ch) if is_name_start(ch) => {
      self.advance_n(1)
      let start = self.offset
      ignore(self.advance_one())
      while self.peek() is Some(next) && is_name_part(next) {
        ignore(self.advance_one())
      }
      if self.peek() == Some('[') {
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          start_pos,
          "Use braces when expanding arrays, e.g. ${array[idx]} (or ${var}[.. to quiet).",
          Some(1087),
        )
      }
      Some(WordPart::Parameter(self.current_slice(start)))
    }
    Some(ch) if is_digit(ch) || is_special_parameter_char(ch) => {
      self.advance_n(1)
      let start = self.offset
      ignore(self.advance_one())
      if is_digit(ch) && self.peek() is Some(next) && is_digit(next) {
        self.emit_diagnostic(
          DiagnosticSeverity::Error,
          start_pos,
          "Braces are required for positionals over 9, e.g. ${10}.",
          Some(1037),
        )
      }
      Some(WordPart::SpecialParameter(self.current_slice(start)))
    }
    _ => None
  }
}

///|
fn Parser::parse_dollar_part(self : Parser) -> WordPart? raise ParseError {
  self.parse_dollar_part_internal(true)
}

///|
fn Parser::read_braced_parameter(self : Parser) -> String raise ParseError {
  let content = StringBuilder::new()
  while self.peek() is Some(ch) {
    if ch == '}' {
      ignore(self.advance_one())
      return content.to_string()
    }
    if self.starts_with("${") {
      self.advance_n(2)
      content.write_string("${")
      content.write_string(self.read_braced_parameter())
      content.write_char('}')
      continue
    }
    if self.starts_with("$((") {
      self.advance_n(3)
      content.write_string("$((")
      content.write_string(self.read_arithmetic_expansion())
      self.advance_n(2)
      content.write_string("))")
      continue
    }
    if self.starts_with("$(") {
      ignore(self.advance_one())
      content.write_char('$')
      content.write_string(
        self.read_balanced_paren_content("parameter expansion"),
      )
      continue
    }
    if ch == '\'' || ch == '"' {
      ignore(self.advance_one())
      content.write_char(ch.unsafe_to_char())
      content.write_string(self.read_until_matching_quote(ch))
      if self.peek() != Some(ch) {
        raise self.unexpected_end("parameter expansion")
      }
      ignore(self.advance_one())
      content.write_char(ch.unsafe_to_char())
      continue
    }
    if ch == '`' {
      ignore(self.advance_one())
      content.write_char('`')
      content.write_string(
        self.read_until_closing_char('`', "parameter expansion"),
      )
      content.write_char('`')
      continue
    }
    if ch == '\\' {
      ignore(self.advance_one())
      match self.peek() {
        Some(next) => {
          content.write_char('\\')
          ignore(self.advance_one())
          content.write_char(next.unsafe_to_char())
        }
        None => raise self.unexpected_end("parameter expansion")
      }
      continue
    }
    ignore(self.advance_one())
    content.write_char(ch.unsafe_to_char())
  }
  raise self.unexpected_end("parameter expansion")
}

///|
fn Parser::read_arithmetic_expansion(self : Parser) -> String raise ParseError {
  let content = StringBuilder::new()
  let mut depth = 1
  while self.peek() is Some(ch) {
    let nested_start = self.offset
    if self.skip_shell_nested_segment("arithmetic expansion") {
      content.write_string(
        self.source
        .view(start_offset=nested_start, end_offset=self.offset)
        .to_string(),
      )
      continue
    }
    if ch == '(' {
      depth += 1
      ignore(self.advance_one())
      content.write_char('(')
      continue
    }
    if ch == ')' {
      if depth == 1 && self.peek_n(1) == Some(')') {
        return content.to_string()
      }
      depth -= 1
      ignore(self.advance_one())
      content.write_char(')')
      continue
    }
    if ch == '\\' {
      ignore(self.advance_one())
      content.write_char('\\')
      match self.peek() {
        Some(next) => {
          ignore(self.advance_one())
          content.write_char(next.unsafe_to_char())
        }
        None => raise self.unexpected_end("arithmetic expansion")
      }
      continue
    }
    ignore(self.advance_one())
    content.write_char(ch.unsafe_to_char())
  }
  raise self.unexpected_end("arithmetic expansion")
}

///|
fn Parser::read_until_matching_quote(
  self : Parser,
  quote : UInt16,
) -> String raise ParseError {
  let content = StringBuilder::new()
  while self.peek() is Some(ch) {
    if ch == quote {
      return content.to_string()
    }
    if ch == '\\' {
      ignore(self.advance_one())
      content.write_char('\\')
      match self.peek() {
        Some(next) => {
          ignore(self.advance_one())
          content.write_char(next.unsafe_to_char())
        }
        None => raise self.unexpected_end("quoted string")
      }
      continue
    }
    ignore(self.advance_one())
    content.write_char(ch.unsafe_to_char())
  }
  raise self.unexpected_end("quoted string")
}

///|
fn quote_removed_source(raw : String) -> String {
  let buf = StringBuilder::new()
  let view = raw[:]
  let mut i = 0
  let mut quote : UInt16? = None
  while i < view.length() {
    let ch = view[i]
    match quote {
      Some(current) => {
        if ch == current {
          quote = None
          i += 1
          continue
        }
        if current == '"' && ch == '\\' && i + 1 < view.length() {
          let next = view[i + 1]
          if next == '$' ||
            next == '"' ||
            next == '\\' ||
            next == '\n' ||
            next == '\r' {
            buf.write_char(next.unsafe_to_char())
            i += 2
            continue
          }
        }
        buf.write_char(ch.unsafe_to_char())
        i += 1
      }
      None => {
        if ch == '\'' || ch == '"' {
          quote = Some(ch)
          i += 1
          continue
        }
        if ch == '\\' {
          if i + 1 < view.length() {
            buf.write_char(view[i + 1].unsafe_to_char())
            i += 2
          } else {
            i += 1
          }
          continue
        }
        buf.write_char(ch.unsafe_to_char())
        i += 1
      }
    }
  }
  buf.to_string()
}

///|
fn strip_leading_tabs(input : String) -> String {
  let view = input[:]
  let mut i = 0
  while i < view.length() && view[i] == '\t' {
    i += 1
  }
  input.view(start_offset=i).to_string()
}

///|
fn strip_leading_space_tabs(input : String) -> String {
  let view = input[:]
  let mut i = 0
  while i < view.length() && (view[i] == ' ' || view[i] == '\t') {
    i += 1
  }
  input.view(start_offset=i).to_string()
}

///|
fn all_space_tabs(input : String) -> Bool {
  for ch in input {
    if ch != ' ' && ch != '\t' {
      return false
    }
  }
  true
}

///|
fn here_doc_trailer_start(rest : String) -> UInt16? {
  let view = rest[:]
  let mut i = 0
  while i < view.length() && (view[i] == ' ' || view[i] == '\t') {
    i += 1
  }
  if i < view.length() {
    Some(view[i])
  } else {
    None
  }
}

///|
fn leading_space_tabs_count(input : String) -> Int {
  let view = input[:]
  let mut i = 0
  while i < view.length() && (view[i] == ' ' || view[i] == '\t') {
    i += 1
  }
  i
}

///|
fn classify_here_doc_near_match(
  line : String,
  delimiter : String,
  strip_tabs : Bool,
) -> (Int, Int, String)? {
  let trimmed_ws = strip_leading_space_tabs(line)
  if strip_tabs && trimmed_ws.has_prefix(delimiter) {
    let trimmed_tabs = strip_leading_tabs(line)
    if trimmed_tabs != trimmed_ws {
      return Some((0, 1040, "When using <<-, you can only indent with tabs."))
    }
  }
  if strip_tabs {
    let normalized_delimiter = strip_leading_space_tabs(delimiter)
    if normalized_delimiter != delimiter &&
      trimmed_ws.has_prefix(normalized_delimiter) {
      let trimmed_tabs = strip_leading_tabs(line)
      if trimmed_tabs != trimmed_ws {
        return Some((0, 1040, "When using <<-, you can only indent with tabs."))
      }
    }
  }

  if !strip_tabs && trimmed_ws.has_prefix(delimiter) && trimmed_ws != line {
    let rest = trimmed_ws.view(start_offset=delimiter.length()).to_string()
    if rest == "" {
      return Some(
        (
          0, 1039, "Remove indentation before end token (or use <<- and indent with tabs).",
        ),
      )
    }
  }

  let candidate = if strip_tabs { strip_leading_tabs(line) } else { line }
  if candidate.has_prefix(delimiter) {
    let delimiter_column = line.length() - candidate.length()
    let rest = candidate.view(start_offset=delimiter.length()).to_string()
    if rest == "" {
      return None
    }
    if all_space_tabs(rest) {
      return Some(
        (
          delimiter_column + delimiter.length(),
          1118,
          "Delete whitespace after the here-doc end token.",
        ),
      )
    }
    let trailer_column = delimiter_column +
      delimiter.length() +
      leading_space_tabs_count(rest)
    match here_doc_trailer_start(rest) {
      Some(')') =>
        return Some(
          (
            trailer_column, 1119, "Add a linefeed between end token and terminating ')'.",
          ),
        )
      Some('#') =>
        return Some(
          (
            trailer_column, 1120, "No comments allowed after here-doc token. Comment the next line instead.",
          ),
        )
      Some(';') | Some('>') | Some('|') | Some('&') =>
        return Some(
          (
            trailer_column, 1121, "Add ;/& terminators (and other syntax) on the line with the <<, not here.",
          ),
        )
      _ => ()
    }
    if strip_leading_space_tabs(rest) != rest {
      return Some(
        (
          trailer_column, 1122, "Nothing allowed after end token. To continue a command, put it on the line with the <<.",
        ),
      )
    }
  }

  None
}

///|
fn Parser::read_line(self : Parser) -> (String, Bool) {
  let start = self.offset
  while self.peek() is Some(ch) {
    if ch == '\n' || ch == '\r' {
      break
    }
    ignore(self.advance_one())
  }
  let line = self.source
    .view(start_offset=start, end_offset=self.offset)
    .to_string()
  let has_newline = self.consume_newline()
  (line, has_newline)
}

///|
fn Parser::read_pending_heredocs(self : Parser) -> Unit {
  let pending = self.pending_heredocs
  self.pending_heredocs = []
  for entry in pending {
    let body = StringBuilder::new()
    let body_diagnostics : Array[Diagnostic] = []
    let mut body_diagnostics_emitted = false
    let mut saw_near_match = false
    let mut terminated = false
    let body_start = self.position()
    while true {
      if self.eof() {
        if !saw_near_match {
          if body.to_string().contains(entry.delimiter) {
            let diagnostic = {
              span: span_at(entry.delimiter_pos),
              severity: DiagnosticSeverity::Error,
              code: Some(1041),
              message: "Found '\{entry.delimiter}' further down, but not on a separate line.",
            }
            if !annotations_disable_code(entry.annotations, diagnostic.code) {
              body_diagnostics.push(diagnostic)
            }
            match first_line_containing(body.to_string(), entry.delimiter) {
              Some(line) => {
                let diagnostic = {
                  span: span_at(entry.delimiter_pos),
                  severity: DiagnosticSeverity::Error,
                  code: Some(1042),
                  message: "Close matches include '\{line}' (!= '\{entry.delimiter}').",
                }
                if !annotations_disable_code(entry.annotations, diagnostic.code) {
                  body_diagnostics.push(diagnostic)
                }
              }
              None => ()
            }
          } else if lower_ascii_string(body.to_string()).contains(
              lower_ascii_string(entry.delimiter),
            ) {
            let diagnostic = {
              span: span_at(entry.delimiter_pos),
              severity: DiagnosticSeverity::Error,
              code: Some(1043),
              message: "Found \{entry.delimiter} further down, but with wrong casing.",
            }
            if !annotations_disable_code(entry.annotations, diagnostic.code) {
              body_diagnostics.push(diagnostic)
            }
          } else {
            let diagnostic = {
              span: span_at(entry.delimiter_pos),
              severity: DiagnosticSeverity::Error,
              code: Some(1044),
              message: "Couldn't find end token `\{entry.delimiter}' in the here document.",
            }
            if !annotations_disable_code(entry.annotations, diagnostic.code) {
              body_diagnostics.push(diagnostic)
            }
          }
        }
        if !annotations_disable_code(entry.annotations, Some(1009)) {
          match (entry.owner_context_pos, entry.owner_context_message) {
            (Some(pos), Some(message)) =>
              self.diagnostics.push({
                span: span_at(pos),
                severity: DiagnosticSeverity::Info,
                code: Some(1009),
                message,
              })
            _ => ()
          }
        }
        if !annotations_disable_code(entry.annotations, Some(1073)) {
          self.diagnostics.push({
            span: span_at(entry.redirection_pos),
            severity: DiagnosticSeverity::Error,
            code: Some(1073),
            message: "Couldn't parse this here document. Fix to allow more checks.",
          })
        }
        for diagnostic in body_diagnostics {
          self.diagnostics.push(diagnostic)
        }
        body_diagnostics_emitted = true
        let eof_message = "Here document was not correctly terminated. Fix any mentioned problems and try again."
        if !annotations_disable_code(entry.annotations, Some(1072)) {
          self.diagnostics.push({
            span: span_at(self.position()),
            severity: DiagnosticSeverity::Error,
            code: Some(1072),
            message: eof_message,
          })
        }
        break
      }
      let line_pos = self.position()
      let (line, has_newline) = self.read_line()
      let compare = if entry.strip_tabs {
        strip_leading_tabs(line)
      } else {
        line
      }
      if compare == entry.delimiter {
        terminated = true
        break
      }
      if compare.has_prefix(entry.delimiter) {
        let delimiter_column = line.length() - compare.length()
        let rest = compare
          .view(start_offset=entry.delimiter.length())
          .to_string()
        if all_space_tabs(rest) {
          let diagnostic = {
            span: span_at(
              advance_position_columns(
                line_pos,
                delimiter_column + entry.delimiter.length(),
              ),
            ),
            severity: DiagnosticSeverity::Error,
            code: Some(1118),
            message: "Delete whitespace after the here-doc end token.",
          }
          if !annotations_disable_code(entry.annotations, diagnostic.code) {
            body_diagnostics.push(diagnostic)
          }
          break
        }
      }
      if !saw_near_match {
        match
          classify_here_doc_near_match(line, entry.delimiter, entry.strip_tabs) {
          Some((column_offset, code, message)) => {
            let diagnostic = {
              span: span_at(advance_position_columns(line_pos, column_offset)),
              severity: DiagnosticSeverity::Error,
              code: Some(code),
              message,
            }
            if !annotations_disable_code(entry.annotations, diagnostic.code) {
              body_diagnostics.push(diagnostic)
            }
            saw_near_match = true
          }
          None => ()
        }
      }
      body.write_string(compare)
      if has_newline {
        body.write_char('\n')
      }
    }
    if !body_diagnostics_emitted {
      for diagnostic in body_diagnostics {
        self.diagnostics.push(diagnostic)
      }
    }
    let redirection = entry.redirections[entry.index]
    let text = body.to_string()
    let parts = if !terminated || entry.quoted {
      None
    } else {
      let parser = Parser::new(text.view(), self.options, self.source_stack)
      try {
        let parts = parser.parse_here_doc_parts()
        for diagnostic in parser.diagnostics {
          if !annotations_disable_code(entry.annotations, diagnostic.code) {
            self.diagnostics.push({
              ..diagnostic,
              span: translate_span(body_start, diagnostic.span),
            })
          }
        }
        Some(parts)
      } catch {
        _ => {
          if !annotations_disable_code(entry.annotations, Some(1009)) {
            self.diagnostics.push({
              span: span_at(entry.redirection_pos),
              severity: DiagnosticSeverity::Info,
              code: Some(1009),
              message: "The mentioned syntax error was in this here document.",
            })
          }
          for diagnostic in parser.diagnostics {
            if !annotations_disable_code(entry.annotations, diagnostic.code) {
              let message = if diagnostic.code == Some(1072) {
                " Fix any mentioned problems and try again."
              } else {
                diagnostic.message
              }
              let translated = {
                ..diagnostic,
                message,
                span: translate_span(body_start, diagnostic.span),
              }
              self.diagnostics.push({ ..translated })
            }
          }
          None
        }
      }
    }
    entry.redirections[entry.index] = {
      ..redirection,
      target: RedirectionTarget::HereDoc({
        delimiter: entry.delimiter,
        quoted: entry.quoted,
        strip_tabs: entry.strip_tabs,
        body: text,
        parts,
      }),
    }
  }
}

///|
fn parse_error_diagnostic(err : ParseError) -> Diagnostic {
  match err {
    ParseError::UnexpectedEnd(pos~, context~) =>
      {
        span: span_at(pos),
        severity: DiagnosticSeverity::Error,
        code: None,
        message: "unexpected end while parsing \{context}",
      }
    ParseError::UnexpectedToken(pos~, found~, expected~) =>
      {
        span: span_at(pos),
        severity: DiagnosticSeverity::Error,
        code: None,
        message: "expected \{expected}, found \{found}",
      }
    ParseError::Message(pos~, message~) =>
      {
        span: span_at(pos),
        severity: DiagnosticSeverity::Error,
        code: None,
        message,
      }
  }
}

///|
fn diagnostic_as_error(diagnostic : Diagnostic) -> ParseError {
  ParseError::Message(pos=diagnostic.span.start, message=diagnostic.message)
}

///|
fn dirname(path : String) -> String {
  let view = path[:]
  let mut slash : Int? = None
  let mut i = 0
  while i < view.length() {
    if view[i] == '/' {
      slash = Some(i)
    }
    i += 1
  }
  match slash {
    None => "."
    Some(0) => "/"
    Some(index) => path.view(end_offset=index).to_string()
  }
}

///|
fn join_path(base : String, relative : String) -> String {
  if relative.has_prefix("/") || base == "" || base == "." {
    relative
  } else if base.has_suffix("/") {
    base + relative
  } else {
    base + "/" + relative
  }
}

///|
fn merge_annotations(
  left : Array[Annotation],
  right : Array[Annotation],
) -> Array[Annotation] {
  let merged : Array[Annotation] = []
  for annotation in left {
    merged.push(annotation)
  }
  for annotation in right {
    merged.push(annotation)
  }
  merged
}

///|
fn effective_source_paths(
  options : ParseOptions,
  annotations : Array[Annotation],
) -> Array[String] {
  let paths : Array[String] = []
  for path in options.source_paths {
    paths.push(path)
  }
  for annotation in annotations {
    match annotation {
      Annotation::SourcePath(path) => paths.push(path)
      _ => ()
    }
  }
  paths
}

///|
fn effective_external_sources(
  options : ParseOptions,
  annotations : Array[Annotation],
) -> Bool {
  let mut enabled = options.external_sources
  for annotation in annotations {
    match annotation {
      Annotation::ExternalSources(flag) => enabled = flag
      _ => ()
    }
  }
  enabled
}

///|
fn lookup_source_text(options : ParseOptions, path : String) -> String? {
  for pair in options.source_files {
    if pair.0 == path {
      return Some(pair.1)
    }
  }
  None
}

///|
fn resolve_source_input(
  path : String,
  options : ParseOptions,
  annotations : Array[Annotation],
) -> (String, String)? {
  if path == "/dev/null" {
    return Some((path, ""))
  }
  let candidates : Array[String] = [path]
  if !path.has_prefix("/") {
    match options.current_path {
      Some(current) => candidates.push(join_path(dirname(current), path))
      None => ()
    }
    for base in effective_source_paths(options, annotations) {
      candidates.push(join_path(base, path))
    }
  }
  for candidate in candidates {
    match lookup_source_text(options, candidate) {
      Some(contents) => return Some((candidate, contents))
      None => ()
    }
  }
  None
}

///|
fn source_override_path(annotations : Array[Annotation]) -> String? {
  let mut path_override : String? = None
  for annotation in annotations {
    match annotation {
      Annotation::Source(path) => path_override = Some(path)
      _ => ()
    }
  }
  path_override
}

///|
fn is_dynamic_source_prefix_part(part : WordPart) -> Bool {
  match part {
    WordPart::Parameter(_)
    | WordPart::SpecialParameter(_)
    | WordPart::BracedParameter(_)
    | WordPart::BraceCommandSubstitution(_, _)
    | WordPart::CommandSubstitution(_)
    | WordPart::BackQuoted(_)
    | WordPart::ArithmeticExpansion(_)
    | WordPart::DollarBracket(_) => true
    _ => false
  }
}

///|
fn source_word_with_dynamic_prefix(word : Word) -> String? {
  if word.parts.length() == 0 {
    return None
  }
  let suffix = StringBuilder::new()
  if !append_dynamic_source_prefix_part(word.parts[0], suffix) {
    return None
  }
  let mut i = 1
  while i < word.parts.length() {
    if !append_literal_word_part_text(word.parts[i], suffix) {
      return None
    }
    i += 1
  }
  let path = suffix.to_string()
  if path.has_prefix("/") {
    Some("." + path)
  } else {
    None
  }
}

///|
fn append_dynamic_source_prefix_part(
  part : WordPart,
  buf : StringBuilder,
) -> Bool {
  match part {
    WordPart::DoubleQuoted(parts) | WordPart::DollarDoubleQuoted(parts) => {
      if parts.length() == 0 ||
        !append_dynamic_source_prefix_part(parts[0], buf) {
        return false
      }
      let mut i = 1
      while i < parts.length() {
        if !append_literal_word_part_text(parts[i], buf) {
          return false
        }
        i += 1
      }
      true
    }
    _ => is_dynamic_source_prefix_part(part)
  }
}

///|
fn resolve_source_command_path(
  source : SourceCommand,
  annotations : Array[Annotation],
) -> String? {
  let path = match source_override_path(annotations) {
    Some(path) => Some(path)
    None =>
      match word_literal_text(source.path) {
        Some(path) => Some(path)
        None => source_word_with_dynamic_prefix(source.path)
      }
  }
  match path {
    Some(path) if path.has_prefix("~/") => None
    _ => path
  }
}

///|
fn source_command_resolution_span(source : SourceCommand) -> Span {
  source.path.span
}

///|
fn resolve_command_sources(
  command : Command,
  file_annotations : Array[Annotation],
  active_annotations : Array[Annotation],
  options : ParseOptions,
  stack : Array[String],
  diagnostics : Array[Diagnostic],
) -> Command {
  let resolved_kind = match command.kind {
    CommandKind::Simple(simple) => CommandKind::Simple(simple)
    CommandKind::Source(source) =>
      if !options.follow_sources {
        CommandKind::Source(source)
      } else {
        match resolve_source_command_path(source, active_annotations) {
          None => {
            diagnostics.push({
              span: source_command_resolution_span(source),
              severity: DiagnosticSeverity::Warning,
              code: Some(1090),
              message: "source path is dynamic; include resolution was skipped",
            })
            CommandKind::Source(source)
          }
          Some(path) =>
            match resolve_source_input(path, options, active_annotations) {
              None => {
                diagnostics.push({
                  span: source_command_resolution_span(source),
                  severity: if effective_external_sources(
                      options, active_annotations,
                    ) {
                    DiagnosticSeverity::Info
                  } else {
                    DiagnosticSeverity::Warning
                  },
                  code: Some(1091),
                  message: "source file '\{path}' was not provided in parse options",
                })
                CommandKind::Source(source)
              }
              Some((resolved_path, contents)) =>
                if stack.contains(resolved_path) {
                  diagnostics.push({
                    span: source_command_resolution_span(source),
                    severity: DiagnosticSeverity::Info,
                    code: Some(1093),
                    message: "source file '\{resolved_path}' is already being parsed; skipping recursive include",
                  })
                  CommandKind::Source({
                    ..source,
                    resolved_path: Some(resolved_path),
                  })
                } else if stack.length() >= 100 {
                  diagnostics.push({
                    span: source_command_resolution_span(source),
                    severity: DiagnosticSeverity::Error,
                    code: Some(1092),
                    message: "Stopping at 100 'source' frames :O",
                  })
                  CommandKind::Source({
                    ..source,
                    resolved_path: Some(resolved_path),
                  })
                } else {
                  let nested_options = {
                    ..options,
                    sourced: true,
                    current_path: Some(resolved_path),
                    source_paths: effective_source_paths(
                      options, active_annotations,
                    ),
                    external_sources: effective_external_sources(
                      options, active_annotations,
                    ),
                  }
                  let next_stack : Array[String] = []
                  for item in stack {
                    next_stack.push(item)
                  }
                  next_stack.push(resolved_path)
                  let report = parse_script_with_options_internal(
                    contents, nested_options, next_stack,
                  )
                  if nested_parse_blocks_include(report.diagnostics) {
                    diagnostics.push({
                      span: source_command_resolution_span(source),
                      severity: DiagnosticSeverity::Warning,
                      code: Some(1094),
                      message: "source file '\{resolved_path}' could not be parsed; include was skipped",
                    })
                    CommandKind::Source({
                      ..source,
                      resolved_path: Some(resolved_path),
                    })
                  } else {
                    match report.script {
                      Some(script) => {
                        for diagnostic in report.diagnostics {
                          diagnostics.push(diagnostic)
                        }
                        CommandKind::Source({
                          ..source,
                          resolved_path: Some(resolved_path),
                          included: Some(script),
                        })
                      }
                      None => {
                        diagnostics.push({
                          span: source_command_resolution_span(source),
                          severity: DiagnosticSeverity::Warning,
                          code: Some(1094),
                          message: "source file '\{resolved_path}' could not be parsed; include was skipped",
                        })
                        CommandKind::Source({
                          ..source,
                          resolved_path: Some(resolved_path),
                        })
                      }
                    }
                  }
                }
            }
        }
      }
    CommandKind::Time(clause) =>
      CommandKind::Time({
        ..clause,
        body: resolve_pipeline_sources(
          clause.body,
          file_annotations,
          active_annotations,
          options,
          stack,
          diagnostics,
        ),
      })
    CommandKind::Subshell(script) =>
      CommandKind::Subshell(
        resolve_script_sources(
          script, file_annotations, options, stack, diagnostics,
        ),
      )
    CommandKind::BraceGroup(script) =>
      CommandKind::BraceGroup(
        resolve_script_sources(
          script, file_annotations, options, stack, diagnostics,
        ),
      )
    CommandKind::If(clause) => {
      let arms : Array[IfArm] = []
      for arm in clause.arms {
        arms.push({
          condition: resolve_script_sources(
            arm.condition,
            file_annotations,
            options,
            stack,
            diagnostics,
          ),
          body: resolve_script_sources(
            arm.body,
            file_annotations,
            options,
            stack,
            diagnostics,
          ),
        })
      }
      let else_body = match clause.else_body {
        None => None
        Some(script) =>
          Some(
            resolve_script_sources(
              script, file_annotations, options, stack, diagnostics,
            ),
          )
      }
      CommandKind::If({ arms, else_body })
    }
    CommandKind::While(loop_) =>
      CommandKind::While({
        condition: resolve_script_sources(
          loop_.condition,
          file_annotations,
          options,
          stack,
          diagnostics,
        ),
        body: resolve_script_sources(
          loop_.body,
          file_annotations,
          options,
          stack,
          diagnostics,
        ),
      })
    CommandKind::Until(loop_) =>
      CommandKind::Until({
        condition: resolve_script_sources(
          loop_.condition,
          file_annotations,
          options,
          stack,
          diagnostics,
        ),
        body: resolve_script_sources(
          loop_.body,
          file_annotations,
          options,
          stack,
          diagnostics,
        ),
      })
    CommandKind::ForIn(clause) =>
      CommandKind::ForIn({
        ..clause,
        body: resolve_script_sources(
          clause.body,
          file_annotations,
          options,
          stack,
          diagnostics,
        ),
      })
    CommandKind::ForArithmetic(clause) =>
      CommandKind::ForArithmetic({
        ..clause,
        body: resolve_script_sources(
          clause.body,
          file_annotations,
          options,
          stack,
          diagnostics,
        ),
      })
    CommandKind::Select(clause) =>
      CommandKind::Select({
        ..clause,
        body: resolve_script_sources(
          clause.body,
          file_annotations,
          options,
          stack,
          diagnostics,
        ),
      })
    CommandKind::Case(clause) => {
      let items : Array[CaseItem] = []
      for item in clause.items {
        items.push({
          ..item,
          body: resolve_script_sources(
            item.body,
            file_annotations,
            options,
            stack,
            diagnostics,
          ),
        })
      }
      CommandKind::Case({ ..clause, items, })
    }
    CommandKind::Condition(condition) => CommandKind::Condition(condition)
    CommandKind::Arithmetic(arithmetic) => CommandKind::Arithmetic(arithmetic)
    CommandKind::Function(function_) =>
      CommandKind::Function({
        ..function_,
        body: resolve_command_sources(
          function_.body,
          file_annotations,
          active_annotations,
          options,
          stack,
          diagnostics,
        ),
      })
    CommandKind::CoProc(clause) =>
      CommandKind::CoProc({
        ..clause,
        body: resolve_command_sources(
          clause.body,
          file_annotations,
          active_annotations,
          options,
          stack,
          diagnostics,
        ),
      })
    CommandKind::BatsTest(clause) =>
      CommandKind::BatsTest({
        ..clause,
        body: resolve_script_sources(
          clause.body,
          file_annotations,
          options,
          stack,
          diagnostics,
        ),
      })
  }
  { ..command, kind: resolved_kind }
}

///|
fn resolve_pipeline_sources(
  pipeline : Pipeline,
  file_annotations : Array[Annotation],
  active_annotations : Array[Annotation],
  options : ParseOptions,
  stack : Array[String],
  diagnostics : Array[Diagnostic],
) -> Pipeline {
  let segments : Array[PipelineSegment] = []
  for segment in pipeline.segments {
    segments.push({
      ..segment,
      command: resolve_command_sources(
        segment.command,
        file_annotations,
        active_annotations,
        options,
        stack,
        diagnostics,
      ),
    })
  }
  { ..pipeline, segments, }
}

///|
fn resolve_and_or_sources(
  and_or : AndOrList,
  file_annotations : Array[Annotation],
  item_annotations : Array[Annotation],
  options : ParseOptions,
  stack : Array[String],
  diagnostics : Array[Diagnostic],
) -> AndOrList {
  let active_annotations = merge_annotations(file_annotations, item_annotations)
  let tail : Array[(AndOrOperator, Pipeline)] = []
  for pair in and_or.tail {
    tail.push(
      (
        pair.0,
        resolve_pipeline_sources(
          pair.1,
          file_annotations,
          active_annotations,
          options,
          stack,
          diagnostics,
        ),
      ),
    )
  }
  {
    ..and_or,
    head: resolve_pipeline_sources(
      and_or.head,
      file_annotations,
      active_annotations,
      options,
      stack,
      diagnostics,
    ),
    tail,
  }
}

///|
fn resolve_script_sources(
  script : Script,
  file_annotations : Array[Annotation],
  options : ParseOptions,
  stack : Array[String],
  diagnostics : Array[Diagnostic],
) -> Script {
  let items : Array[ListItem] = []
  for item in script.items {
    items.push({
      ..item,
      and_or: resolve_and_or_sources(
        item.and_or,
        file_annotations,
        item.annotations,
        options,
        stack,
        diagnostics,
      ),
    })
  }
  { ..script, items, }
}

///|
fn is_plain_identifier_text(text : String) -> Bool {
  if text == "" {
    return false
  }
  let view = text[:]
  if !is_name_start(view[0]) {
    return false
  }
  let mut i = 1
  while i < view.length() {
    if !is_name_part(view[i]) {
      return false
    }
    i += 1
  }
  true
}

///|
fn word_identifier_text(word : Word) -> String? {
  match word_plain_text(word) {
    Some(text) if is_plain_identifier_text(text) => Some(text)
    _ => None
  }
}

///|
fn push_unique_name(names : Array[String], name : String) -> Unit {
  if !names.contains(name) {
    names.push(name)
  }
}

///|
fn word_has_associative_flag(word : Word) -> Bool {
  match word_plain_text(word) {
    Some(text) if text.has_prefix("-") && text.contains("A") => true
    _ => false
  }
}

///|
fn collect_associative_names_from_array_index(
  index : ArrayIndex,
  names : Array[String],
) -> Unit {
  for part in index.parts {
    collect_associative_names_from_word_part(part, names)
  }
}

///|
fn collect_associative_names_from_word(
  word : Word,
  names : Array[String],
) -> Unit {
  for part in word.parts {
    collect_associative_names_from_word_part(part, names)
  }
}

///|
fn collect_associative_names_from_word_part(
  part : WordPart,
  names : Array[String],
) -> Unit {
  match part {
    WordPart::DoubleQuoted(parts) | WordPart::DollarDoubleQuoted(parts) =>
      for nested in parts {
        collect_associative_names_from_word_part(nested, names)
      }
    WordPart::BracedParameter(expansion) =>
      match expansion.index {
        Some(index) => collect_associative_names_from_array_index(index, names)
        None => ()
      }
    WordPart::BraceCommandSubstitution(_, script)
    | WordPart::CommandSubstitution(script)
    | WordPart::BackQuoted(script)
    | WordPart::ProcessSubstitution(_, script) =>
      collect_associative_names_from_script(script, names)
    WordPart::ArithmeticExpansion(expr) | WordPart::DollarBracket(expr) =>
      collect_associative_names_from_arithmetic_expr(expr, names)
    WordPart::ExtGlob(pattern) =>
      for alternative in pattern.alternatives {
        collect_associative_names_from_word(alternative, names)
      }
    WordPart::BraceExpansion(expansion) =>
      for element in expansion.elements {
        collect_associative_names_from_word(element, names)
      }
    _ => ()
  }
}

///|
fn collect_associative_names_from_arithmetic_expr(
  expr : ArithmeticExpr,
  names : Array[String],
) -> Unit {
  for token in expr.tokens {
    match token {
      ArithmeticToken::Variable(_, indexes) =>
        for index in indexes {
          collect_associative_names_from_array_index(index, names)
        }
      ArithmeticToken::Expansion(word) =>
        collect_associative_names_from_word(word, names)
      ArithmeticToken::Group(inner) =>
        collect_associative_names_from_arithmetic_expr(inner, names)
      _ => ()
    }
  }
}

///|
fn collect_associative_names_from_condition_expr(
  expr : ConditionExpr,
  names : Array[String],
) -> Unit {
  match expr {
    ConditionExpr::Word(word) =>
      collect_associative_names_from_word(word, names)
    ConditionExpr::Unary(_, _, word) =>
      collect_associative_names_from_word(word, names)
    ConditionExpr::Binary(_, _, left, right) => {
      collect_associative_names_from_word(left, names)
      collect_associative_names_from_word(right, names)
    }
    ConditionExpr::Group(inner) | ConditionExpr::Not(inner) =>
      collect_associative_names_from_condition_expr(inner, names)
    ConditionExpr::And(left, right) | ConditionExpr::Or(left, right) => {
      collect_associative_names_from_condition_expr(left, names)
      collect_associative_names_from_condition_expr(right, names)
    }
    ConditionExpr::Empty => ()
  }
}

///|
fn collect_associative_names_from_redirection(
  redirection : Redirection,
  names : Array[String],
) -> Unit {
  match redirection.target {
    RedirectionTarget::Word(word) =>
      collect_associative_names_from_word(word, names)
    RedirectionTarget::HereDoc(here_doc) =>
      match here_doc.parts {
        Some(parts) =>
          for part in parts {
            collect_associative_names_from_word_part(part, names)
          }
        None => ()
      }
  }
}

///|
fn collect_associative_names_from_assignment_value(
  value : AssignmentValue,
  names : Array[String],
) -> Unit {
  match value {
    AssignmentValue::Word(word) =>
      collect_associative_names_from_word(word, names)
    AssignmentValue::ArrayLiteral(elements) =>
      for element in elements {
        for index in element.indexes {
          collect_associative_names_from_array_index(index, names)
        }
        collect_associative_names_from_assignment_value(element.value, names)
      }
    AssignmentValue::Empty => ()
  }
}

///|
fn collect_associative_names_from_simple(
  simple : SimpleCommand,
  names : Array[String],
) -> Unit {
  if simple.words.length() == 0 {
    return
  }
  let command_name = match word_plain_text(simple.words[0]) {
    Some(name) => name
    None => {
      for assignment in simple.assignments {
        collect_associative_names_from_assignment_value(assignment.value, names)
      }
      for word in simple.words {
        collect_associative_names_from_word(word, names)
      }
      return
    }
  }
  let mut has_assoc_flag = false
  if command_name == "declare" ||
    command_name == "local" ||
    command_name == "typeset" {
    let mut i = 1
    while i < simple.words.length() {
      if word_has_associative_flag(simple.words[i]) {
        has_assoc_flag = true
        break
      }
      i += 1
    }
    if has_assoc_flag {
      for assignment in simple.assignments {
        push_unique_name(names, assignment.name)
      }
      i = 1
      while i < simple.words.length() {
        match word_plain_text(simple.words[i]) {
          Some(text) if text == "--" => ()
          Some(text) if text.has_prefix("-") => ()
          _ =>
            match word_identifier_text(simple.words[i]) {
              Some(name) => push_unique_name(names, name)
              None => ()
            }
        }
        i += 1
      }
    }
  }
  for assignment in simple.assignments {
    collect_associative_names_from_assignment_value(assignment.value, names)
  }
  for word in simple.words {
    collect_associative_names_from_word(word, names)
  }
}

///|
fn collect_associative_names_from_command(
  command : Command,
  names : Array[String],
) -> Unit {
  match command.kind {
    CommandKind::Simple(simple) =>
      collect_associative_names_from_simple(simple, names)
    CommandKind::Source(source) => {
      for assignment in source.assignments {
        collect_associative_names_from_assignment_value(assignment.value, names)
      }
      for option in source.options {
        collect_associative_names_from_word(option, names)
      }
      collect_associative_names_from_word(source.path, names)
      for arg in source.args {
        collect_associative_names_from_word(arg, names)
      }
      match source.included {
        Some(script) => collect_associative_names_from_script(script, names)
        None => ()
      }
    }
    CommandKind::Time(clause) => {
      for flag in clause.flags {
        collect_associative_names_from_word(flag, names)
      }
      collect_associative_names_from_pipeline(clause.body, names)
    }
    CommandKind::Subshell(script) | CommandKind::BraceGroup(script) =>
      collect_associative_names_from_script(script, names)
    CommandKind::If(clause) => {
      for arm in clause.arms {
        collect_associative_names_from_script(arm.condition, names)
        collect_associative_names_from_script(arm.body, names)
      }
      match clause.else_body {
        Some(script) => collect_associative_names_from_script(script, names)
        None => ()
      }
    }
    CommandKind::While(loop_) | CommandKind::Until(loop_) => {
      collect_associative_names_from_script(loop_.condition, names)
      collect_associative_names_from_script(loop_.body, names)
    }
    CommandKind::ForIn(clause) => {
      for value in clause.values {
        collect_associative_names_from_word(value, names)
      }
      collect_associative_names_from_script(clause.body, names)
    }
    CommandKind::ForArithmetic(clause) => {
      collect_associative_names_from_arithmetic_expr(clause.init, names)
      collect_associative_names_from_arithmetic_expr(clause.condition, names)
      collect_associative_names_from_arithmetic_expr(clause.step, names)
      collect_associative_names_from_script(clause.body, names)
    }
    CommandKind::Select(clause) => {
      for value in clause.values {
        collect_associative_names_from_word(value, names)
      }
      collect_associative_names_from_script(clause.body, names)
    }
    CommandKind::Case(clause) => {
      collect_associative_names_from_word(clause.word, names)
      for item in clause.items {
        for pattern in item.patterns {
          collect_associative_names_from_word(pattern, names)
        }
        collect_associative_names_from_script(item.body, names)
      }
    }
    CommandKind::Condition(condition) =>
      collect_associative_names_from_condition_expr(condition.expr, names)
    CommandKind::Arithmetic(arithmetic) =>
      collect_associative_names_from_arithmetic_expr(arithmetic.expr, names)
    CommandKind::Function(function_) =>
      collect_associative_names_from_command(function_.body, names)
    CommandKind::CoProc(clause) => {
      match clause.name {
        Some(name) => collect_associative_names_from_word(name, names)
        None => ()
      }
      collect_associative_names_from_command(clause.body, names)
    }
    CommandKind::BatsTest(clause) =>
      collect_associative_names_from_script(clause.body, names)
  }
  for redirection in command.redirects {
    collect_associative_names_from_redirection(redirection, names)
  }
}

///|
fn collect_associative_names_from_pipeline(
  pipeline : Pipeline,
  names : Array[String],
) -> Unit {
  for segment in pipeline.segments {
    collect_associative_names_from_command(segment.command, names)
  }
}

///|
fn collect_associative_names_from_and_or(
  and_or : AndOrList,
  names : Array[String],
) -> Unit {
  collect_associative_names_from_pipeline(and_or.head, names)
  for pair in and_or.tail {
    collect_associative_names_from_pipeline(pair.1, names)
  }
}

///|
fn collect_associative_names_from_script(
  script : Script,
  names : Array[String],
) -> Unit {
  for item in script.items {
    collect_associative_names_from_and_or(item.and_or, names)
  }
}

///|
fn normalize_array_index_for_name(
  index : ArrayIndex,
  name : String,
  associative_names : Array[String],
) -> ArrayIndex {
  if associative_names.contains(name) {
    parse_array_index(index.raw)
  } else {
    parse_arithmetic_index(index.raw)
  }
}

///|
fn normalize_array_indexes_for_name(
  indexes : Array[ArrayIndex],
  name : String,
  associative_names : Array[String],
) -> Array[ArrayIndex] {
  let normalized : Array[ArrayIndex] = []
  for index in indexes {
    normalized.push(
      normalize_array_index_for_name(index, name, associative_names),
    )
  }
  normalized
}

///|
fn normalize_condition_expr(
  expr : ConditionExpr,
  associative_names : Array[String],
) -> ConditionExpr {
  match expr {
    ConditionExpr::Word(word) =>
      ConditionExpr::Word(normalize_word(word, associative_names))
    ConditionExpr::Unary(op, op_span, word) =>
      ConditionExpr::Unary(op, op_span, normalize_word(word, associative_names))
    ConditionExpr::Binary(op, op_span, left, right) =>
      ConditionExpr::Binary(
        op,
        op_span,
        normalize_word(left, associative_names),
        normalize_word(right, associative_names),
      )
    ConditionExpr::Group(inner) =>
      ConditionExpr::Group(normalize_condition_expr(inner, associative_names))
    ConditionExpr::Not(inner) =>
      ConditionExpr::Not(normalize_condition_expr(inner, associative_names))
    ConditionExpr::And(left, right) =>
      ConditionExpr::And(
        normalize_condition_expr(left, associative_names),
        normalize_condition_expr(right, associative_names),
      )
    ConditionExpr::Or(left, right) =>
      ConditionExpr::Or(
        normalize_condition_expr(left, associative_names),
        normalize_condition_expr(right, associative_names),
      )
    ConditionExpr::Empty => ConditionExpr::Empty
  }
}

///|
fn normalize_arithmetic_expr(
  expr : ArithmeticExpr,
  associative_names : Array[String],
) -> ArithmeticExpr {
  let tokens : Array[ArithmeticToken] = []
  for token in expr.tokens {
    tokens.push(
      match token {
        ArithmeticToken::Variable(name, indexes) =>
          ArithmeticToken::Variable(
            name,
            normalize_array_indexes_for_name(indexes, name, associative_names),
          )
        ArithmeticToken::Expansion(word) =>
          ArithmeticToken::Expansion(normalize_word(word, associative_names))
        ArithmeticToken::Group(inner) =>
          ArithmeticToken::Group(
            normalize_arithmetic_expr(inner, associative_names),
          )
        _ => token
      },
    )
  }
  { ..expr, tokens, }
}

///|
fn normalize_parameter_expansion(
  expansion : ParameterExpansion,
  associative_names : Array[String],
) -> ParameterExpansion {
  let index = match expansion.index {
    Some(index) =>
      match expansion.name {
        Some(name) =>
          Some(normalize_array_index_for_name(index, name, associative_names))
        None => Some(index)
      }
    None => None
  }
  { ..expansion, index, }
}

///|
fn normalize_word_part(
  part : WordPart,
  associative_names : Array[String],
) -> WordPart {
  match part {
    WordPart::DoubleQuoted(parts) => {
      let normalized : Array[WordPart] = []
      for nested in parts {
        normalized.push(normalize_word_part(nested, associative_names))
      }
      WordPart::DoubleQuoted(normalized)
    }
    WordPart::DollarDoubleQuoted(parts) => {
      let normalized : Array[WordPart] = []
      for nested in parts {
        normalized.push(normalize_word_part(nested, associative_names))
      }
      WordPart::DollarDoubleQuoted(normalized)
    }
    WordPart::BracedParameter(expansion) =>
      WordPart::BracedParameter(
        normalize_parameter_expansion(expansion, associative_names),
      )
    WordPart::BraceCommandSubstitution(command, script) =>
      WordPart::BraceCommandSubstitution(
        command,
        normalize_array_indices_in_script(script, associative_names),
      )
    WordPart::CommandSubstitution(script) =>
      WordPart::CommandSubstitution(
        normalize_array_indices_in_script(script, associative_names),
      )
    WordPart::BackQuoted(script) =>
      WordPart::BackQuoted(
        normalize_array_indices_in_script(script, associative_names),
      )
    WordPart::ArithmeticExpansion(expr) =>
      WordPart::ArithmeticExpansion(
        normalize_arithmetic_expr(expr, associative_names),
      )
    WordPart::DollarBracket(expr) =>
      WordPart::DollarBracket(
        normalize_arithmetic_expr(expr, associative_names),
      )
    WordPart::ExtGlob(pattern) => {
      let alternatives : Array[Word] = []
      for alternative in pattern.alternatives {
        alternatives.push(normalize_word(alternative, associative_names))
      }
      WordPart::ExtGlob({ ..pattern, alternatives, })
    }
    WordPart::ProcessSubstitution(kind, script) =>
      WordPart::ProcessSubstitution(
        kind,
        normalize_array_indices_in_script(script, associative_names),
      )
    WordPart::BraceExpansion(expansion) => {
      let elements : Array[Word] = []
      for element in expansion.elements {
        elements.push(normalize_word(element, associative_names))
      }
      WordPart::BraceExpansion({ ..expansion, elements, })
    }
    _ => part
  }
}

///|
fn normalize_word(word : Word, associative_names : Array[String]) -> Word {
  let parts : Array[WordPart] = []
  for part in word.parts {
    parts.push(normalize_word_part(part, associative_names))
  }
  { ..word, parts, }
}

///|
fn normalize_assignment_value(
  value : AssignmentValue,
  parent_name : String,
  associative_names : Array[String],
) -> AssignmentValue {
  match value {
    AssignmentValue::Word(word) =>
      AssignmentValue::Word(normalize_word(word, associative_names))
    AssignmentValue::ArrayLiteral(elements) => {
      let normalized : Array[ArrayElement] = []
      for element in elements {
        normalized.push(
          normalize_array_element(element, parent_name, associative_names),
        )
      }
      AssignmentValue::ArrayLiteral(normalized)
    }
    AssignmentValue::Empty => AssignmentValue::Empty
  }
}

///|
fn normalize_array_element(
  element : ArrayElement,
  parent_name : String,
  associative_names : Array[String],
) -> ArrayElement {
  {
    ..element,
    indexes: normalize_array_indexes_for_name(
      element.indexes,
      parent_name,
      associative_names,
    ),
    value: normalize_assignment_value(
      element.value,
      parent_name,
      associative_names,
    ),
  }
}

///|
fn normalize_assignment(
  assignment : Assignment,
  associative_names : Array[String],
) -> Assignment {
  {
    ..assignment,
    indexes: normalize_array_indexes_for_name(
      assignment.indexes,
      assignment.name,
      associative_names,
    ),
    value: normalize_assignment_value(
      assignment.value,
      assignment.name,
      associative_names,
    ),
  }
}

///|
fn normalize_redirection(
  redirection : Redirection,
  associative_names : Array[String],
) -> Redirection {
  let target = match redirection.target {
    RedirectionTarget::Word(word) =>
      RedirectionTarget::Word(normalize_word(word, associative_names))
    RedirectionTarget::HereDoc(here_doc) => {
      let parts = match here_doc.parts {
        Some(parts) => {
          let normalized : Array[WordPart] = []
          for part in parts {
            normalized.push(normalize_word_part(part, associative_names))
          }
          Some(normalized)
        }
        None => None
      }
      RedirectionTarget::HereDoc({ ..here_doc, parts, })
    }
  }
  { ..redirection, target, }
}

///|
fn normalize_command(
  command : Command,
  associative_names : Array[String],
) -> Command {
  let redirects : Array[Redirection] = []
  for redirection in command.redirects {
    redirects.push(normalize_redirection(redirection, associative_names))
  }
  let kind = match command.kind {
    CommandKind::Simple(simple) => {
      let assignments : Array[Assignment] = []
      for assignment in simple.assignments {
        assignments.push(normalize_assignment(assignment, associative_names))
      }
      let words : Array[Word] = []
      for word in simple.words {
        words.push(normalize_word(word, associative_names))
      }
      CommandKind::Simple({ assignments, words })
    }
    CommandKind::Source(source) => {
      let assignments : Array[Assignment] = []
      for assignment in source.assignments {
        assignments.push(normalize_assignment(assignment, associative_names))
      }
      let options : Array[Word] = []
      for option in source.options {
        options.push(normalize_word(option, associative_names))
      }
      let args : Array[Word] = []
      for arg in source.args {
        args.push(normalize_word(arg, associative_names))
      }
      let included = match source.included {
        Some(script) =>
          Some(normalize_array_indices_in_script(script, associative_names))
        None => None
      }
      CommandKind::Source({
        ..source,
        assignments,
        options,
        path: normalize_word(source.path, associative_names),
        args,
        included,
      })
    }
    CommandKind::Time(clause) => {
      let flags : Array[Word] = []
      for flag in clause.flags {
        flags.push(normalize_word(flag, associative_names))
      }
      CommandKind::Time({
        flags,
        body: normalize_pipeline(clause.body, associative_names),
      })
    }
    CommandKind::Subshell(script) =>
      CommandKind::Subshell(
        normalize_array_indices_in_script(script, associative_names),
      )
    CommandKind::BraceGroup(script) =>
      CommandKind::BraceGroup(
        normalize_array_indices_in_script(script, associative_names),
      )
    CommandKind::If(clause) => {
      let arms : Array[IfArm] = []
      for arm in clause.arms {
        arms.push({
          condition: normalize_array_indices_in_script(
            arm.condition,
            associative_names,
          ),
          body: normalize_array_indices_in_script(arm.body, associative_names),
        })
      }
      let else_body = match clause.else_body {
        Some(script) =>
          Some(normalize_array_indices_in_script(script, associative_names))
        None => None
      }
      CommandKind::If({ arms, else_body })
    }
    CommandKind::While(loop_) =>
      CommandKind::While({
        condition: normalize_array_indices_in_script(
          loop_.condition,
          associative_names,
        ),
        body: normalize_array_indices_in_script(loop_.body, associative_names),
      })
    CommandKind::Until(loop_) =>
      CommandKind::Until({
        condition: normalize_array_indices_in_script(
          loop_.condition,
          associative_names,
        ),
        body: normalize_array_indices_in_script(loop_.body, associative_names),
      })
    CommandKind::ForIn(clause) => {
      let values : Array[Word] = []
      for value in clause.values {
        values.push(normalize_word(value, associative_names))
      }
      CommandKind::ForIn({
        ..clause,
        values,
        body: normalize_array_indices_in_script(clause.body, associative_names),
      })
    }
    CommandKind::ForArithmetic(clause) =>
      CommandKind::ForArithmetic({
        init: normalize_arithmetic_expr(clause.init, associative_names),
        condition: normalize_arithmetic_expr(
          clause.condition,
          associative_names,
        ),
        step: normalize_arithmetic_expr(clause.step, associative_names),
        body: normalize_array_indices_in_script(clause.body, associative_names),
      })
    CommandKind::Select(clause) => {
      let values : Array[Word] = []
      for value in clause.values {
        values.push(normalize_word(value, associative_names))
      }
      CommandKind::Select({
        ..clause,
        values,
        body: normalize_array_indices_in_script(clause.body, associative_names),
      })
    }
    CommandKind::Case(clause) => {
      let items : Array[CaseItem] = []
      for item in clause.items {
        let patterns : Array[Word] = []
        for pattern in item.patterns {
          patterns.push(normalize_word(pattern, associative_names))
        }
        items.push({
          ..item,
          patterns,
          body: normalize_array_indices_in_script(item.body, associative_names),
        })
      }
      CommandKind::Case({
        word: normalize_word(clause.word, associative_names),
        items,
      })
    }
    CommandKind::Condition(condition) =>
      CommandKind::Condition({
        ..condition,
        expr: normalize_condition_expr(condition.expr, associative_names),
      })
    CommandKind::Arithmetic(arithmetic) =>
      CommandKind::Arithmetic({
        ..arithmetic,
        expr: normalize_arithmetic_expr(arithmetic.expr, associative_names),
      })
    CommandKind::Function(function_) =>
      CommandKind::Function({
        ..function_,
        body: normalize_command(function_.body, associative_names),
      })
    CommandKind::CoProc(clause) =>
      CommandKind::CoProc({
        name: match clause.name {
          Some(name) => Some(normalize_word(name, associative_names))
          None => None
        },
        body: normalize_command(clause.body, associative_names),
      })
    CommandKind::BatsTest(clause) =>
      CommandKind::BatsTest({
        ..clause,
        body: normalize_array_indices_in_script(clause.body, associative_names),
      })
  }
  { ..command, kind, redirects }
}

///|
fn normalize_pipeline(
  pipeline : Pipeline,
  associative_names : Array[String],
) -> Pipeline {
  let segments : Array[PipelineSegment] = []
  for segment in pipeline.segments {
    segments.push({
      ..segment,
      command: normalize_command(segment.command, associative_names),
    })
  }
  { ..pipeline, segments, }
}

///|
fn normalize_and_or(
  and_or : AndOrList,
  associative_names : Array[String],
) -> AndOrList {
  let tail : Array[(AndOrOperator, Pipeline)] = []
  for pair in and_or.tail {
    tail.push((pair.0, normalize_pipeline(pair.1, associative_names)))
  }
  { ..and_or, head: normalize_pipeline(and_or.head, associative_names), tail }
}

///|
fn normalize_array_indices_in_script(
  script : Script,
  associative_names : Array[String],
) -> Script {
  let items : Array[ListItem] = []
  for item in script.items {
    items.push({
      ..item,
      and_or: normalize_and_or(item.and_or, associative_names),
    })
  }
  { ..script, items, }
}

///|
fn normalize_array_indices(script : Script) -> Script {
  let associative_names : Array[String] = []
  collect_associative_names_from_script(script, associative_names)
  normalize_array_indices_in_script(script, associative_names)
}

///|
fn validate_shebang(
  parser : Parser,
  has_bom : Bool,
  shebang : String?,
  annotations : Array[Annotation],
) -> Unit {
  if has_bom && !annotations_disable_code(annotations, Some(1082)) {
    parser.emit_diagnostic(
      DiagnosticSeverity::Error,
      initial_position(),
      "This file has a UTF-8 BOM. Remove it with: LC_CTYPE=C sed '1s/^...//' < yourscript .",
      Some(1082),
    )
  }
  if has_shell_annotation(annotations) {
    return
  }
  match shebang {
    Some(line) => {
      let shell = executable_from_shebang(line)
      match classify_shebang_shell(shell) {
        ShebangShellStatus::Supported => ()
        ShebangShellStatus::Unsupported =>
          if !annotations_disable_code(annotations, Some(1071)) {
            parser.emit_diagnostic(
              DiagnosticSeverity::Error,
              shebang_position(has_bom),
              "unsupported shebang shell '\{shell}'; parser only supports sh/bash/dash/ash/bats/ksh/oksh/'busybox sh'/'busybox ash' scripts",
              Some(1071),
            )
          }
        ShebangShellStatus::Unknown =>
          if !annotations_disable_code(annotations, Some(1008)) {
            parser.emit_diagnostic(
              DiagnosticSeverity::Error,
              shebang_position(has_bom),
              "unrecognized shebang shell '\{shell}'; add '# shellcheck shell=bash' to specify the shell",
              Some(1008),
            )
          }
      }
    }
    None => ()
  }
}

///|
fn parse_script_with_options_internal(
  source : String,
  options : ParseOptions,
  stack : Array[String],
) -> ParseReport {
  let parser = Parser::new(source.view(), options, stack)
  try {
    let (has_bom, shebang, annotations) = parser.parse_leading_metadata()
    parser.file_annotations = copy_annotations(annotations)
    validate_shebang(parser, has_bom, shebang, annotations)
    let script = parser.parse_script([], None)
    parser.skip_command_gaps()
    parser.ensure_no_pending_heredocs()
    if !parser.eof() {
      parser.diagnostics.push({
        span: span_at(parser.position()),
        severity: DiagnosticSeverity::Error,
        code: None,
        message: "unexpected trailing input",
      })
      return { script: None, diagnostics: parser.diagnostics }
    }
    let root = {
      span: { start: { offset: 0, line: 1, column: 1 }, end: script.span.end },
      has_bom,
      shebang,
      annotations,
      items: script.items,
    }
    let resolved = resolve_script_sources(
      root,
      root.annotations,
      options,
      stack,
      parser.diagnostics,
    )
    {
      script: Some(normalize_array_indices(resolved)),
      diagnostics: parser.diagnostics,
    }
  } catch {
    err => {
      match err {
        ParseError::Message(pos~, message~) => {
          for diagnostic in parser.diagnostics {
            if diagnostic.span.start == pos && diagnostic.message == message {
              return { script: None, diagnostics: parser.diagnostics }
            }
          }
          parser.diagnostics.push(parse_error_diagnostic(err))
        }
        _ => parser.diagnostics.push(parse_error_diagnostic(err))
      }
      { script: None, diagnostics: parser.diagnostics }
    }
  }
}

///|
fn nested_parse_blocks_include(diagnostics : Array[Diagnostic]) -> Bool {
  for diagnostic in diagnostics {
    match diagnostic.code {
      Some(1061) | Some(1062) => return true
      _ => ()
    }
  }
  false
}

///|
/// Prepends extra annotations to a parsed script.
pub fn merge_script_annotations(
  script : Script,
  annotations : Array[Annotation],
) -> Script {
  if annotations.length() == 0 {
    return script
  }
  { ..script, annotations: merge_annotations(script.annotations, annotations) }
}

///|
/// Parses shell source using explicit parser options.
///
/// The returned report may contain both a script and non-fatal diagnostics.
pub fn parse_script_with_options(
  source : String,
  options : ParseOptions,
) -> ParseReport {
  let stack : Array[String] = []
  match options.current_path {
    Some(path) => stack.push(path)
    None => ()
  }
  parse_script_with_options_internal(source, options, stack)
}

///|
/// Parses shell source with default parser options.
pub fn parse_script_report(source : String) -> ParseReport {
  parse_script_with_options(source, ParseOptions::default())
}

///|
/// Parses config-style annotations from a `.shellcheckrc` file or directive
/// stream.
pub fn parse_config_report(source : String) -> ConfigParseReport {
  let report = { annotations: [], diagnostics: [] }
  let options = ParseOptions::new(false, true, false, false, None, [], [])
  let mut offset = 0
  let mut line = 1
  for raw in source.split("\n") {
    let text = raw.to_string()
    if config_line_is_ignorable(text) {
      offset += text.length() + 1
      line += 1
      continue
    }
    let position : Position = { offset, line, column: 1 }
    let (annotations, diagnostics) = try {
      if is_shellcheck_annotation_comment(text) {
        parse_annotation_line(text, position, options)
      } else {
        parse_annotation_entries(text, position, options)
      }
    } catch {
      err => ([], [parse_error_diagnostic(err)])
    }
    for annotation in annotations {
      report.annotations.push(annotation)
    }
    for diagnostic in diagnostics {
      report.diagnostics.push(diagnostic)
    }
    offset += text.length() + 1
    line += 1
  }
  report
}

///|
/// Parses shell source and returns the first fatal parse error if any were
/// produced.
pub fn parse_script(source : String) -> Result[Script, ParseError] {
  let report = parse_script_report(source)
  for diagnostic in report.diagnostics {
    match diagnostic.severity {
      DiagnosticSeverity::Error => return Err(diagnostic_as_error(diagnostic))
      _ => ()
    }
  }
  match report.script {
    Some(script) => Ok(script)
    None =>
      match report.diagnostics.get(0) {
        Some(diagnostic) => Err(diagnostic_as_error(diagnostic))
        None =>
          Err(
            ParseError::Message(
              pos={ offset: 0, line: 1, column: 1 },
              message="parse failed",
            ),
          )
      }
  }
}

///|
fn config_line_is_ignorable(line : String) -> Bool {
  let view = line[:]
  let mut start = 0
  while start < view.length() &&
        (view[start] == ' ' || view[start] == '\t' || view[start] == '\r') {
    start += 1
  }
  if start >= view.length() {
    return true
  }
  view[start] == '#' &&
  !is_shellcheck_annotation_comment(line.view(start_offset=start).to_string())
}
