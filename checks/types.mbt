///|
/// Severity levels emitted by low-level lint checks before the checker layer
/// remaps them into its public reporting model.
#warnings("-deprecated_syntax")
pub enum CheckSeverity {
  Error
  Warning
  Info
  Style
} derive(Eq, Show, Debug)

///|
/// A single lint diagnostic produced by the `checks` package.
pub struct CheckDiagnostic {
  span : @parser.Span
  severity : CheckSeverity
  code : Int
  message : String
  fix : @fixer.Fix?
} derive(Eq, Debug)

///|
/// Static metadata describing a supported ShellCheck-style rule.
pub struct CheckDescription {
  code : Int
  severity : CheckSeverity
  category : String
  summary : String
} derive(Eq, Debug)

///|
/// Human-readable documentation for an optional check toggle.
pub struct OptionalCheckInfo {
  name : String
  desc : String
  example : String
  fix : String
} derive(Eq, Debug)

///|
/// Options that control how AST-level checks are executed.
pub struct CheckOptions {
  shell_override : @semantics.ShellDialect?
  filename : String?
  extended_analysis : Bool
  optional_checks : Array[String]
} derive(Eq, Debug)

///|
priv struct CheckSuiteRegistration {
  descriptions : Array[CheckDescription]
  run : (@parser.Script, @semantics.ShellDialect, Array[CheckDiagnostic]) -> Unit
}

///|
priv struct ToggleableCheckSuiteRegistration {
  name : String
  descriptions : Array[CheckDescription]
  run : (@parser.Script, @semantics.ShellDialect, Array[CheckDiagnostic]) -> Unit
}

///|
priv struct OptionalCheckRegistration {
  info : OptionalCheckInfo
  description : CheckDescription
  run : (@parser.Script, @semantics.ShellDialect, Array[CheckDiagnostic]) -> Unit
}

///|
// CHECK THIS: THUNK

///|
/// Returns the default options for running AST-level checks.
pub fn CheckOptions::default() -> CheckOptions {
  {
    shell_override: None,
    filename: None,
    extended_analysis: false,
    optional_checks: [],
  }
}

///|
/// Returns a copy of the options with extended analysis enabled or disabled.
pub fn CheckOptions::with_extended_analysis(
  self : CheckOptions,
  extended_analysis : Bool,
) -> CheckOptions {
  { ..self, extended_analysis, }
}

///|
/// Returns a copy of the options with additional optional checks enabled.
pub fn CheckOptions::with_optional_checks(
  self : CheckOptions,
  optional_checks : Array[String],
) -> CheckOptions {
  { ..self, optional_checks, }
}

///|
fn check_diagnostic(
  span : @parser.Span,
  severity : CheckSeverity,
  code : Int,
  message : String,
) -> CheckDiagnostic {
  { span, severity, code, message, fix: None }
}

///|
fn check_diagnostic_with_fix(
  span : @parser.Span,
  severity : CheckSeverity,
  code : Int,
  message : String,
  fix : @fixer.Fix,
) -> CheckDiagnostic {
  { span, severity, code, message, fix: Some(fix) }
}

///|
fn push_diagnostic(
  diagnostics : Array[CheckDiagnostic],
  span : @parser.Span,
  severity : CheckSeverity,
  code : Int,
  message : String,
) -> Unit {
  diagnostics.push(check_diagnostic(span, severity, code, message))
}

///|
fn push_diagnostic_with_fix(
  diagnostics : Array[CheckDiagnostic],
  span : @parser.Span,
  severity : CheckSeverity,
  code : Int,
  message : String,
  fix : @fixer.Fix,
) -> Unit {
  diagnostics.push(
    check_diagnostic_with_fix(span, severity, code, message, fix),
  )
}
