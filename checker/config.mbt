///|
/// Parsed rc-file payload that influences checking.
///
/// Config files can both emit their own diagnostics and contribute annotations
/// that modify how the main script is checked.
priv struct LoadedConfig {
  annotations : Array[@parser.Annotation]
  diagnostics : Array[PositionedDiagnostic]
}

///|
/// Loads the effective configuration for one check run.
///
/// The loader prefers an explicit `--rcfile` override when present; otherwise
/// it searches the candidate parent directories for the first available rc
/// file. All paths are resolved against already-preloaded in-memory contents so
/// the checker itself stays free of filesystem access.
fn load_config(spec : CheckSpec) -> LoadedConfig {
  if spec.ignore_rc {
    return empty_loaded_config()
  }
  match spec.config_path_override {
    Some(path) => return load_config_from_path(path, spec.config_files)
    None => ()
  }
  let filename = match current_path_for_parse(spec.filename) {
    Some(filename) => filename
    None => return empty_loaded_config()
  }
  match
    read_first_config_file(config_candidate_paths(filename), spec.config_files) {
    Some((path, contents)) => parse_loaded_config(path, contents)
    None => empty_loaded_config()
  }
}

///|
/// Loads configuration from one explicit path, if that path has been preloaded.
fn load_config_from_path(
  path : String,
  config_files : Array[(String, String)],
) -> LoadedConfig {
  match lookup_config_file(config_files, path) {
    Some(contents) => parse_loaded_config(path, contents)
    None => empty_loaded_config()
  }
}

///|
/// Returns the neutral config object used when no rc file applies.
fn empty_loaded_config() -> LoadedConfig {
  { annotations: [], diagnostics: [] }
}

///|
/// Parses one rc file into annotations plus positioned diagnostics.
///
/// A hard parse error collapses into a single, user-friendly SC1134-style
/// diagnostic so callers get a focused message instead of a noisy cascade.
fn parse_loaded_config(path : String, contents : String) -> LoadedConfig {
  let report = @parser.parse_config_report(contents)
  match first_config_error(report.diagnostics) {
    Some(diagnostic) =>
      return {
        annotations: [],
        diagnostics: [positioned_config_parse_error(path, contents, diagnostic)],
      }
    None => ()
  }
  {
    annotations: copy_parser_annotations(report.annotations),
    diagnostics: position_config_diagnostics(path, report.diagnostics),
  }
}

///|
/// Returns the first fatal config diagnostic, ignoring warnings and infos.
fn first_config_error(
  diagnostics : Array[@parser.Diagnostic],
) -> @parser.Diagnostic? {
  for diagnostic in diagnostics {
    match diagnostic.severity {
      @parser.DiagnosticSeverity::Error => return Some(diagnostic)
      _ => ()
    }
  }
  None
}

///|
/// Converts a raw config parse error into the public checker diagnostic model.
fn positioned_config_parse_error(
  filename : String,
  contents : String,
  diagnostic : @parser.Diagnostic,
) -> PositionedDiagnostic {
  let line = diagnostic.span.start.line
  let cause = config_error_cause(contents, diagnostic)
  {
    filename,
    span: diagnostic.span,
    severity: DiagnosticSeverity::Error,
    code: Some(1134),
    message: "Failed to process \{filename}, line \{line}: \{cause}. Fix any mentioned problems and try again.",
    fix: None,
  }
}

///|
/// Produces the human-readable cause text for a config parse failure.
///
/// Some parser diagnostics are technically correct but too generic for users,
/// so this function upgrades common cases such as a missing `=` into clearer
/// wording.
fn config_error_cause(
  contents : String,
  diagnostic : @parser.Diagnostic,
) -> String {
  if diagnostic.code == Some(1125) &&
    config_line_missing_equals_after_key(
      config_line_text(contents, diagnostic.span.start.line),
    ) {
    return "Expected '=' after directive key"
  }
  sentence_case(strip_trailing_period(diagnostic.message))
}

///|
/// Returns the raw text of a 1-based line from config contents.
fn config_line_text(contents : String, line : Int) -> String {
  let mut current = 1
  for raw in contents.split("\n") {
    if current == line {
      return raw.to_string()
    }
    current += 1
  }
  ""
}

///|
/// Heuristically detects the common mistake `key value` instead of `key=value`.
///
/// The function skips leading whitespace, ignores comments, extracts the first
/// token, and checks whether that token looks like a directive key without an
/// equals sign.
fn config_line_missing_equals_after_key(line : String) -> Bool {
  let view = line[:]
  let mut i = 0
  while i < view.length() &&
        (view[i] == ' ' || view[i] == '\t' || view[i] == '\r') {
    i += 1
  }
  if i >= view.length() || view[i] == '#' {
    return false
  }
  let mut end_ = i
  while end_ < view.length() &&
        view[end_] != ' ' &&
        view[end_] != '\t' &&
        view[end_] != '\r' &&
        view[end_] != '#' {
    end_ += 1
  }
  let token = line.view(start_offset=i, end_offset=end_).to_string()
  token != "" && !token.contains("=")
}

///|
/// Removes one trailing period so the caller can compose a larger sentence
/// without ending up with doubled punctuation.
fn strip_trailing_period(text : String) -> String {
  if text.has_suffix(".") {
    text.view(end_offset=text.length() - 1).to_string()
  } else {
    text
  }
}

