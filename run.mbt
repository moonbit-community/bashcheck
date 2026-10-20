///|
/// Error classes produced while parsing CLI flags.
///
/// The CLI distinguishes between usage mistakes made by the caller and support
/// errors where the syntax is valid but the requested feature/value is not
/// recognized. The distinction maps directly to different exit codes.
priv enum CliErrorKind {
  Usage
  Support
}

///|
/// Rich parse error used internally by the CLI layer before it is converted
/// into a `CliOutcome`.
priv struct CliError {
  kind : CliErrorKind
  message : String
}

///|
/// Three-state color selection used by `--color`.
///
/// `Auto` defers the decision to environment inspection so the parser can keep
/// rendering policy separate from string formatting logic.
priv enum CliColorOption {
  Auto
  Always
  Never
}

///|
/// Fully normalized command-line configuration consumed by `@driver.run_cli`.
///
/// All stringly CLI arguments are converted here into typed checker and
/// formatter options so the driver only executes already-validated requests.
priv struct CliConfig {
  spec : @checker.CheckSpec
  format : @formatter.OutputFormat
  format_options : @formatter.FormatOptions
  files : Array[String]
  action : @driver.CliAction
}

///|
/// Parses raw CLI arguments into a typed configuration using core argparse.
fn parse_cli_args(args : Array[String]) -> Result[CliConfig, CliError] {
  let options = @driver.cli_value_options()
  let (argv, action) = normalize_cli_args(args, options)
  let matches = @driver.cli_command().parse(argv~, env={}) catch {
    error => return Err(argparse_error(error))
  }
  let mut spec = @checker.CheckSpec::default()
  let mut format = @formatter.OutputFormat::default()
  let mut color = CliColorOption::Auto
  let mut wiki_link_count = 3
  for name, _ in matches.flags {
    match name {
      "check-sourced" => spec = spec.with_check_sourced(true)
      "external-sources" => spec = spec.with_external_sources(true)
      "norc" => spec = spec.with_ignore_rc(true)
      _ => ()
    }
  }
  for name, values in matches.values {
    for index, raw in values {
      match name {
        "format" =>
          if index == 0 {
            if @formatter.parse_output_format(raw) is Some(parsed) {
              format = parsed
            } else {
              return Err(unknown_format_error(raw))
            }
          }
        "shell" =>
          if parse_shell(raw) is Some(parsed) {
            spec = spec.with_shell_override(Some(parsed))
          } else {
            return Err(support_error("Unknown shell: " + raw))
          }
        "severity" =>
          if parse_severity(raw) is Some(parsed) {
            spec = spec.with_min_severity(parsed)
          } else {
            return Err(unknown_severity_error())
          }
        "include" =>
          match parse_code_list(raw) {
            Ok(parsed) =>
              spec = spec.with_include_codes(
                append_ints(spec.include_codes, parsed),
              )
            Err(error) => return Err(error)
          }
        "exclude" =>
          match parse_code_list(raw) {
            Ok(parsed) =>
              spec = spec.with_exclude_codes(
                append_ints(spec.exclude_codes, parsed),
              )
            Err(error) => return Err(error)
          }
        "enable" =>
          spec = spec.with_optional_checks(
            append_optional_checks(spec.optional_checks, split_csv(raw)),
          )
        "source-path" =>
          for entry in split_source_paths(raw) {
            spec = spec.add_source_path(entry)
          }
        "rcfile" => spec = spec.with_config_path_override(Some(raw))
        "color" =>
          match parse_color_option(raw) {
            Ok(parsed) => color = parsed
            Err(error) => return Err(error)
          }
        "wiki-link-count" =>
          match parse_nonnegative_int(raw) {
            Ok(parsed) => wiki_link_count = parsed
            Err(error) => return Err(error)
          }
        "extended-analysis" =>
          if parse_bool_value(raw) is Some(parsed) {
            spec = spec.with_extended_analysis(parsed)
          } else {
            return Err(
              usage_error("Invalid boolean, expected true/false: " + raw),
            )
          }
        _ => ()
      }
    }
  }
  let files = matches.values.get("files").unwrap_or([])
  if files.is_empty() && action is Run {
    files.push("-")
  }
  Ok({
    spec,
    format,
    format_options: @formatter.FormatOptions::default()
    .with_wiki_link_count(wiki_link_count)
    .with_enable_color(resolve_color(color)),
    files,
    action,
  })
}

