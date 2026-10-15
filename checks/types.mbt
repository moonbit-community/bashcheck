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
#deprecated
#doc(hidden)
pub extend CheckSeverity with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CheckSeverity with Show::{to_string, output}

///|
#deprecated
#doc(hidden)
pub extend CheckSeverity with Debug::{to_repr}

///|
/// A single lint diagnostic produced by the `checks` package.
pub struct CheckDiagnostic {
  span : @parser.Span
  severity : CheckSeverity
  code : Int32
  message : String
  fix : @fixer.Fix?
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend CheckDiagnostic with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend CheckDiagnostic with Debug::{to_repr}

///|
/// Human-readable documentation for an optional check toggle.
pub struct OptionalCheckInfo {
  name : String
  desc : String
  example : String
  fix : String
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend OptionalCheckInfo with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend OptionalCheckInfo with Debug::{to_repr}

///|
priv struct CheckSuiteRegistration {
  run : (@parser.Script, @semantics.ShellDialect, Array[CheckDiagnostic]) -> Unit
}

///|
priv struct ToggleableCheckSuiteRegistration {
  name : String
  run : (@parser.Script, @semantics.ShellDialect, Array[CheckDiagnostic]) -> Unit
}

///|
priv struct OptionalCheckRegistration {
  info : OptionalCheckInfo
  run : (@parser.Script, @semantics.ShellDialect, Array[CheckDiagnostic]) -> Unit
}

///|
// CHECK THIS: THUNK

///|
fn check_diagnostic(
  span : @parser.Span,
  severity : CheckSeverity,
  code : Int32,
  message : String,
) -> CheckDiagnostic {
  { span, severity, code, message, fix: None, }
}

///|
fn check_diagnostic_with_fix(
  span : @parser.Span,
  severity : CheckSeverity,
  code : Int32,
  message : String,
  fix : @fixer.Fix,
) -> CheckDiagnostic {
  { span, severity, code, message, fix: Some(fix), }
}

///|
fn push_diagnostic(
  diagnostics : Array[CheckDiagnostic],
  span : @parser.Span,
  severity : CheckSeverity,
  code : Int32,
  message : String,
) -> Unit {
  diagnostics.push(check_diagnostic(span, severity, code, message))
}

///|
fn push_diagnostic_with_fix(
  diagnostics : Array[CheckDiagnostic],
  span : @parser.Span,
  severity : CheckSeverity,
  code : Int32,
  message : String,
  fix : @fixer.Fix,
) -> Unit {
  diagnostics.push(
    check_diagnostic_with_fix(span, severity, code, message, fix),
  )
}