///|
/// Uppercases the first ASCII letter when needed.
fn sentence_case(text : String) -> String {
  if text == "" {
    return text
  }
  let view = text[:]
  let first = view[0]
  if first >= 'a' && first <= 'z' {
    (first - ('a' - 'A')).unsafe_to_char().to_string() +
    text.view(start_offset=1).to_string()
  } else {
    text
  }
}

///|
/// Converts parser diagnostics from rc parsing into positioned checker
/// diagnostics bound to the rc filename.
fn position_config_diagnostics(
  filename : String,
  diagnostics : Array[@parser.Diagnostic],
) -> Array[PositionedDiagnostic] {
  let positioned : Array[PositionedDiagnostic] = []
  for diagnostic in diagnostics {
    positioned.push({
      filename,
      span: diagnostic.span,
      severity: parse_severity(diagnostic.severity),
      code: diagnostic.code,
      message: diagnostic.message,
      fix: None,
    })
  }
  positioned
}

///|
/// Applies rc annotations that affect the checker spec itself.
///
/// Today rc files can contribute additional source paths and toggle external
/// source loading. The function returns a fresh spec instead of mutating the
/// original so config processing remains easy to reason about.
fn apply_config_to_spec(
  spec : CheckSpec,
  annotations : Array[@parser.Annotation],
) -> CheckSpec {
  if annotations.length() == 0 {
    return spec
  }
  // Copy first so the original `spec.source_paths` array stays untouched even
  // when multiple runs share the same base spec.
  let source_paths = copy_strings(spec.source_paths)
  for annotation in annotations {
    match annotation {
      @parser.Annotation::SourcePath(path) =>
        // `SCRIPTDIR` placeholders are expanded relative to the checked file,
        // not relative to the rc file itself.
        source_paths.push(expand_source_path(path, spec.filename))
      _ => ()
    }
  }
  {
    ..spec,
    external_sources: config_external_sources(
      spec.external_sources,
      annotations,
    ),
    source_paths,
  }
}

///|
/// Merges rc annotations into the parsed script so directive handling later in
/// the pipeline sees one unified annotation stream.
fn apply_config_to_script(
  script : @parser.Script,
  annotations : Array[@parser.Annotation],
) -> @parser.Script {
  @parser.merge_script_annotations(script, annotations)
}

///|
/// Resolves the effective `external_sources` flag.
///
/// An explicit CLI `true` always wins; otherwise the last matching config
/// annotation controls the setting.
fn config_external_sources(
  cli_external_sources : Bool,
  annotations : Array[@parser.Annotation],
) -> Bool {
  if cli_external_sources {
    return true
  }
  let mut enabled = false
  for annotation in annotations {
    match annotation {
      @parser.Annotation::ExternalSources(flag) => enabled = flag
      _ => ()
    }
  }
  enabled
}

///|
/// Expands `SCRIPTDIR` placeholders inside config-provided source paths.
fn expand_source_path(path : String, filename : String?) -> String {
  if !path.has_prefix("SCRIPTDIR") {
    return path
  }
  let scriptdir = match filename {
    Some(filename) => path_dirname(filename)
    None => "."
  }
  if path == "SCRIPTDIR" {
    return scriptdir
  }
  if path.has_prefix("SCRIPTDIR/") {
    return path_join(
      scriptdir,
      path.view(start_offset="SCRIPTDIR/".length()).to_string(),
    )
  }
  path
}

///|
/// Returns the first candidate path that exists in the preloaded config cache.
fn read_first_config_file(
  paths : Array[String],
  config_files : Array[(String, String)],
) -> (String, String)? {
  for path in paths {
    match lookup_config_file(config_files, path) {
      Some(contents) => return Some((path, contents))
      None => ()
    }
  }
  None
}

///|
/// Looks up preloaded config contents by path.
fn lookup_config_file(
  config_files : Array[(String, String)],
  path : String,
) -> String? {
  for pair in config_files {
    if pair.0 == path {
      return Some(pair.1)
    }
  }
  None
}

///|
/// Builds the ordered list of rc-file candidates for a source path.
fn config_candidate_paths(filename : String) -> Array[String] {
  let paths : Array[String] = []
  let mut dir = path_dirname(filename)
  while true {
    paths.push(path_join(dir, ".shellcheckrc"))
    paths.push(path_join(dir, "shellcheckrc"))
    let parent = path_dirname(dir)
    if parent == dir {
      break
    }
    dir = parent
  }
  paths
}

///|
/// Returns the directory portion of a POSIX-style path.
fn path_dirname(path : String) -> String {
  let view = path[:]
  let mut slash : Int? = None
  let mut i = 0
  while i < view.length() {
    if view[i] == '/' {
      slash = Some(i)
    }
    i += 1
  }
  match slash {
    None => "."
    Some(0) => "/"
    Some(index) => path.view(end_offset=index).to_string()
  }
}

///|
/// Joins two path fragments using simple POSIX rules.
fn path_join(base : String, relative : String) -> String {
  if relative.has_prefix("/") || base == "" {
    relative
  } else if base == "." {
    relative
  } else if base.has_suffix("/") {
    base + relative
  } else {
    base + "/" + relative
  }
}

///|
/// Copies parser annotations into a fresh array so callers can safely extend
/// or retain the result without aliasing the parser-owned array.
fn copy_parser_annotations(
  annotations : Array[@parser.Annotation],
) -> Array[@parser.Annotation] {
  let copied : Array[@parser.Annotation] = []
  for annotation in annotations {
    copied.push(annotation)
  }
  copied
}