///|
/// Argparse options require a value, while ShellCheck's color flag accepts an
/// attached value or defaults to "always" without consuming the next token.
/// Leave option values and everything following `--` untouched. Record the
/// first meta action here because Matches does not expose occurrence order.
fn normalize_cli_args(
  args : Array[String],
  options : Array[(String, Char?, String)],
) -> (Array[String], @driver.CliAction) {
  let normalized : Array[String] = []
  let mut action = @driver.CliAction::Run
  for index = 0; index < args.length(); {
    let arg = args[index]
    if arg == "--" {
      for rest in args[index:] {
        normalized.push(rest)
      }
      break
    }
    let mut token = arg
    let mut takes_next = false
    if arg.has_prefix("--") {
      let (flag, inline) = split_flag_value(arg)
      match flag {
        "--color" if inline is None => token = "--color=always"
        "--check-sourced" | "--external-sources" | "--norc" =>
          // The existing CLI ignores inline values on switches.
          token = flag
        "--list-optional" => {
          token = flag
          action = choose_action(action, ListOptional)
        }
        "--version" => {
          token = flag
          action = choose_action(action, ShowVersion)
        }
        "--help" => {
          token = flag
          action = choose_action(action, ShowHelp)
        }
        _ =>
          takes_next = inline is None &&
            options.any(option => flag == "--" + option.0)
      }
    } else if arg.has_prefix("-") && arg != "-" {
      let chars = arg.iter()
      ignore(chars.next())
      while chars.next() is Some(short) {
        if short == 'V' {
          action = choose_action(action, ShowVersion)
        }
        if options.any(option => option.1 == Some(short)) {
          let rest = String::from_iter(chars)
          if short == 'C' && rest == "" {
            token = arg + "always"
          } else {
            takes_next = rest == ""
          }
          break
        }
      }
    }
    normalized.push(token)
    if takes_next && index + 1 < args.length() {
      normalized.push(args[index + 1])
      continue index + 2
    }
    continue index + 1
  }
  (normalized, action)
}

///|
/// Argparse exposes display-ready errors. Adapt its syntax failures to the
/// established ShellCheck-compatible messages and usage exit code.
fn argparse_error(error : Error) -> CliError {
  let message = error.to_string().split("\n").next().unwrap_or("").to_owned()
  if message.strip_prefix("error: unexpected argument '") is Some(rest) &&
    rest.strip_suffix("' found") is Some(flag) {
    return usage_error("Unknown option: " + flag.to_owned())
  }
  if message.strip_prefix("error: a value is required for '") is Some(rest) &&
    rest.strip_suffix("' but none was supplied") is Some(flag) {
    return usage_error("Missing value for " + flag.to_owned())
  }
  usage_error(error.to_string())
}

///|
/// Keeps the first requested non-run action.
///
/// This makes `--help --version` deterministic: the first terminal action wins
/// and later ones are ignored instead of fighting over output.
fn choose_action(
  current : @driver.CliAction,
  next : @driver.CliAction,
) -> @driver.CliAction {
  match current {
    Run => next
    _ => current
  }
}

///|
/// Splits a long option into the flag name and optional inline value at the
/// first `=`.
fn split_flag_value(arg : String) -> (String, String?) {
  let view = arg[:]
  let mut i = 0
  while i < view.length() {
    if view[i] == '=' {
      return (
        arg.view(end_offset=i).to_owned(),
        Some(arg.view(start_offset=i + 1).to_owned()),
      )
    }
    i += 1
  }
  (arg, None)
}

///|
/// Parses color values after bare `--color` / `-C` have defaulted to "always".
fn parse_color_option(value : String) -> Result[CliColorOption, CliError] {
  match value {
    "auto" => Ok(Auto)
    "always" => Ok(Always)
    "never" => Ok(Never)
    _ =>
      Err(
        support_error(
          "Unknown value for --color. Valid options are: auto, always, never",
        ),
      )
  }
}

///|
/// Resolves the user-facing color mode into a concrete enable/disable flag.
///
/// `Auto` follows the common CLI convention of honoring `NO_COLOR` first and
/// otherwise enabling color only for non-dumb terminals.
fn resolve_color(color : CliColorOption) -> Bool {
  match color {
    Always => true
    Never => false
    Auto =>
      if @env.get_env_var("NO_COLOR") is Some(_) {
        false
      } else if @env.get_env_var("TERM") is Some(term) {
        term != "" && term != "dumb"
      } else {
        false
      }
  }
}

///|
/// Parses a strict boolean literal used by `--extended-analysis`.
fn parse_bool_value(text : String) -> Bool? {
  match text {
    "true" => Some(true)
    "false" => Some(false)
    _ => None
  }
}

///|
/// Parses a shell dialect name accepted by the CLI.
fn parse_shell(text : String) -> @semantics.ShellDialect? {
  match text {
    "sh" => Some(Sh)
    "bash" => Some(Bash)
    "dash" => Some(Dash)
    "ksh" => Some(Ksh)
    "busybox-sh" | "busybox" => Some(BusyboxSh)
    _ => None
  }
}

