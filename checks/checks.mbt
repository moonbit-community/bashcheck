///|
/// Runs the built-in lint suites for a parsed script.
///
/// The script's shell dialect is inferred from the options before individual
/// checks are executed.
pub fn check_script(
  script : @parser.Script,
  options? : CheckOptions = CheckOptions::default(),
) -> Array[CheckDiagnostic] {
  let shell = match (options.shell_override, options.filename) {
    (Some(shell_override), Some(filename)) =>
      @semantics.determine_shell(script, shell_override~, filename~)
    (Some(shell_override), None) =>
      @semantics.determine_shell(script, shell_override~)
    (None, Some(filename)) => @semantics.determine_shell(script, filename~)
    (None, None) => @semantics.determine_shell(script)
  }
  run_checks_with_shell(
    script,
    shell,
    options.extended_analysis,
    options.optional_checks,
  )
}

///|
/// Runs the built-in lint suites using an explicit shell dialect.
pub fn run_checks_with_shell(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  extended_analysis : Bool,
  optional_checks : Array[String],
) -> Array[CheckDiagnostic] {
  let diagnostics : Array[CheckDiagnostic] = []
  run_check_suites(core_check_suites(), script, shell, diagnostics)
  run_toggleable_check_suites(
    toggleable_check_suites(),
    script,
    shell,
    diagnostics,
    extended_analysis,
    optional_checks,
  )
  run_optional_checks(
    optional_check_registrations(),
    script,
    shell,
    diagnostics,
    optional_checks,
  )
  sort_diagnostics(filter_disabled_diagnostics(script, diagnostics))
}

///|
/// Returns metadata for every check currently implemented by this package.
pub fn supported_checks() -> Array[CheckDescription] {
  let descriptions : Array[CheckDescription] = []
  append_suite_descriptions(descriptions, core_check_suites())
  append_toggleable_suite_descriptions(descriptions, toggleable_check_suites())
  append_optional_descriptions(descriptions, optional_check_registrations())
  descriptions
}

///|
/// Returns the names of optional checks that can be enabled by users.
pub fn supported_optional_checks() -> Array[String] {
  let names : Array[String] = []
  append_optional_check_names(names, optional_check_registrations())
  sort_optional_check_names(names)
}

///|
/// Returns descriptive metadata for each optional check name.
pub fn supported_optional_check_infos() -> Array[OptionalCheckInfo] {
  let infos : Array[OptionalCheckInfo] = []
  append_optional_check_infos(infos, optional_check_registrations())
  sort_optional_check_infos(infos)
}

///|
/// Reports whether a name matches a supported optional or toggleable check.
pub fn supports_optional_check_name(name : String) -> Bool {
  supported_optional_checks().contains(name) ||
  toggleable_optional_check_names().contains(name)
}

///|
fn core_check_suites() -> Array[CheckSuiteRegistration] {
  [analytics_suite(), commands_suite(), shell_support_suite()]
}

///|
fn toggleable_check_suites() -> Array[ToggleableCheckSuiteRegistration] {
  [control_flow_suite()]
}

///|
fn optional_check_registrations() -> Array[OptionalCheckRegistration] {
  let registrations = analytics_optional_registrations()
  append_optional_registrations(
    registrations,
    commands_optional_registrations(),
  )
  registrations
}

///|
fn run_check_suites(
  suites : Array[CheckSuiteRegistration],
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  for suite in suites {
    (suite.run)(script, shell, diagnostics)
  }
}

///|
fn run_toggleable_check_suites(
  suites : Array[ToggleableCheckSuiteRegistration],
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
  extended_analysis : Bool,
  optional_checks : Array[String],
) -> Unit {
  for suite in suites {
    if extended_analysis || optional_checks.contains(suite.name) {
      (suite.run)(script, shell, diagnostics)
    }
  }
}

///|
fn run_optional_checks(
  registrations : Array[OptionalCheckRegistration],
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
  optional_checks : Array[String],
) -> Unit {
  for registration in registrations {
    if optional_checks.contains(registration.info.name) {
      (registration.run)(script, shell, diagnostics)
    }
  }
}

///|
fn append_suite_descriptions(
  descriptions : Array[CheckDescription],
  suites : Array[CheckSuiteRegistration],
) -> Unit {
  for suite in suites {
    for description in suite.descriptions {
      descriptions.push(description)
    }
  }
}

///|
fn append_toggleable_suite_descriptions(
  descriptions : Array[CheckDescription],
  suites : Array[ToggleableCheckSuiteRegistration],
) -> Unit {
  for suite in suites {
    for description in suite.descriptions {
      descriptions.push(description)
    }
  }
}

///|
fn append_optional_descriptions(
  descriptions : Array[CheckDescription],
  registrations : Array[OptionalCheckRegistration],
) -> Unit {
  for registration in registrations {
    descriptions.push(registration.description)
  }
}

///|
fn append_toggleable_check_names(
  names : Array[String],
  suites : Array[ToggleableCheckSuiteRegistration],
) -> Unit {
  for suite in suites {
    names.push(suite.name)
  }
}

///|
fn append_optional_check_names(
  names : Array[String],
  registrations : Array[OptionalCheckRegistration],
) -> Unit {
  for registration in registrations {
    names.push(registration.info.name)
  }
}

///|
fn append_optional_check_infos(
  infos : Array[OptionalCheckInfo],
  registrations : Array[OptionalCheckRegistration],
) -> Unit {
  for registration in registrations {
    infos.push(registration.info)
  }
}

