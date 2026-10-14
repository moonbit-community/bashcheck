///|
struct ExpectedParserDiagnostic {
  severity : String
  code : Int32?
  line : Int32
  column : Int32
  message : String
} derive(Eq, Debug)

///|
fn expected_parser_diagnostic(
  severity : String,
  code : Int32?,
  line : Int32,
  column : Int32,
  message : String,
) -> ExpectedParserDiagnostic {
  { severity, code, line, column, message, }
}

///|
fn parser_error(
  code : Int32,
  line : Int32,
  column : Int32,
  message : String,
) -> ExpectedParserDiagnostic {
  expected_parser_diagnostic("error", Some(code), line, column, message)
}

///|
fn parser_warning(
  code : Int32,
  line : Int32,
  column : Int32,
  message : String,
) -> ExpectedParserDiagnostic {
  expected_parser_diagnostic("warning", Some(code), line, column, message)
}

///|
fn parser_info(
  code : Int32,
  line : Int32,
  column : Int32,
  message : String,
) -> ExpectedParserDiagnostic {
  expected_parser_diagnostic("info", Some(code), line, column, message)
}

///|
fn normalize_parser_diagnostics(
  diagnostics : Array[@parser.Diagnostic],
) -> Array[ExpectedParserDiagnostic] {
  let normalized : Array[ExpectedParserDiagnostic] = []
  for diagnostic in diagnostics {
    normalized.push({
      severity: parser_severity_name(diagnostic.severity),
      code: diagnostic.code,
      line: diagnostic.span.start.line,
      column: diagnostic.span.start.column,
      message: diagnostic.message,
    })
  }
  normalized
}

///|
fn sort_parser_diagnostics(
  diagnostics : Array[ExpectedParserDiagnostic],
) -> Array[ExpectedParserDiagnostic] {
  let sorted : Array[ExpectedParserDiagnostic] = []
  for diagnostic in diagnostics {
    sorted.push(diagnostic)
  }
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      if parser_diagnostic_precedes(sorted[j], sorted[i]) {
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
fn parser_diagnostic_precedes(
  lhs : ExpectedParserDiagnostic,
  rhs : ExpectedParserDiagnostic,
) -> Bool {
  if lhs.line != rhs.line {
    return lhs.line < rhs.line
  }
  if lhs.column != rhs.column {
    return lhs.column < rhs.column
  }
  let lhs_rank = parser_severity_rank(lhs.severity)
  let rhs_rank = parser_severity_rank(rhs.severity)
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
fn parser_severity_rank(severity : String) -> Int32 {
  match severity {
    "error" => 0
    "warning" => 1
    "info" => 2
    "style" => 3
    _ => 4
  }
}

///|
fn parser_severity_name(severity : @parser.DiagnosticSeverity) -> String {
  match severity {
    Error => "error"
    Warning => "warning"
    Info => "info"
  }
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
fn assert_parser_diagnostics_match_with_options(
  label : String,
  source : String,
  shellcheck_baseline : Array[ExpectedParserDiagnostic],
  options : @parser.ParseOptions,
) -> Unit {
  let actual = sort_parser_diagnostics(
    normalize_parser_diagnostics(
      @parser.parse_script_with_options(source, options).diagnostics,
    ),
  )
  let expected = sort_parser_diagnostics(shellcheck_baseline)
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
  shellcheck_baseline : Array[ExpectedParserDiagnostic],
) -> Unit {
  assert_parser_diagnostics_match_with_options(
    label,
    source,
    shellcheck_baseline,
    @parser.ParseOptions::default(),
  )
}
