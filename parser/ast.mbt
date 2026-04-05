///|
/// A concrete location in the original source text.
pub struct Position {
  offset : Int
  line : Int
  column : Int
} derive(Eq, Debug)

///|
/// Constructs a source position from byte offset, line, and column values.
pub fn Position::new(offset : Int, line : Int, column : Int) -> Position {
  { offset, line, column }
}

///|
/// A source range with start and end positions.
pub struct Span {
  start : Position
  end : Position
} derive(Eq, Debug)

///|
/// Constructs a source span from two positions.
pub fn Span::new(start : Position, end_ : Position) -> Span {
  { start, end: end_ }
}

///|
/// Severity used by parser and config diagnostics.
pub enum DiagnosticSeverity {
  Error
  Warning
  Info
} derive(Eq, Debug)

///|
/// A diagnostic produced while parsing shell source or config directives.
pub struct Diagnostic {
  span : Span
  severity : DiagnosticSeverity
  code : Int?
  message : String
} derive(Eq, Debug)

///|
/// Options that control sourced-file resolution and parser behavior.
pub struct ParseOptions {
  sourced : Bool
  allow_inline_external_sources : Bool
  external_sources : Bool
  follow_sources : Bool
  current_path : String?
  source_paths : Array[String]
  source_files : Array[(String, String)]
} derive(Eq, Debug)

///|
/// A parse result that preserves both the parsed script and any diagnostics.
pub struct ParseReport {
  script : Script?
  diagnostics : Array[Diagnostic]
} derive(Eq, Debug)

///|
/// The result of parsing config-style annotations from comments or rc files.
pub struct ConfigParseReport {
  annotations : Array[Annotation]
  diagnostics : Array[Diagnostic]
} derive(Eq, Debug)

///|
/// Returns the default parser options.
pub fn ParseOptions::default() -> ParseOptions {
  {
    sourced: false,
    allow_inline_external_sources: false,
    external_sources: false,
    follow_sources: false,
    current_path: None,
    source_paths: [],
    source_files: [],
  }
}

///|
/// Constructs parser options explicitly.
pub fn ParseOptions::new(
  sourced : Bool,
  allow_inline_external_sources : Bool,
  external_sources : Bool,
  follow_sources : Bool,
  current_path : String?,
  source_paths : Array[String],
  source_files : Array[(String, String)],
) -> ParseOptions {
  {
    sourced,
    allow_inline_external_sources,
    external_sources,
    follow_sources,
    current_path,
    source_paths,
    source_files,
  }
}

///|
/// The root AST node for an entire shell input.
pub struct Script {
  span : Span
  has_bom : Bool
  shebang : String?
  annotations : Array[Annotation]
  items : Array[ListItem]
} derive(Eq, Debug)

///|
/// ShellCheck-style directives extracted from comments.
pub enum Annotation {
  Disable(String)
  Enable(String)
  Shell(String)
  Source(String)
  SourcePath(String)
  ExternalSources(Bool)
  ExtendedAnalysis(Bool)
} derive(Eq, Debug)

///|
/// One top-level list item together with its attached annotations.
pub struct ListItem {
  span : Span
  annotations : Array[Annotation]
  and_or : AndOrList
  terminator : Terminator?
} derive(Eq, Debug)

///|
/// Terminators that can follow a list item.
pub enum Terminator {
  Sequential
  Background
} derive(Eq, Debug)

///|
/// A pipeline chain connected by `&&` and `||`.
pub struct AndOrList {
  span : Span
  head : Pipeline
  tail : Array[(AndOrOperator, Pipeline)]
} derive(Eq, Debug)

///|
/// Logical operators that connect pipelines inside an and-or list.
pub enum AndOrOperator {
  AndIf
  OrIf
} derive(Eq, Debug)

///|
/// A pipeline together with the operators between its segments.
pub struct Pipeline {
  span : Span
  segments : Array[PipelineSegment]
  operators : Array[PipeOperator]
} derive(Eq, Debug)

///|
/// One stage in a pipeline, including any leading `!` negation.
pub struct PipelineSegment {
  span : Span
  bangs : Int
  command : Command
} derive(Eq, Debug)

///|
/// Pipe operators supported by the parser.
pub enum PipeOperator {
  Pipe
  PipeAndStderr
} derive(Eq, Debug)

///|
/// A parsed command together with its trailing redirections.
pub struct Command {
  span : Span
  kind : CommandKind
  redirects : Array[Redirection]
} derive(Eq, Debug)

