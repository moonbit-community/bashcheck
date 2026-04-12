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
  match script {
    Some(script) =>
      append_missing_source_diagnostics(diagnostics, filename, spec, script)
    None => ()
  }
  match (base_script, script) {
    (Some(base_script), Some(script)) => {
      append_shebang_entry_diagnostics(diagnostics, filename, spec, script)
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
    // Recursive include diagnostics are internal parser bookkeeping. The
    // public checker does not surface them.
    Some(1093) => false
    _ => true
  }
}

///|
fn append_missing_source_diagnostics(
  diagnostics : Array[PositionedDiagnostic],
  filename : String,
  spec : CheckSpec,
  script : @parser.Script,
) -> Unit {
  if spec.check_sourced {
    return
  }
  for command in top_level_commands(script) {
    @semantics.walk_command(command, fn(current) {
      match current.kind {
        @parser.CommandKind::Source(source) =>
          match @semantics.literal_text(source.path) {
            Some(path) if !source_file_is_available(spec, path) => {
              let diagnostic = {
                filename,
                span: source.path.span,
                severity: DiagnosticSeverity::Warning,
                code: Some(1091),
                message: "source file '\{path}' was not provided in parse options",
                fix: None,
              }
              if diagnostic_is_included(Some(script), spec, diagnostic) {
                diagnostics.push(diagnostic)
              }
            }
            _ => ()
          }
        _ => ()
      }
    })
  }
}

///|
fn top_level_commands(script : @parser.Script) -> Array[@parser.Command] {
  let commands : Array[@parser.Command] = []
  for item in script.items {
    for segment in item.and_or.head.segments {
      commands.push(segment.command)
    }
    for pair in item.and_or.tail {
      for segment in pair.1.segments {
        commands.push(segment.command)
      }
    }
  }
  commands
}

///|
fn source_file_is_available(spec : CheckSpec, path : String) -> Bool {
  if path == "/dev/null" {
    return true
  }
  if source_file_is_listed(spec.source_files, path) {
    return true
  }
  if path.has_prefix("/") {
    return false
  }
  match spec.filename {
    Some(filename) =>
      if source_file_is_listed(
          spec.source_files,
          path_join(path_dirname(filename), path),
        ) {
        return true
      }
    None => ()
  }
  for source_path in spec.source_paths {
    if source_file_is_listed(spec.source_files, path_join(source_path, path)) {
      return true
    }
  }
  false
}

