///|
/// The rendered output and process exit code produced by the CLI driver.
pub struct CliOutcome {
  output : String
  exit_code : Int
} derive(Eq, Debug)

///|
/// Constructs a CLI outcome from rendered output and an exit code.
pub fn CliOutcome::new(output : String, exit_code : Int) -> CliOutcome {
  { output, exit_code }
}

///|
/// High-level actions supported by the CLI driver.
pub(all) enum CliAction {
  Run
  ShowHelp
  ShowVersion
  ListOptional
} derive(Eq, Debug)

///|
/// Executes one CLI action over the provided files and formatter settings.
///
/// This function is the boundary between argument parsing and real work. It
/// decides whether to render static text (`--help`, `--version`, etc.) or to
/// run the checker pipeline and convert the resulting diagnostics into both a
/// textual report and the shell exit code expected by callers.
pub async fn run_cli(
  action : CliAction,
  files : Array[String],
  spec : @checker.CheckSpec,
  format : @formatter.OutputFormat,
  format_options : @formatter.FormatOptions,
) -> CliOutcome {
  match action {
    CliAction::ShowHelp => { output: cli_usage_text(), exit_code: 0 }
    CliAction::ShowVersion => { output: "bashcheck 0.1.0", exit_code: 0 }
    CliAction::ListOptional =>
      { output: @checker.list_optional_checks_text(), exit_code: 0 }
    CliAction::Run =>
      match
        collect_results(files, spec, format is @formatter.OutputFormat::Quiet) {
        Ok(results) => {
          // Rendering is format-dependent, but exit-status semantics are not:
          // any reported diagnostic means the run should fail with exit code 1.
          let output = @formatter.render_results(
            results,
            format,
            options=format_options,
          )
          { output, exit_code: if any_diagnostics(results) { 1 } else { 0 } }
        }
        Err(message) => { output: message, exit_code: 2 }
      }
  }
}

///|
/// Checks the requested files one by one and stops early for quiet output.
///
/// Quiet mode only cares whether at least one issue exists, so it can short
/// circuit after the first diagnostic-producing file to avoid unnecessary work.
async fn collect_results(
  files : Array[String],
  spec : @checker.CheckSpec,
  stop_after_first_issue : Bool,
) -> Result[Array[@checker.CheckResult], String] {
  let results : Array[@checker.CheckResult] = []
  for file in files {
    let result = check_cli_file(file, spec) catch {
      // Surface IO failures using the user-facing file label so stdin reads
      // mention `<stdin>` instead of `/dev/stdin`.
      Failure::Failure(message) =>
        return Err(display_cli_filename(file) + ": " + message)
      err => return Err(display_cli_filename(file) + ": " + err.to_string())
    }
    results.push(result)
    if stop_after_first_issue && result.diagnostics.length() > 0 {
      break
    }
  }
  Ok(results)
}

///|
/// Loads one file (or stdin), preloads configuration, and delegates to the
/// library checker entry point.
async fn check_cli_file(
  file : String,
  spec : @checker.CheckSpec,
) -> @checker.CheckResult {
  // Internally stdin is read from `/dev/stdin`, but diagnostics should still
  // render the more conventional `<stdin>` filename.
  let actual_path = if file == "-" { "/dev/stdin" } else { file }
  let filename = if file == "-" { Some("<stdin>") } else { Some(file) }
  let source = @fs.read_file(actual_path).text()
  let loaded_spec = preload_config(spec.with_filename(filename))
  @checker.check_script(source, spec=loaded_spec)
}

///|
/// Preloads rc configuration according to the current spec.
///
/// The checker accepts config contents in-memory via `config_files`, so the
/// driver resolves filesystem paths once here and passes pure data downward.
async fn preload_config(spec : @checker.CheckSpec) -> @checker.CheckSpec {
  if spec.ignore_rc {
    return spec
  }
  match spec.config_path_override {
    Some(path) => preload_config_path(spec, path)
    None => preload_first_config_file(spec)
  }
}

///|
/// Loads a user-specified rc file if it has not already been preloaded.
async fn preload_config_path(
  spec : @checker.CheckSpec,
  path : String,
) -> @checker.CheckSpec {
  if lookup_config_file(spec.config_files, path) is Some(_) {
    // The same file may be requested repeatedly across multiple inputs; avoid
    // re-reading it once cached in the spec.
    return spec
  }
  match try_read_file_to_string(path) {
    Some(contents) =>
      spec.with_config_files(
        append_config_file(spec.config_files, path, contents),
      )
    None => spec
  }
}

