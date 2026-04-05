///|
struct BaselineDiagnostic {
  severity : String
  code : Int?
  line : Int
  column : Int
  message : String
} derive(Eq, Debug)

///|
fn baseline_diagnostic(
  severity : String,
  code : Int?,
  line : Int,
  column : Int,
  message : String,
) -> BaselineDiagnostic {
  { severity, code, line, column, message }
}

///|
fn shellcheck_error(
  code : Int,
  line : Int,
  column : Int,
  message : String,
) -> BaselineDiagnostic {
  baseline_diagnostic("error", Some(code), line, column, message)
}

///|
fn shellcheck_warning(
  code : Int,
  line : Int,
  column : Int,
  message : String,
) -> BaselineDiagnostic {
  baseline_diagnostic("warning", Some(code), line, column, message)
}

///|
fn shellcheck_info(
  code : Int,
  line : Int,
  column : Int,
  message : String,
) -> BaselineDiagnostic {
  baseline_diagnostic("info", Some(code), line, column, message)
}

///|
fn shellcheck_style(
  code : Int,
  line : Int,
  column : Int,
  message : String,
) -> BaselineDiagnostic {
  baseline_diagnostic("style", Some(code), line, column, message)
}

///|
fn normalize_baseline_diagnostics(
  diagnostics : Array[@checker.PositionedDiagnostic],
) -> Array[BaselineDiagnostic] {
  let normalized : Array[BaselineDiagnostic] = []
  for diagnostic in diagnostics {
    normalized.push({
      severity: baseline_severity_name(diagnostic.severity),
      code: diagnostic.code,
      line: diagnostic.span.start.line,
      column: diagnostic.span.start.column,
      message: diagnostic.message,
    })
  }
  normalized
}

///|
fn normalize_parser_baseline_diagnostics(
  diagnostics : Array[@parser.Diagnostic],
) -> Array[BaselineDiagnostic] {
  let normalized : Array[BaselineDiagnostic] = []
  for diagnostic in diagnostics {
    normalized.push({
      severity: parser_baseline_severity_name(diagnostic.severity),
      code: diagnostic.code,
      line: diagnostic.span.start.line,
      column: diagnostic.span.start.column,
      message: diagnostic.message,
    })
  }
  normalized
}

///|
fn sort_baseline_diagnostics(
  diagnostics : Array[BaselineDiagnostic],
) -> Array[BaselineDiagnostic] {
  let sorted : Array[BaselineDiagnostic] = []
  for diagnostic in diagnostics {
    sorted.push(diagnostic)
  }
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      if baseline_diagnostic_precedes(sorted[j], sorted[i]) {
        let current = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = current
      }
      j += 1
    }
    i += 1
  }
  sorted
}

///|
fn baseline_diagnostic_precedes(
  lhs : BaselineDiagnostic,
  rhs : BaselineDiagnostic,
) -> Bool {
  if lhs.line != rhs.line {
    return lhs.line < rhs.line
  }
  if lhs.column != rhs.column {
    return lhs.column < rhs.column
  }
  let lhs_rank = baseline_severity_rank(lhs.severity)
  let rhs_rank = baseline_severity_rank(rhs.severity)
  if lhs_rank != rhs_rank {
    return lhs_rank < rhs_rank
  }
  match (lhs.code, rhs.code) {
    (Some(lhs_code), Some(rhs_code)) if lhs_code != rhs_code =>
      return lhs_code < rhs_code
    (Some(_), None) => return true
    (None, Some(_)) => return false
    _ => ()
  }
  lhs.message < rhs.message
}

///|
fn baseline_severity_rank(severity : String) -> Int {
  match severity {
    "error" => 0
    "warning" => 1
    "info" => 2
    "style" => 3
    _ => 4
  }
}

///|
fn baseline_severity_name(severity : @checker.DiagnosticSeverity) -> String {
  match severity {
    @checker.DiagnosticSeverity::Error => "error"
    @checker.DiagnosticSeverity::Warning => "warning"
    @checker.DiagnosticSeverity::Info => "info"
    @checker.DiagnosticSeverity::Style => "style"
  }
}

///|
fn parser_baseline_severity_name(
  severity : @parser.DiagnosticSeverity,
) -> String {
  match severity {
    @parser.DiagnosticSeverity::Error => "error"
    @parser.DiagnosticSeverity::Warning => "warning"
    @parser.DiagnosticSeverity::Info => "info"
  }
}

///|
fn bash_shell_spec() -> @checker.CheckSpec {
  @checker.CheckSpec::default().with_shell_override(
    Some(@semantics.ShellDialect::Bash),
  )
}

///|
fn sourced_bash_parser_options(
  current_path : String,
  source_files : Array[(String, String)],
) -> @parser.ParseOptions {
  @parser.ParseOptions::new(
    false,
    false,
    false,
    true,
    Some(current_path),
    [],
    source_files,
  )
}

///|
fn bash_shell_spec_with_config(
  path : String,
  contents : String,
) -> @checker.CheckSpec {
  let spec = bash_shell_spec().with_config_path_override(Some(path))
  spec.with_config_files([(path, contents)])
}

///|
fn assert_diagnostics_match(
  label : String,
  source : String,
  shellcheck_baseline : Array[BaselineDiagnostic],
  spec? : @checker.CheckSpec = bash_shell_spec(),
) -> Unit {
  let actual = normalize_baseline_diagnostics(
    @checker.check_script(source, spec~).diagnostics,
  )
  if actual != shellcheck_baseline {
    abort(
      "\{label}: expected upstream baseline \{@debug.to_string(shellcheck_baseline)}, got \{@debug.to_string(actual)}",
    )
  }
}

///|
fn assert_parser_diagnostics_match_with_options(
  label : String,
  source : String,
  shellcheck_baseline : Array[BaselineDiagnostic],
  options : @parser.ParseOptions,
) -> Unit {
  let actual = sort_baseline_diagnostics(
    normalize_parser_baseline_diagnostics(
      @parser.parse_script_with_options(source, options).diagnostics,
    ),
  )
  let expected = sort_baseline_diagnostics(shellcheck_baseline)
  if actual != expected {
    abort(
      "\{label}: expected upstream parser baseline \{@debug.to_string(expected)}, got \{@debug.to_string(actual)}",
    )
  }
}

///|
fn assert_parser_diagnostics_match(
  label : String,
  source : String,
  shellcheck_baseline : Array[BaselineDiagnostic],
) -> Unit {
  assert_parser_diagnostics_match_with_options(
    label,
    source,
    shellcheck_baseline,
    @parser.ParseOptions::default(),
  )
}

///|
async fn assert_cli_output_matches(
  label : String,
  action : @driver.CliAction,
  expected_exit_code : Int,
  expected_output : String,
) -> Unit {
  let outcome = @driver.run_cli(
    action,
    [],
    @checker.CheckSpec::default(),
    @formatter.OutputFormat::default(),
    @formatter.FormatOptions::default(),
  )
  if outcome.exit_code != expected_exit_code {
    abort(
      "\{label}: expected exit code \{expected_exit_code}, got \{outcome.exit_code}",
    )
  }
  if outcome.output != expected_output {
    abort(
      "\{label}: expected CLI output \{@debug.to_string(expected_output)}, got \{@debug.to_string(outcome.output)}",
    )
  }
}
