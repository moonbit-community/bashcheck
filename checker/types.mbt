///|
/// Severity levels used by the public checker API after parse and lint
/// diagnostics have been normalized into a single model.
#warnings("-deprecated_syntax")
pub enum DiagnosticSeverity {
  Error
  Warning
  Info
  Style
} derive(Eq, Show, Debug)

///|
/// End-to-end checker configuration.
///
/// `CheckSpec` controls filename context, shell selection, diagnostic filters,
/// config loading, and whether optional or extended analyses are enabled.
pub struct CheckSpec {
  filename : String?
  check_sourced : Bool
  ignore_rc : Bool
  shell_override : @semantics.ShellDialect?
  fallback_shell : @semantics.ShellDialect?
  execution_mode : @semantics.ExecutionMode
  min_severity : DiagnosticSeverity
  include_codes : Array[Int]
  exclude_codes : Array[Int]
  optional_checks : Array[String]
  extended_analysis : Bool
  extended_analysis_forced : Bool
  external_sources : Bool
  source_paths : Array[String]
  source_files : Array[(String, String)]
  config_path_override : String?
  config_files : Array[(String, String)]
} derive(Eq, Debug)

///|
// CHECK THIS: THUNK

///|
/// Returns the default checker configuration.
///
/// The default spec performs extended analysis, loads rc files, reports all
/// severities, and does not force a shell override.
pub fn CheckSpec::default() -> CheckSpec {
  {
    filename: None,
    check_sourced: false,
    ignore_rc: false,
    shell_override: None,
    fallback_shell: None,
    execution_mode: @semantics.ExecutionMode::Executed,
    min_severity: DiagnosticSeverity::Style,
    include_codes: [],
    exclude_codes: [],
    optional_checks: [],
    extended_analysis: true,
    extended_analysis_forced: false,
    external_sources: false,
    source_paths: [],
    source_files: [],
    config_path_override: None,
    config_files: [],
  }
}

///|
/// Returns a copy of the spec with a new display filename.
pub fn CheckSpec::with_filename(
  self : CheckSpec,
  filename : String?,
) -> CheckSpec {
  { ..self, filename, }
}

///|
/// Returns a copy of the spec with an explicit shell override.
pub fn CheckSpec::with_shell_override(
  self : CheckSpec,
  shell_override : @semantics.ShellDialect?,
) -> CheckSpec {
  { ..self, shell_override, }
}

///|
/// Returns a copy of the spec with the minimum reported severity.
pub fn CheckSpec::with_min_severity(
  self : CheckSpec,
  min_severity : DiagnosticSeverity,
) -> CheckSpec {
  { ..self, min_severity, }
}

///|
/// Returns a copy of the spec that only includes the given ShellCheck codes.
pub fn CheckSpec::with_include_codes(
  self : CheckSpec,
  include_codes : Array[Int],
) -> CheckSpec {
  { ..self, include_codes, }
}

///|
/// Returns a copy of the spec with the given ShellCheck codes excluded.
pub fn CheckSpec::with_exclude_codes(
  self : CheckSpec,
  exclude_codes : Array[Int],
) -> CheckSpec {
  { ..self, exclude_codes, }
}

///|
/// Returns a copy of the spec with the requested optional checks enabled.
pub fn CheckSpec::with_optional_checks(
  self : CheckSpec,
  optional_checks : Array[String],
) -> CheckSpec {
  { ..self, optional_checks, }
}

///|
/// Returns a copy of the spec with one more path for resolving sourced files.
pub fn CheckSpec::add_source_path(self : CheckSpec, path : String) -> CheckSpec {
  let source_paths = copy_check_spec_strings(self.source_paths)
  source_paths.push(path)
  { ..self, source_paths, }
}

///|
/// Returns a copy of the spec that follows sourced files during parsing.
pub fn CheckSpec::with_check_sourced(
  self : CheckSpec,
  check_sourced : Bool,
) -> CheckSpec {
  { ..self, check_sourced, }
}

///|
/// Returns a copy of the spec that skips loading `.shellcheckrc` files when set.
pub fn CheckSpec::with_ignore_rc(
  self : CheckSpec,
  ignore_rc : Bool,
) -> CheckSpec {
  { ..self, ignore_rc, }
}

///|
/// Returns a copy of the spec that allows external sourced files to be read.
pub fn CheckSpec::with_external_sources(
  self : CheckSpec,
  external_sources : Bool,
) -> CheckSpec {
  { ..self, external_sources, }
}

///|
/// Returns a copy of the spec with in-memory config file contents preloaded.
pub fn CheckSpec::with_config_files(
  self : CheckSpec,
  config_files : Array[(String, String)],
) -> CheckSpec {
  { ..self, config_files, }
}

///|
/// Returns a copy of the spec with extended analysis forced to the given value.
pub fn CheckSpec::with_extended_analysis(
  self : CheckSpec,
  extended_analysis : Bool,
) -> CheckSpec {
  { ..self, extended_analysis, extended_analysis_forced: true }
}

///|
/// Returns a copy of the spec with an explicit rc file path override.
pub fn CheckSpec::with_config_path_override(
  self : CheckSpec,
  config_path_override : String?,
) -> CheckSpec {
  { ..self, config_path_override, }
}

///|
/// A diagnostic anchored to a filename and source span.
///
/// This is the main reporting payload consumed by formatters and CLI callers.
pub struct PositionedDiagnostic {
  filename : String
  span : @parser.Span
  severity : DiagnosticSeverity
  code : Int?
  message : String
  fix : @fixer.Fix?
} derive(Eq, Debug)

///|
/// The result of checking a single source file or input stream.
pub struct CheckResult {
  filename : String
  source : String
  diagnostics : Array[PositionedDiagnostic]
} derive(Eq, Debug)

///|
/// Returns the names of optional checks that users can enable explicitly.
pub fn supported_optional_checks() -> Array[String] {
  @checks.supported_optional_checks()
}

///|
/// Renders a human-readable description block for each optional check.
pub fn list_optional_checks_text() -> String {
  render_optional_checks(@checks.supported_optional_check_infos())
}

///|
/// Parses a lowercase severity name such as `error` or `style`.
pub fn parse_diagnostic_severity(text : String) -> DiagnosticSeverity? {
  match text {
    "error" => Some(DiagnosticSeverity::Error)
    "warning" => Some(DiagnosticSeverity::Warning)
    "info" => Some(DiagnosticSeverity::Info)
    "style" => Some(DiagnosticSeverity::Style)
    _ => None
  }
}

///|
fn copy_check_spec_strings(values : Array[String]) -> Array[String] {
  let copied : Array[String] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
fn render_optional_checks(infos : Array[@checks.OptionalCheckInfo]) -> String {
  let lines : Array[String] = []
  let mut i = 0
  while i < infos.length() {
    let info = infos[i]
    if i > 0 {
      lines.push("")
    }
    lines.push("name:    " + info.name)
    lines.push("desc:    " + info.desc)
    lines.push("example: " + info.example)
    lines.push("fix:     " + info.fix)
    i += 1
  }
  lines.join("\n")
}