///|
/// Searches parent directories for the first available rc file.
///
/// The search order mirrors ShellCheck: start near the checked file and walk up
/// toward the filesystem root, trying both `.shellcheckrc` and `shellcheckrc`
/// in each directory.
async fn preload_first_config_file(
  spec : @checker.CheckSpec,
) -> @checker.CheckSpec {
  let filename = match current_path_for_config(spec.filename) {
    Some(filename) => filename
    None => return spec
  }
  for path in config_candidate_paths(filename) {
    if lookup_config_file(spec.config_files, path) is Some(_) {
      return spec
    }
    match try_read_file_to_string(path) {
      Some(contents) =>
        // Stop at the first readable config file so nearer directories win.
        return spec.with_config_files(
          append_config_file(spec.config_files, path, contents),
        )
      None => ()
    }
  }
  spec
}

///|
/// Best-effort file read used during rc discovery.
///
/// Missing or unreadable config files are not fatal; they simply mean "keep
/// searching" or "act as if no rc file exists".
async fn try_read_file_to_string(path : String) -> String? {
  Some(@fs.read_file(path).text()) catch {
    _ => None
  }
}

///|
/// Looks up already-loaded config contents by path.
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
/// Returns a fresh config cache array with one more `(path, contents)` pair.
fn append_config_file(
  config_files : Array[(String, String)],
  path : String,
  contents : String,
) -> Array[(String, String)] {
  let copied : Array[(String, String)] = []
  for pair in config_files {
    copied.push(pair)
  }
  copied.push((path, contents))
  copied
}

///|
/// Converts display filenames back into real paths suitable for config lookup.
///
/// Synthetic names such as `<stdin>` and `<input>` do not correspond to actual
/// directories, so they must not participate in rc file discovery.
fn current_path_for_config(filename : String?) -> String? {
  match filename {
    Some("<stdin>") => None
    Some("<input>") => None
    Some(name) => Some(name)
    None => None
  }
}

///|
/// Builds the ordered rc-file search list for a source file.
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
///
/// The logic intentionally preserves `/` as the dirname of root and falls back
/// to `.` when no slash is present, matching common shell expectations.
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
/// Joins `base` and `relative` using simple POSIX path rules.
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
/// Reports whether any checked file produced at least one diagnostic.
fn any_diagnostics(results : Array[@checker.CheckResult]) -> Bool {
  for result in results {
    if result.diagnostics.length() > 0 {
      return true
    }
  }
  false
}

///|
/// Converts the internal stdin marker back into the label shown to users.
fn display_cli_filename(file : String) -> String {
  if file == "-" {
    "<stdin>"
  } else {
    file
  }
}

///|
/// Returns the static CLI help text.
///
/// Keeping the usage text here instead of in the parser lets both `--help` and
/// parse failures share the same canonical option list.
fn cli_usage_text() -> String {
  [
    "Usage: bashcheck [OPTIONS...] FILES...", "  -a                  --check-sourced            Include warnings from sourced files",
    "  -C[WHEN]            --color[=WHEN]             Use color (auto, always, never)",
    "  -i CODE1,CODE2..    --include=CODE1,CODE2..    Consider only given types of warnings",
    "  -e CODE1,CODE2..    --exclude=CODE1,CODE2..    Exclude types of warnings",
    "                      --extended-analysis=bool   Perform dataflow analysis (default true)",
    "  -f FORMAT           --format=FORMAT            Output format (checkstyle, diff, gcc, json, json1, quiet, tty)",
    "                      --list-optional            List checks disabled by default",
    "                      --norc                     Don't look for .shellcheckrc files",
    "                      --rcfile=RCFILE            Prefer the specified configuration file over searching for one",
    "  -o check1,check2..  --enable=check1,check2..   List of optional checks to enable (or 'all')",
    "  -P SOURCEPATHS      --source-path=SOURCEPATHS  Specify path when looking for sourced files (\"SCRIPTDIR\" for script's dir)",
    "  -s SHELLNAME        --shell=SHELLNAME          Specify dialect (sh, bash, dash, ksh, busybox)",
    "  -S SEVERITY         --severity=SEVERITY        Minimum severity of errors to consider (error, warning, info, style)",
    "  -V                  --version                  Print version information",
    "  -W NUM              --wiki-link-count=NUM      The number of wiki links to show, when applicable",
    "  -x                  --external-sources         Allow 'source' outside of FILES",
    "                      --help                     Show this usage summary and exit",
  ].join("\n")
}