///|
fn append_optional_registrations(
  registrations : Array[OptionalCheckRegistration],
  extra : Array[OptionalCheckRegistration],
) -> Unit {
  for registration in extra {
    registrations.push(registration)
  }
}

///|
fn toggleable_optional_check_names() -> Array[String] {
  let names : Array[String] = []
  append_toggleable_check_names(names, toggleable_check_suites())
  names
}

///|
fn sort_optional_check_names(names : Array[String]) -> Array[String] {
  let sorted : Array[String] = []
  for name in names {
    sorted.push(name)
  }
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      if string_precedes(sorted[j], sorted[i]) {
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
fn sort_optional_check_infos(
  infos : Array[OptionalCheckInfo],
) -> Array[OptionalCheckInfo] {
  let sorted : Array[OptionalCheckInfo] = []
  for info in infos {
    sorted.push(info)
  }
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      if string_precedes(sorted[j].name, sorted[i].name) {
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
fn string_precedes(lhs : String, rhs : String) -> Bool {
  let lhs_view = lhs[:]
  let rhs_view = rhs[:]
  let limit = if lhs_view.length() < rhs_view.length() {
    lhs_view.length()
  } else {
    rhs_view.length()
  }
  let mut i = 0
  while i < limit {
    if lhs_view[i] != rhs_view[i] {
      return lhs_view[i] < rhs_view[i]
    }
    i += 1
  }
  lhs_view.length() < rhs_view.length()
}

///|
fn filter_disabled_diagnostics(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Array[CheckDiagnostic] {
  let filtered : Array[CheckDiagnostic] = []
  for diagnostic in diagnostics {
    if diagnostic_is_enabled(script, diagnostic) {
      filtered.push(diagnostic)
    }
  }
  filtered
}

///|
fn diagnostic_is_enabled(
  script : @parser.Script,
  diagnostic : CheckDiagnostic,
) -> Bool {
  !annotations_disable_code_at_position(
    script,
    diagnostic.span.start,
    diagnostic.code,
  )
}

///|
fn annotations_disable_code_at_position(
  script : @parser.Script,
  position : @parser.Position,
  code : Int,
) -> Bool {
  let mut disabled = false
  @semantics.walk_script(script, fn(current) {
    if disabled || !span_contains_position(current.span, position) {
      return
    }
    if annotations_disable_code(current.annotations, code) {
      disabled = true
      return
    }
    for item in current.items {
      if span_contains_position(item.span, position) &&
        annotations_disable_code(item.annotations, code) {
        disabled = true
        return
      }
    }
  })
  disabled
}

///|
fn span_contains_position(
  span : @parser.Span,
  position : @parser.Position,
) -> Bool {
  span.start.offset <= position.offset && position.offset <= span.end.offset
}

///|
fn annotations_disable_code(
  annotations : Array[@parser.Annotation],
  code : Int,
) -> Bool {
  for annotation in annotations {
    match annotation {
      @parser.Annotation::Disable(value) if disable_value_matches_code(
          value, code,
        ) => return true
      _ => ()
    }
  }
  false
}

///|
fn disable_value_matches_code(value : String, code : Int) -> Bool {
  if value == "all" {
    return true
  }
  match split_disable_once(value) {
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
fn split_disable_once(text : String) -> (String, String)? {
  let view = text[:]
  let mut i = 0
  while i < view.length() {
    if view[i] == '-' {
      return Some(
        (
          text.view(end_offset=i).to_string(),
          text.view(start_offset=i + 1).to_string(),
        ),
      )
    }
    i += 1
  }
  None
}

///|
fn parse_disable_code_number(text : String) -> Int? {
  let start = if text.has_prefix("SC") { 2 } else { 0 }
  let digits = text.view(start_offset=start).to_string()
  if digits == "" || !disable_text_is_digits(text) {
    return None
  }
  Some(digits_to_int(digits))
}

///|
fn disable_text_is_digits(text : String) -> Bool {
  let start = if text.has_prefix("SC") { 2 } else { 0 }
  let view = text[:]
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
fn digits_to_int(text : String) -> Int {
  let view = text[:]
  let mut value = 0
  let mut i = 0
  while i < view.length() {
    value = value * 10 + (view[i] - '0').to_int()
    i += 1
  }
  value
}

///|
fn sort_diagnostics(
  diagnostics : Array[CheckDiagnostic],
) -> Array[CheckDiagnostic] {
  let sorted = copy_diagnostics(diagnostics)
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      if diagnostic_precedes(sorted[j], sorted[i]) {
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
fn diagnostic_precedes(lhs : CheckDiagnostic, rhs : CheckDiagnostic) -> Bool {
  if lhs.span.start.offset != rhs.span.start.offset {
    return lhs.span.start.offset < rhs.span.start.offset
  }
  if lhs.span.end.offset != rhs.span.end.offset {
    return lhs.span.end.offset < rhs.span.end.offset
  }
  let lhs_rank = severity_rank(lhs.severity)
  let rhs_rank = severity_rank(rhs.severity)
  if lhs_rank != rhs_rank {
    return lhs_rank < rhs_rank
  }
  lhs.code < rhs.code
}

///|
fn severity_rank(severity : CheckSeverity) -> Int {
  match severity {
    CheckSeverity::Error => 0
    CheckSeverity::Warning => 1
    CheckSeverity::Info => 2
    CheckSeverity::Style => 3
  }
}

///|
fn copy_diagnostics(
  diagnostics : Array[CheckDiagnostic],
) -> Array[CheckDiagnostic] {
  let copied : Array[CheckDiagnostic] = []
  for diagnostic in diagnostics {
    copied.push(diagnostic)
  }
  copied
}
