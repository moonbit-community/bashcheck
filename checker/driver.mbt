///|
/// Returns the static descriptions for every built-in check known to the
/// checker pipeline.
pub fn supported_checks() -> Array[@checks.CheckDescription] {
  @checks.supported_checks()
}

///|
/// Parses, checks, filters, and sorts diagnostics for a shell source string.
///
/// This is the main entry point for library users who want a single
/// `CheckResult` from raw source text.
pub fn check_script(
  source : String,
  spec? : CheckSpec = CheckSpec::default(),
) -> CheckResult {
  let filename = display_filename(spec.filename)
  // Config loading happens before parsing the main script because rc files can
  // inject annotations that affect parse-time sourced-file resolution.
  let config = load_config(spec)
  let effective_spec = apply_config_to_spec(spec, config.annotations)
  let report = @parser.parse_script_with_options(
    source,
    parse_options(effective_spec),
  )
  // Parsing, config diagnostics, and lint diagnostics all use different
  // internal representations. They are merged here into one public list.
  let diagnostics = merge_parse_and_lint_diagnostics(
    report, filename, effective_spec, config,
  )
  { filename, source, diagnostics }
}

///|
/// Translates `CheckSpec` into parser-specific options.
///
/// This is the only place where checker configuration is converted into parser
/// settings, which keeps the rest of the checker independent from parser
/// constructor details.
fn parse_options(spec : CheckSpec) -> @parser.ParseOptions {
  @parser.ParseOptions::new(
    spec.execution_mode == @semantics.ExecutionMode::Sourced,
    false,
    spec.external_sources,
    spec.check_sourced,
    current_path_for_parse(spec.filename),
    copy_strings(spec.source_paths),
    copy_string_pairs(spec.source_files),
  )
}

///|
/// Converts display filenames into real paths the parser may use for sourced
/// file resolution.
fn current_path_for_parse(filename : String?) -> String? {
  match filename {
    Some("<stdin>") => None
    Some("<input>") => None
    Some(name) => Some(name)
    None => None
  }
}

///|
/// Combines config, parse, and lint diagnostics into one filtered, sorted list.
///
/// The order matters:
/// 1. rc-file diagnostics are added first;
/// 2. parse diagnostics are added next;
/// 3. lint only runs if parsing produced a script.
/// This mirrors the actual data dependencies in the pipeline.
fn merge_parse_and_lint_diagnostics(
  report : @parser.ParseReport,
  filename : String,
  spec : CheckSpec,
  config : LoadedConfig,
) -> Array[PositionedDiagnostic] {
  let diagnostics : Array[PositionedDiagnostic] = []
  for diagnostic in config.diagnostics {
    // Config diagnostics are already positioned; they only need final severity
    // and code filtering to honor the caller's spec.
    if severity_included(spec.min_severity, diagnostic.severity) &&
      code_is_included(spec, diagnostic.code) {
      diagnostics.push(diagnostic)
    }
  }
  let base_script = report.script
  let script = match base_script {
    // Config annotations become part of the script before later filters inspect
    // per-node disable directives.
    Some(script) => Some(apply_config_to_script(script, config.annotations))
    None => None
  }
  for diagnostic in report.diagnostics {
    let positioned = positioned_parse_diagnostic(filename, diagnostic)
    if parse_diagnostic_allowed_by_spec(spec, positioned) &&
      diagnostic_is_included(script, spec, positioned) {
      diagnostics.push(positioned)
    }
  }
  match (base_script, script) {
    (Some(base_script), Some(script)) => {
      if parse_report_has_code(report, 1071) {
        return sort_diagnostics(diagnostics)
      }
      // Shell selection depends on the parsed script plus caller overrides.
      let shell = @semantics.determine_shell_with_fallback(
        script,
        spec.shell_override,
        Some(filename),
        spec.fallback_shell,
      )
      if script.shebang is None &&
        !@semantics.suppresses_unknown_shell_warning(
          script,
          spec.shell_override,
          Some(filename),
          spec.fallback_shell,
        ) {
        // ShellCheck emits a dedicated diagnostic when analysis would be less
        // precise because the target shell is unknown.
        let unknown_shell = unknown_shell_diagnostic(filename, script)
        if diagnostic_is_included(Some(script), spec, unknown_shell) {
          diagnostics.push(unknown_shell)
        }
      }
      let optional_checks = effective_optional_checks(spec, script)
      // Extended analysis can be forced by the caller, overridden by script
      // annotations, or implicitly required by certain optional checks.
      let lint = @checks.run_checks_with_shell(
        script,
        shell,
        effective_extended_analysis(
          spec,
          base_script,
          config.annotations,
          optional_checks,
        ),
        optional_checks,
      )
      for diagnostic in lint {
        let positioned = positioned_lint_diagnostic(filename, diagnostic)
        if diagnostic_is_included(Some(script), spec, positioned) {
          diagnostics.push(positioned)
        }
      }
    }
    _ => ()
  }
  sort_diagnostics(diagnostics)
}