///|
/// All command forms recognized by the parser.
pub enum CommandKind {
  Simple(SimpleCommand)
  Source(SourceCommand)
  Time(TimeClause)
  Subshell(Script)
  BraceGroup(Script)
  If(IfClause)
  While(LoopClause)
  Until(LoopClause)
  ForIn(ForClause)
  ForArithmetic(ArithmeticForClause)
  Select(SelectClause)
  Case(CaseClause)
  Condition(ConditionCommand)
  Arithmetic(ArithmeticCommand)
  Function(FunctionDef)
  CoProc(CoProcClause)
  BatsTest(BatsTestClause)
} derive(Eq, Debug)

///|
/// A simple command consisting of assignments and ordinary words.
pub struct SimpleCommand {
  assignments : Array[Assignment]
  words : Array[Word]
} derive(Eq, Debug)

///|
/// A parsed `.` or `source` command, optionally with resolved include data.
pub struct SourceCommand {
  assignments : Array[Assignment]
  keyword : String
  options : Array[Word]
  path : Word
  args : Array[Word]
  resolved_path : String?
  included : Script?
} derive(Eq, Debug)

///|
/// A tokenized shell arithmetic expression.
pub struct ArithmeticExpr {
  raw : String
  tokens : Array[ArithmeticToken]
} derive(Eq, Debug)

///|
/// One token inside an arithmetic expression.
pub enum ArithmeticToken {
  Literal(String)
  Operator(String)
  Variable(String, Array[ArrayIndex])
  Expansion(Word)
  Group(ArithmeticExpr)
} derive(Eq, Debug)

///|
/// An array index as written in shell syntax.
pub struct ArrayIndex {
  raw : String
  parts : Array[WordPart]
  arithmetic : ArithmeticExpr?
} derive(Eq, Debug)

///|
/// The `time` reserved word together with its flags and body.
pub struct TimeClause {
  flags : Array[Word]
  body : Pipeline
} derive(Eq, Debug)

///|
/// A shell variable assignment.
pub struct Assignment {
  span : Span
  name : String
  indexes : Array[ArrayIndex]
  append : Bool
  value : AssignmentValue
} derive(Eq, Debug)

///|
/// Possible right-hand sides of an assignment.
pub enum AssignmentValue {
  Empty
  Word(Word)
  ArrayLiteral(Array[ArrayElement])
} derive(Eq, Debug)

///|
/// One element in an array literal assignment.
pub struct ArrayElement {
  indexes : Array[ArrayIndex]
  append : Bool
  value : AssignmentValue
} derive(Eq, Debug)

///|
/// A parsed `if` / `elif` / `else` clause.
pub struct IfClause {
  arms : Array[IfArm]
  else_body : Script?
} derive(Eq, Debug)

///|
/// One conditional arm inside an `if` clause.
pub struct IfArm {
  condition : Script
  body : Script
} derive(Eq, Debug)

///|
/// The shared representation of `while` and `until` loops.
pub struct LoopClause {
  condition : Script
  body : Script
} derive(Eq, Debug)

///|
/// A `for name in ...` loop.
pub struct ForClause {
  name : String
  values : Array[Word]
  body : Script
} derive(Eq, Debug)

///|
/// A C-style arithmetic `for ((...))` loop.
pub struct ArithmeticForClause {
  init : ArithmeticExpr
  condition : ArithmeticExpr
  step : ArithmeticExpr
  body : Script
} derive(Eq, Debug)

///|
/// A Bash `select` loop.
pub struct SelectClause {
  name : String
  values : Array[Word]
  body : Script
} derive(Eq, Debug)

///|
/// A parsed `case` command.
pub struct CaseClause {
  word : Word
  items : Array[CaseItem]
} derive(Eq, Debug)

///|
/// One pattern arm inside a `case` command.
pub struct CaseItem {
  patterns : Array[Word]
  body : Script
  separator : CaseSeparator
} derive(Eq, Debug)

///|
/// The terminator used after a `case` arm body.
pub enum CaseSeparator {
  Break
  FallThrough
  Continue
} derive(Eq, Debug)

///|
/// The syntactic form of a condition command.
pub enum ConditionKind {
  SingleBracket
  DoubleBracket
} derive(Eq, Debug)

///|
/// A parsed `[` or `[[` condition command.
pub struct ConditionCommand {
  kind : ConditionKind
  raw : String
  expr : ConditionExpr
} derive(Eq, Debug)

///|
/// The expression tree produced for a condition command.
pub enum ConditionExpr {
  Empty
  Word(Word)
  Unary(String, Word)
  Binary(String, Word, Word)
  Group(ConditionExpr)
  Not(ConditionExpr)
  And(ConditionExpr, ConditionExpr)
  Or(ConditionExpr, ConditionExpr)
} derive(Eq, Debug)

