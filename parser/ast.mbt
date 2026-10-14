///|
/// A concrete location in the original source text.
pub struct Position {
  offset : Int32
  line : Int32
  column : Int32
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend Position with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Position with Debug::{to_repr}

///|
/// Constructs a source position from byte offset, line, and column values.
pub fn Position::new(offset : Int32, line : Int32, column : Int32) -> Position {
  { offset, line, column, }
}

///|
/// A source range with start and end positions.
pub struct Span {
  start : Position
  end : Position
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend Span with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Span with Debug::{to_repr}

///|
/// Constructs a source span from two positions.
pub fn Span::new(start : Position, end_ : Position) -> Span {
  { start, end: end_, }
}

///|
/// Severity used by parser and config diagnostics.
pub enum DiagnosticSeverity {
  Error
  Warning
  Info
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend DiagnosticSeverity with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend DiagnosticSeverity with Debug::{to_repr}

///|
/// A diagnostic produced while parsing shell source or config directives.
pub struct Diagnostic {
  span : Span
  severity : DiagnosticSeverity
  code : Int32?
  message : String
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend Diagnostic with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Diagnostic with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend ParseOptions with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ParseOptions with Debug::{to_repr}

///|
/// A parse result that preserves both the parsed script and any diagnostics.
pub struct ParseReport {
  script : Script?
  diagnostics : Array[Diagnostic]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ParseReport with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ParseReport with Debug::{to_repr}

///|
/// The result of parsing config-style annotations from comments or rc files.
pub struct ConfigParseReport {
  annotations : Array[Annotation]
  diagnostics : Array[Diagnostic]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ConfigParseReport with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ConfigParseReport with Debug::{to_repr}

///|
// CHECK THIS: THUNK

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
#deprecated
#doc(hidden)
pub extend Script with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Script with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend Annotation with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Annotation with Debug::{to_repr}

///|
/// One top-level list item together with its attached annotations.
pub struct ListItem {
  span : Span
  annotations : Array[Annotation]
  and_or : AndOrList
  terminator : Terminator?
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ListItem with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ListItem with Debug::{to_repr}

///|
/// Terminators that can follow a list item.
pub enum Terminator {
  Sequential
  Background
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend Terminator with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Terminator with Debug::{to_repr}

///|
/// A pipeline chain connected by `&&` and `||`.
pub struct AndOrList {
  span : Span
  head : Pipeline
  tail : Array[(AndOrOperator, Pipeline)]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend AndOrList with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend AndOrList with Debug::{to_repr}

///|
/// Logical operators that connect pipelines inside an and-or list.
pub enum AndOrOperator {
  AndIf
  OrIf
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend AndOrOperator with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend AndOrOperator with Debug::{to_repr}

///|
/// A pipeline together with the operators between its segments.
pub struct Pipeline {
  span : Span
  segments : Array[PipelineSegment]
  operators : Array[PipeOperator]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend Pipeline with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Pipeline with Debug::{to_repr}

///|
/// One stage in a pipeline, including any leading `!` negation.
pub struct PipelineSegment {
  span : Span
  bangs : Int32
  command : Command
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend PipelineSegment with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend PipelineSegment with Debug::{to_repr}

///|
/// Pipe operators supported by the parser.
pub enum PipeOperator {
  Pipe
  PipeAndStderr
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend PipeOperator with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend PipeOperator with Debug::{to_repr}

///|
/// A parsed command together with its trailing redirections.
pub struct Command {
  span : Span
  kind : CommandKind
  redirects : Array[Redirection]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend Command with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Command with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend CommandKind with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CommandKind with Debug::{to_repr}

///|
/// A simple command consisting of assignments and ordinary words.
pub struct SimpleCommand {
  assignments : Array[Assignment]
  words : Array[Word]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend SimpleCommand with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend SimpleCommand with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend SourceCommand with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend SourceCommand with Debug::{to_repr}

///|
/// A tokenized shell arithmetic expression.
pub struct ArithmeticExpr {
  raw : String
  tokens : Array[ArithmeticToken]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ArithmeticExpr with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ArithmeticExpr with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend ArithmeticToken with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ArithmeticToken with Debug::{to_repr}

///|
/// An array index as written in shell syntax.
pub struct ArrayIndex {
  raw : String
  parts : Array[WordPart]
  arithmetic : ArithmeticExpr?
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ArrayIndex with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ArrayIndex with Debug::{to_repr}

///|
/// The `time` reserved word together with its flags and body.
pub struct TimeClause {
  flags : Array[Word]
  body : Pipeline
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend TimeClause with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend TimeClause with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend Assignment with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Assignment with Debug::{to_repr}

///|
/// Possible right-hand sides of an assignment.
pub enum AssignmentValue {
  Empty
  Word(Word)
  ArrayLiteral(Array[ArrayElement])
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend AssignmentValue with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend AssignmentValue with Debug::{to_repr}

///|
/// One element in an array literal assignment.
pub struct ArrayElement {
  indexes : Array[ArrayIndex]
  append : Bool
  value : AssignmentValue
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ArrayElement with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ArrayElement with Debug::{to_repr}

///|
/// A parsed `if` / `elif` / `else` clause.
pub struct IfClause {
  arms : Array[IfArm]
  else_body : Script?
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend IfClause with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend IfClause with Debug::{to_repr}

///|
/// One conditional arm inside an `if` clause.
pub struct IfArm {
  condition : Script
  body : Script
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend IfArm with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend IfArm with Debug::{to_repr}

///|
/// The shared representation of `while` and `until` loops.
pub struct LoopClause {
  condition : Script
  body : Script
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend LoopClause with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend LoopClause with Debug::{to_repr}

///|
/// A `for name in ...` loop.
pub struct ForClause {
  name : String
  values : Array[Word]
  body : Script
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ForClause with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ForClause with Debug::{to_repr}

///|
/// A C-style arithmetic `for ((...))` loop.
pub struct ArithmeticForClause {
  init : ArithmeticExpr
  condition : ArithmeticExpr
  step : ArithmeticExpr
  body : Script
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ArithmeticForClause with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ArithmeticForClause with Debug::{to_repr}

///|
/// A Bash `select` loop.
pub struct SelectClause {
  name : String
  values : Array[Word]
  body : Script
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend SelectClause with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend SelectClause with Debug::{to_repr}

///|
/// A parsed `case` command.
pub struct CaseClause {
  word : Word
  items : Array[CaseItem]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CaseClause with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CaseClause with Debug::{to_repr}

///|
/// One pattern arm inside a `case` command.
pub struct CaseItem {
  patterns : Array[Word]
  body : Script
  separator : CaseSeparator
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CaseItem with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CaseItem with Debug::{to_repr}

///|
/// The terminator used after a `case` arm body.
pub enum CaseSeparator {
  Break
  FallThrough
  Continue
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CaseSeparator with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CaseSeparator with Debug::{to_repr}

///|
/// The syntactic form of a condition command.
pub enum ConditionKind {
  SingleBracket
  DoubleBracket
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ConditionKind with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ConditionKind with Debug::{to_repr}

///|
/// A parsed `[` or `[[` condition command.
pub struct ConditionCommand {
  kind : ConditionKind
  raw : String
  expr : ConditionExpr
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ConditionCommand with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ConditionCommand with Debug::{to_repr}

///|
/// One logical operator inside a condition expression.
pub struct ConditionLogicalOperator {
  text : String
  span : Span
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ConditionLogicalOperator with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ConditionLogicalOperator with Debug::{to_repr}

///|
/// The expression tree produced for a condition command.
pub enum ConditionExpr {
  Empty
  Word(Word)
  Unary(String, Span, Word)
  Binary(String, Span, Word, Word)
  Group(ConditionExpr)
  Not(ConditionExpr)
  And(ConditionLogicalOperator, ConditionExpr, ConditionExpr)
  Or(ConditionLogicalOperator, ConditionExpr, ConditionExpr)
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ConditionExpr with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ConditionExpr with Debug::{to_repr}

///|
/// A standalone arithmetic command such as `((expr))`.
pub struct ArithmeticCommand {
  raw : String
  expr : ArithmeticExpr
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ArithmeticCommand with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ArithmeticCommand with Debug::{to_repr}

///|
/// A Bash `coproc` clause.
pub struct CoProcClause {
  name : Word?
  body : Command
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CoProcClause with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CoProcClause with Debug::{to_repr}

///|
/// A Bats `@test` clause.
pub struct BatsTestClause {
  name : String
  body : Script
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend BatsTestClause with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend BatsTestClause with Debug::{to_repr}

///|
/// A shell function definition.
pub struct FunctionDef {
  name : String
  uses_keyword : Bool
  has_parentheses : Bool
  body : Command
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend FunctionDef with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend FunctionDef with Debug::{to_repr}

///|
/// A parsed IO redirection attached to a command.
pub struct Redirection {
  span : Span
  source : RedirectionSource?
  op : RedirectionOperator
  target : RedirectionTarget
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend Redirection with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Redirection with Debug::{to_repr}

///|
/// The explicit source FD or pseudo-source of a redirection.
pub enum RedirectionSource {
  Fd(Int32)
  Named(String)
  All
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend RedirectionSource with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend RedirectionSource with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend RedirectionOperator with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend RedirectionOperator with Debug::{to_repr}

///|
/// The target of a redirection.
pub enum RedirectionTarget {
  Word(Word)
  HereDoc(HereDoc)
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend RedirectionTarget with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend RedirectionTarget with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend HereDoc with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend HereDoc with Debug::{to_repr}

///|
/// An extended glob pattern such as `@(a|b)`.
pub struct ExtGlobPattern {
  raw : String
  operator : String
  alternatives : Array[Word]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ExtGlobPattern with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ExtGlobPattern with Debug::{to_repr}

///|
/// A brace expansion such as `{a,b}`.
pub struct BraceExpansion {
  raw : String
  elements : Array[Word]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend BraceExpansion with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend BraceExpansion with Debug::{to_repr}

///|
/// A shell word together with its parsed parts.
pub struct Word {
  span : Span
  source : String
  parts : Array[WordPart]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend Word with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Word with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend WordPart with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend WordPart with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend ParameterExpansion with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ParameterExpansion with Debug::{to_repr}

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
#deprecated
#doc(hidden)
pub extend ParameterOperator with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ParameterOperator with Debug::{to_repr}

///|
/// Replacement modes for `${var/pat/repl}` expansions.
pub enum ParameterReplaceMode {
  First
  All
  Prefix
  Suffix
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ParameterReplaceMode with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ParameterReplaceMode with Debug::{to_repr}

///|
/// Name-list modes for `${!prefix*}` and `${!prefix@}`.
pub enum ParameterNamesMode {
  Star
  At
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend ParameterNamesMode with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ParameterNamesMode with Debug::{to_repr}

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

///|
#deprecated
#doc(hidden)
pub extend ParameterCaseMode with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend ParameterCaseMode with Debug::{to_repr}