///|
fn source_file_is_listed(
  source_files : Array[(String, String)],
  path : String,
) -> Bool {
  for pair in source_files {
    if pair.0 == path {
      return true
    }
  }
  false
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
fn append_shebang_entry_diagnostics(
  diagnostics : Array[PositionedDiagnostic],
  filename : String,
  spec : CheckSpec,
  script : @parser.Script,
) -> Unit {
  guard spec.shell_override is None && !script_has_shell_annotation(script) else {
    return
  }
  let shebang = match script.shebang {
    Some(shebang) => shebang
    None => return
  }
  let command = checker_shebang_command_text(shebang)
  let span = checker_shebang_span(script, shebang)
  if checker_executable_from_shebang(shebang) == "ash" {
    let diagnostic = {
      filename,
      span,
      severity: DiagnosticSeverity::Warning,
      code: Some(2187),
      message: "Ash scripts will be checked as Dash. Add '# shellcheck shell=dash' to silence.",
      fix: None,
    }
    if diagnostic_is_included(Some(script), spec, diagnostic) {
      diagnostics.push(diagnostic)
    }
  }
  if command != "" && !command.has_prefix("/") {
    let diagnostic = {
      filename,
      span,
      severity: DiagnosticSeverity::Error,
      code: Some(2239),
      message: "Ensure the shebang uses an absolute path to the interpreter.",
      fix: None,
    }
    if diagnostic_is_included(Some(script), spec, diagnostic) {
      diagnostics.push(diagnostic)
    }
  }
  match checker_shebang_words(shebang).get(0) {
    Some(first) if checker_quote_removed_source(first).has_suffix("/") => {
      let diagnostic = {
        filename,
        span,
        severity: DiagnosticSeverity::Error,
        code: Some(2246),
        message: "This shebang specifies a directory. Ensure the interpreter is a file.",
        fix: None,
      }
      if diagnostic_is_included(Some(script), spec, diagnostic) {
        diagnostics.push(diagnostic)
      }
    }
    _ => ()
  }
}

///|
fn script_has_shell_annotation(script : @parser.Script) -> Bool {
  for annotation in script.annotations {
    match annotation {
      @parser.Annotation::Shell(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn checker_shebang_span(
  script : @parser.Script,
  shebang : String,
) -> @parser.Span {
  let start = if script.has_bom {
    @parser.Position::new(1, 1, 2)
  } else {
    @parser.Position::new(0, 1, 1)
  }
  let end_ = @parser.Position::new(
    start.offset + shebang.length(),
    1,
    start.column + shebang.length(),
  )
  @parser.Span::new(start, end_)
}

///|
fn checker_shebang_command_text(shebang : String) -> String {
  if shebang.has_prefix("#!") {
    checker_trim_ascii_space(shebang.view(start_offset=2).to_string())
  } else {
    checker_trim_ascii_space(shebang)
  }
}

///|
fn checker_executable_from_shebang(shebang : String) -> String {
  let words = checker_shebang_words(shebang)
  if words.length() == 0 {
    return ""
  }
  let first = checker_basename(checker_quote_removed_source(words[0]))
  if first == "busybox" {
    if words.length() < 2 {
      return first
    }
    let second = checker_basename(checker_quote_removed_source(words[1]))
    match second {
      "sh" => "busybox sh"
      "ash" => "busybox ash"
      _ => second
    }
  } else if first == "env" {
    checker_env_shell_from_args(words, 1)
  } else {
    first
  }
}

///|
fn checker_shebang_words(shebang : String) -> Array[String] {
  checker_split_shell_words(checker_shebang_command_text(shebang))
}

///|
fn checker_env_shell_from_args(args : Array[String], start : Int) -> String {
  let mut i = start
  while i < args.length() {
    let arg = checker_quote_removed_source(args[i])
    if arg == "-S" || arg == "--split-string" {
      if i + 1 < args.length() {
        let split = checker_split_string_args_with_tail(
          checker_split_shell_words(checker_quote_removed_source(args[i + 1])),
          args,
          i + 2,
        )
        let shell = checker_env_shell_from_args(split, 0)
        if shell != "" {
          return shell
        }
        i += 2
        continue
      }
      i += 1
      continue
    }
    if arg.has_prefix("--split-string=") {
      let head = arg.view(start_offset="--split-string=".length()).to_string()
      let split = if head != "" {
        checker_split_string_args_with_tail(
          checker_split_shell_words(head),
          args,
          i + 1,
        )
      } else if i + 1 < args.length() {
        checker_split_string_args_with_tail(
          checker_split_shell_words(checker_quote_removed_source(args[i + 1])),
          args,
          i + 2,
        )
      } else {
        []
      }
      if split.length() > 0 {
        let shell = checker_env_shell_from_args(split, 0)
        if shell != "" {
          return shell
        }
        if head == "" {
          i += 2
          continue
        }
      }
      i += 1
      continue
    }
    if arg.has_prefix("-") || arg.contains("=") {
      i += 1
      continue
    }
    return checker_basename(arg)
  }
  ""
}

///|
fn checker_split_string_args_with_tail(
  split : Array[String],
  args : Array[String],
  tail_start : Int,
) -> Array[String] {
  let combined : Array[String] = []
  for part in split {
    combined.push(part)
  }
  let mut i = tail_start
  while i < args.length() {
    combined.push(args[i])
    i += 1
  }
  combined
}

///|
fn checker_split_shell_words(text : String) -> Array[String] {
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
fn checker_quote_removed_source(raw : String) -> String {
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
fn checker_trim_ascii_space(text : String) -> String {
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
fn checker_basename(text : String) -> String {
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