///|
fn parse_report_has_code(report : @parser.ParseReport, code : Int) -> Bool {
  for diagnostic in report.diagnostics {
    if diagnostic.code == Some(code) {
      return true
    }
  }
  false
}

///|
/// Applies checker-level parse-diagnostic suppressions that depend on the spec.
fn parse_diagnostic_allowed_by_spec(
  spec : CheckSpec,
  diagnostic : PositionedDiagnostic,
) -> Bool {
  match diagnostic.code {
    // Upstream ShellCheck treats an explicit shell override as authoritative and
    // suppresses the shebang-shell mismatch/unknown-shell parse diagnostic.
    Some(1071) => spec.shell_override is None
    _ => true
  }
}

///|
/// Resolves whether expensive dataflow-style analysis should run.
///
/// The user can force the value from the CLI, scripts can override it with
/// annotations, and some optional checks require it regardless.
fn effective_extended_analysis(
  spec : CheckSpec,
  script : @parser.Script,
  config_annotations : Array[@parser.Annotation],
  optional_checks : Array[String],
) -> Bool {
  let enabled = if spec.extended_analysis_forced {
    spec.extended_analysis
  } else {
    match script_extended_analysis_override(script) {
      Some(flag) => flag
      None =>
        match config_extended_analysis_override(config_annotations) {
          Some(flag) => flag
          None => spec.extended_analysis
        }
    }
  }
  enabled || optional_checks.contains("control-flow")
}

///|
fn config_extended_analysis_override(
  annotations : Array[@parser.Annotation],
) -> Bool? {
  let mut flag_override : Bool? = None
  for annotation in annotations {
    match annotation {
      @parser.Annotation::ExtendedAnalysis(flag) => flag_override = Some(flag)
      _ => ()
    }
  }
  flag_override
}

///|
/// Returns the final enabled optional checks for one script.
///
/// The function starts from the caller-provided set and then adds any
/// script-local `enable=` directives that name a supported optional check.
fn effective_optional_checks(
  spec : CheckSpec,
  script : @parser.Script,
) -> Array[String] {
  let names = copy_strings(spec.optional_checks)
  for name in @semantics.extract_enable_directives(script) {
    if @checks.supports_optional_check_name(name) && !names.contains(name) {
      names.push(name)
    }
  }
  names
}

///|
/// Returns the last script-level extended-analysis override, if any.
fn script_extended_analysis_override(script : @parser.Script) -> Bool? {
  let mut flag_override : Bool? = None
  for annotation in script.annotations {
    match annotation {
      @parser.Annotation::ExtendedAnalysis(flag) => flag_override = Some(flag)
      _ => ()
    }
  }
  flag_override
}

///|
/// Repackages a parser diagnostic using the public checker diagnostic shape.
fn positioned_parse_diagnostic(
  filename : String,
  diagnostic : @parser.Diagnostic,
) -> PositionedDiagnostic {
  {
    filename,
    span: diagnostic.span,
    severity: parse_severity(diagnostic.severity),
    code: diagnostic.code,
    message: diagnostic.message,
    fix: None,
  }
}

///|
/// Maps parser severities into checker severities.
fn parse_severity(severity : @parser.DiagnosticSeverity) -> DiagnosticSeverity {
  match severity {
    @parser.DiagnosticSeverity::Error => DiagnosticSeverity::Error
    @parser.DiagnosticSeverity::Warning => DiagnosticSeverity::Warning
    @parser.DiagnosticSeverity::Info => DiagnosticSeverity::Info
  }
}