///|
/// Delegates severity parsing to the checker layer so the CLI and library API
/// share one canonical severity vocabulary.
fn parse_severity(text : String) -> @checker.DiagnosticSeverity? {
  @checker.parse_diagnostic_severity(text)
}

///|
/// Parses a comma-separated list of ShellCheck codes.
///
/// Each item may optionally include the `SC` prefix, but anything that is not a
/// clean non-negative integer is rejected.
fn parse_code_list(text : String) -> Result[Array[Int32], CliError] {
  let codes : Array[Int32] = []
  for value in split_csv(text) {
    if parse_code(value) is Some(code) {
      codes.push(code)
    } else {
      return Err(usage_error("Invalid number: " + value))
    }
  }
  Ok(codes)
}

///|
/// Parses one ShellCheck code in either `1234` or `SC1234` form.
fn parse_code(text : String) -> Int32? {
  let trimmed = text.trim().to_owned()
  let digits = if trimmed.has_prefix("SC") {
    trimmed.view(start_offset=2).to_owned()
  } else {
    trimmed
  }
  if digits == "" {
    return None
  }
  let view = digits[:]
  let mut value = 0
  let mut i = 0
  while i < view.length() {
    let ch = view[i]
    if ch < '0' || ch > '9' {
      return None
    }
    // Manual accumulation avoids depending on any looser integer parser that
    // might accept signs or whitespace the CLI does not want to allow.
    value = value * 10 + (ch - '0').to_int()
    i += 1
  }
  Some(value)
}

///|
/// Parses a non-negative integer and reuses the same validation rules as code
/// parsing so diagnostics stay consistent.
fn parse_nonnegative_int(text : String) -> Result[Int32, CliError] {
  if parse_code(text) is Some(value) {
    Ok(value)
  } else {
    Err(usage_error("Invalid number: " + text))
  }
}

///|
/// Splits a comma-separated list and discards empty / whitespace-only entries.
fn split_csv(text : String) -> Array[String] {
  let values : Array[String] = []
  for value in text.split(",") {
    let trimmed = value.to_owned().trim().to_owned()
    if trimmed != "" {
      values.push(trimmed)
    }
  }
  values
}

///|
/// Splits `--source-path` values.
///
/// ShellCheck accepts both `:` and `;` separated forms, so this parser uses `;`
/// when present and otherwise falls back to `:`.
fn split_source_paths(text : String) -> Array[String] {
  let separator = if text.contains(";") { ";" } else { ":" }
  let values : Array[String] = []
  for value in text.split(separator) {
    let trimmed = value.to_owned().trim().to_owned()
    if trimmed != "" {
      values.push(trimmed)
    }
  }
  values
}

///|
/// Returns a fresh array containing the contents of `lhs` followed by `rhs`.
fn append_ints(lhs : Array[Int32], rhs : Array[Int32]) -> Array[Int32] {
  let values : Array[Int32] = []
  for value in lhs {
    values.push(value)
  }
  for value in rhs {
    values.push(value)
  }
  values
}

///|
/// Appends optional-check names while preserving existing order and uniqueness.
///
/// The special `all` token expands to every supported optional check exactly
/// once at the point where it appears.
fn append_optional_checks(
  current : Array[String],
  additions : Array[String],
) -> Array[String] {
  let values : Array[String] = []
  for value in current {
    values.push(value)
  }
  let supported = @checker.supported_optional_checks()
  for value in additions {
    if value == "all" {
      for name in supported {
        if !values.contains(name) {
          values.push(name)
        }
      }
    } else if !values.contains(value) {
      values.push(value)
    }
  }
  values
}

///|
/// Constructs a usage error that should terminate with the CLI usage exit code.
fn usage_error(message : String) -> CliError {
  { kind: Usage, message, }
}

///|
/// Constructs a support error for syntactically valid but unsupported input.
fn support_error(message : String) -> CliError {
  { kind: Support, message, }
}

///|
/// Formats the list of supported renderer names for an unknown `--format`
/// request.
fn unknown_format_error(format : String) -> CliError {
  support_error(
    "Unknown format " +
    format +
    (
      #|
      #|Supported formats:
      #|  checkstyle
      #|  diff
      #|  gcc
      #|  json
      #|  json1
      #|  quiet
      #|  tty
    ),
  )
}

///|
/// Reuses ShellCheck's severity vocabulary in the error text.
fn unknown_severity_error() -> CliError {
  support_error(
    "Unknown value for --severity. Valid options are: error, warning, info, style",
  )
}

///|
/// Maps parser error classes to shell exit codes.
fn cli_exit_code(kind : CliErrorKind) -> Int32 {
  match kind {
    Usage => 3
    Support => 4
  }
}