///|
/// A standalone arithmetic command such as `((expr))`.
pub struct ArithmeticCommand {
  raw : String
  expr : ArithmeticExpr
} derive(Eq, Debug)

///|
/// A Bash `coproc` clause.
pub struct CoProcClause {
  name : Word?
  body : Command
} derive(Eq, Debug)

///|
/// A Bats `@test` clause.
pub struct BatsTestClause {
  name : String
  body : Script
} derive(Eq, Debug)

///|
/// A shell function definition.
pub struct FunctionDef {
  name : String
  uses_keyword : Bool
  has_parentheses : Bool
  body : Command
} derive(Eq, Debug)

///|
/// A parsed IO redirection attached to a command.
pub struct Redirection {
  span : Span
  source : RedirectionSource?
  op : RedirectionOperator
  target : RedirectionTarget
} derive(Eq, Debug)

///|
/// The explicit source FD or pseudo-source of a redirection.
pub enum RedirectionSource {
  Fd(Int)
  Named(String)
  All
} derive(Eq, Debug)

///|
/// Redirection operators supported by the parser.
pub enum RedirectionOperator {
  Read
  Write
  Append
  ReadWrite
  Clobber
  HereDoc
  HereDocStrip
  HereString
  DupInput
  DupOutput
} derive(Eq, Debug)

///|
/// The target of a redirection.
pub enum RedirectionTarget {
  Word(Word)
  HereDoc(HereDoc)
} derive(Eq, Debug)

///|
/// A parsed here-document body and delimiter metadata.
pub struct HereDoc {
  delimiter : String
  quoted : Bool
  strip_tabs : Bool
  body : String
  parts : Array[WordPart]?
} derive(Eq, Debug)

///|
/// An extended glob pattern such as `@(a|b)`.
pub struct ExtGlobPattern {
  raw : String
  operator : String
  alternatives : Array[Word]
} derive(Eq, Debug)

///|
/// A brace expansion such as `{a,b}`.
pub struct BraceExpansion {
  raw : String
  elements : Array[Word]
} derive(Eq, Debug)

///|
/// A shell word together with its parsed parts.
pub struct Word {
  span : Span
  source : String
  parts : Array[WordPart]
} derive(Eq, Debug)

///|
/// The building blocks that make up a parsed shell word.
pub enum WordPart {
  Literal(String)
  SingleQuoted(String)
  DoubleQuoted(Array[WordPart])
  DollarDoubleQuoted(Array[WordPart])
  DollarSingleQuoted(String)
  Parameter(String)
  SpecialParameter(String)
  BracedParameter(ParameterExpansion)
  BraceCommandSubstitution(Bool, Script)
  CommandSubstitution(Script)
  BackQuoted(Script)
  ArithmeticExpansion(ArithmeticExpr)
  DollarBracket(ArithmeticExpr)
  ExtGlob(ExtGlobPattern)
  ProcessSubstitution(String, Script)
  BraceExpansion(BraceExpansion)
  Glob(String)
} derive(Eq, Debug)

///|
/// A braced parameter expansion such as `${name:-default}`.
pub struct ParameterExpansion {
  raw : String
  length_prefix : Bool
  indirect : Bool
  name : String?
  index : ArrayIndex?
  operator : ParameterOperator?
} derive(Eq, Debug)

///|
/// The operator applied within a parameter expansion.
pub enum ParameterOperator {
  Slice(String, String?)
  DefaultValue(String)
  AssignDefault(String)
  ErrorValue(String)
  AlternateValue(String)
  Names(ParameterNamesMode)
  RemoveShortestPrefix(String)
  RemoveLongestPrefix(String)
  RemoveShortestSuffix(String)
  RemoveLongestSuffix(String)
  Replace(ParameterReplaceMode, String, String?)
  Transform(String)
  CaseModify(ParameterCaseMode, String?)
  Raw(String)
} derive(Eq, Debug)

///|
/// Replacement modes for `${var/pat/repl}` expansions.
pub enum ParameterReplaceMode {
  First
  All
  Prefix
  Suffix
} derive(Eq, Debug)

///|
/// Name-list modes for `${!prefix*}` and `${!prefix@}`.
pub enum ParameterNamesMode {
  Star
  At
} derive(Eq, Debug)

///|
/// Case-modification modes for `${var^^}`-style expansions.
pub enum ParameterCaseMode {
  UpperFirst
  UpperAll
  LowerFirst
  LowerAll
  ToggleFirst
  ToggleAll
} derive(Eq, Debug)