///|
/// Repackages a lint diagnostic using the public checker diagnostic shape.
fn positioned_lint_diagnostic(
  filename : String,
  diagnostic : @checks.CheckDiagnostic,
) -> PositionedDiagnostic {
  {
    filename,
    span: diagnostic.span,
    severity: lint_severity(diagnostic.severity),
    code: Some(diagnostic.code),
    message: diagnostic.message,
    fix: localize_lint_fix(filename, diagnostic.fix),
  }
}

///|
/// Rewrites fix replacements so each one is anchored to the user-facing
/// filename being checked.
///
/// Lint fixes are usually produced relative to the analyzed script. The public
/// API, however, expects replacements to already carry the final filename.
fn localize_lint_fix(filename : String, fix : @fixer.Fix?) -> @fixer.Fix? {
  match fix {
    Some(fix) => {
      let replacements : Array[@fixer.Replacement] = []
      for replacement in fix.replacements {
        replacements.push(
          @fixer.Replacement::new(
            filename,
            replacement.start,
            replacement.end,
            replacement.text,
            replacement.precedence,
            replacement.insertion_point,
          ),
        )
      }
      Some(@fixer.Fix::from_replacements(replacements))
    }
    None => None
  }
}

///|
/// Maps lint severities into checker severities.
fn lint_severity(severity : @checks.CheckSeverity) -> DiagnosticSeverity {
  match severity {
    @checks.CheckSeverity::Error => DiagnosticSeverity::Error
    @checks.CheckSeverity::Warning => DiagnosticSeverity::Warning
    @checks.CheckSeverity::Info => DiagnosticSeverity::Info
    @checks.CheckSeverity::Style => DiagnosticSeverity::Style
  }
}

///|
/// Creates the ShellCheck-compatible "unknown shell" diagnostic.
fn unknown_shell_diagnostic(
  filename : String,
  script : @parser.Script,
) -> PositionedDiagnostic {
  {
    filename,
    span: script.span,
    severity: DiagnosticSeverity::Error,
    code: Some(2148),
    message: "Tips depend on target shell and yours is unknown. Add a shebang or a 'shell' directive.",
    fix: None,
  }
}

///|
/// Applies severity and code filters to an existing diagnostic list.
pub fn filter_diagnostics(
  diagnostics : Array[PositionedDiagnostic],
  spec : CheckSpec,
) -> Array[PositionedDiagnostic] {
  let filtered : Array[PositionedDiagnostic] = []
  for diagnostic in diagnostics {
    if severity_included(spec.min_severity, diagnostic.severity) &&
      code_is_included(spec, diagnostic.code) {
      filtered.push(diagnostic)
    }
  }
  filtered
}

///|
/// Returns whether a diagnostic survives every active filter.
///
/// Filtering happens in three layers:
/// 1. minimum severity;
/// 2. include/exclude code lists;
/// 3. in-script `disable=` annotations for diagnostics that carry a code.
fn diagnostic_is_included(
  script : @parser.Script?,
  spec : CheckSpec,
  diagnostic : PositionedDiagnostic,
) -> Bool {
  if !severity_included(spec.min_severity, diagnostic.severity) {
    return false
  }
  if !code_is_included(spec, diagnostic.code) {
    return false
  }
  match (script, diagnostic.code) {
    (Some(script), Some(code)) =>
      // Disable annotations only make sense when both a parsed script and a
      // concrete ShellCheck code are available.
      !annotations_disable_code_at_position(script, diagnostic.span.start, code)
    _ => true
  }
}

///|
/// Checks whether `severity` is at least as important as the configured
/// minimum. Lower numeric ranks represent more severe diagnostics.
fn severity_included(
  min_severity : DiagnosticSeverity,
  severity : DiagnosticSeverity,
) -> Bool {
  severity_rank(severity) <= severity_rank(min_severity)
}

///|
/// Applies include/exclude code filtering.
///
/// Include lists are exclusive: once present, only listed codes survive.
/// Diagnostics without a code survive only when there is no include list.
fn code_is_included(spec : CheckSpec, code : Int?) -> Bool {
  match code {
    Some(code) =>
      if spec.include_codes.length() > 0 {
        spec.include_codes.contains(code)
      } else {
        !spec.exclude_codes.contains(code)
      }
    None => spec.include_codes.length() == 0
  }
}

///|
/// Assigns sortable numeric ranks to severities.
fn severity_rank(severity : DiagnosticSeverity) -> Int {
  match severity {
    DiagnosticSeverity::Error => 0
    DiagnosticSeverity::Warning => 1
    DiagnosticSeverity::Info => 2
    DiagnosticSeverity::Style => 3
  }
}

///|
/// Returns diagnostics sorted by filename, span, and severity.
pub fn sort_diagnostics(
  diagnostics : Array[PositionedDiagnostic],
) -> Array[PositionedDiagnostic] {
  let sorted = copy_positioned_diagnostics(diagnostics)
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      // A simple in-place quadratic sort is sufficient here because diagnostic
      // lists are typically small and this keeps ordering logic explicit.
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
/// Returns whether `lhs` should appear before `rhs` in final output.
///
/// Ordering is stable and deterministic across renderers: filename, start/end
/// offsets, severity, diagnostic code, then message text.
fn diagnostic_precedes(
  lhs : PositionedDiagnostic,
  rhs : PositionedDiagnostic,
) -> Bool {
  if lhs.filename != rhs.filename {
    return lhs.filename < rhs.filename
  }
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
/// Checks whether a `disable=` annotation suppresses `code` at `position`.
///
/// The walker descends the script tree and stops as soon as a matching
/// annotation is found in an enclosing node or in one of its immediate items.
fn annotations_disable_code_at_position(
  script : @parser.Script,
  position : @parser.Position,
  code : Int,
) -> Bool {
  let mut disabled = false
  @semantics.walk_script(script, fn(current) {
    // Ignore subtrees that cannot possibly cover the target position.
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
/// Returns whether `position` lies inside `span`, inclusive of both endpoints.
fn span_contains_position(
  span : @parser.Span,
  position : @parser.Position,
) -> Bool {
  span.start.offset <= position.offset && position.offset <= span.end.offset
}

///|
/// Checks whether any annotation in the list disables the given code.
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
/// Matches disable directives such as `all`, `SC2086`, or `SC2086-SC2090`.
fn disable_value_matches_code(value : String, code : Int) -> Bool {
  if value == "all" {
    return true
  }
  match split_disable_once(value) {
    Some((left, right)) =>
      match
        (parse_disable_code_number(left), parse_disable_code_number(right)) {
        (Some(start), Some(end_)) =>
          // Ranges are accepted in either direction so `SC2090-SC2086` still
          // behaves sensibly.
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
/// Splits a disable range at the first `-`, if present.
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
/// Parses one disable-code token in either `1234` or `SC1234` form.
fn parse_disable_code_number(text : String) -> Int? {
  let start = if text.has_prefix("SC") { 2 } else { 0 }
  let digits = text.view(start_offset=start).to_string()
  if digits == "" || !disable_text_is_digits(text) {
    return None
  }
  Some(digits_to_int(digits))
}

///|
/// Returns whether the disable token consists only of digits after an optional
/// `SC` prefix.
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
/// Converts an ASCII digit string into an integer.
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
/// Chooses the filename rendered in public `CheckResult` objects.
fn display_filename(filename : String?) -> String {
  match filename {
    Some(filename) => filename
    None => "<input>"
  }
}

///|
/// Copies a string array into a fresh buffer.
fn copy_strings(values : Array[String]) -> Array[String] {
  let copied : Array[String] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
/// Copies an array of string pairs into a fresh buffer.
fn copy_string_pairs(
  values : Array[(String, String)],
) -> Array[(String, String)] {
  let copied : Array[(String, String)] = []
  for value in values {
    copied.push(value)
  }
  copied
}

///|
/// Copies diagnostics into a fresh array before sorting.
fn copy_positioned_diagnostics(
  diagnostics : Array[PositionedDiagnostic],
) -> Array[PositionedDiagnostic] {
  let copied : Array[PositionedDiagnostic] = []
  for diagnostic in diagnostics {
    copied.push(diagnostic)
  }
  copied
}
