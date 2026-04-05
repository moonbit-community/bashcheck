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
/// Parses raw CLI arguments into a typed configuration.
///
/// The implementation performs a single left-to-right scan over argv. Long
/// options and short-option bundles share helpers so the resulting semantics
/// stay consistent regardless of spellings such as `--format=json` or `-fjson`.
fn parse_cli_args(args : Array[String]) -> Result[CliConfig, CliError] {
  // Start from the library defaults so CLI flags only need to describe
  // differences from the default checking behavior.
  let mut spec = @checker.CheckSpec::default()
  let mut format = @formatter.OutputFormat::default()
  // Once the user picked a format explicitly, later aliases must not silently
  // overwrite it.
  let mut format_locked = false
  let mut color = CliColorOption::Auto
  let mut wiki_link_count = 3
  let files : Array[String] = []
  let mut action = @driver.CliAction::Run
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--" {
      // `--` terminates option parsing. Everything after it is treated
      // literally, even if it starts with `-`.
      let mut j = i + 1
      while j < args.length() {
        files.push(args[j])
        j += 1
      }
      break
    }
    if arg == "-" || !arg.has_prefix("-") {
      // A bare `-` means stdin, and any non-flag token is a positional file.
      files.push(arg)
      i += 1
      continue
    }
    if arg.has_prefix("--") {
      // Long options either carry `--flag=value` inline or consume the next
      // argv element via `read_required_value`.
      match split_flag_value(arg) {
        ("--format", value) =>
          match read_required_value(value, args, i, "--format") {
            Ok((raw, next)) => {
              i = next
              if !format_locked {
                match @formatter.parse_output_format(raw) {
                  Some(parsed) => {
                    format = parsed
                    format_locked = true
                  }
                  None => return Err(unknown_format_error(raw))
                }
              }
            }
            Err(error) => return Err(error)
          }
        ("--shell", value) =>
          match read_required_value(value, args, i, "--shell") {
            Ok((shell, next)) => {
              i = next
              match parse_shell(shell) {
                Some(parsed) => spec = spec.with_shell_override(Some(parsed))
                None => return Err(support_error("Unknown shell: " + shell))
              }
            }
            Err(error) => return Err(error)
          }
        ("--severity", value) =>
          match read_required_value(value, args, i, "--severity") {
            Ok((severity, next)) => {
              i = next
              match parse_severity(severity) {
                Some(parsed) => spec = spec.with_min_severity(parsed)
                None => return Err(unknown_severity_error())
              }
            }
            Err(error) => return Err(error)
          }
        ("--include", value) =>
          match read_required_value(value, args, i, "--include") {
            Ok((codes, next)) => {
              i = next
              match parse_code_list(codes) {
                Ok(parsed) =>
                  spec = spec.with_include_codes(
                    append_ints(spec.include_codes, parsed),
                  )
                Err(error) => return Err(error)
              }
            }
            Err(error) => return Err(error)
          }
        ("--exclude", value) =>
          match read_required_value(value, args, i, "--exclude") {
            Ok((codes, next)) => {
              i = next
              match parse_code_list(codes) {
                Ok(parsed) =>
                  spec = spec.with_exclude_codes(
                    append_ints(spec.exclude_codes, parsed),
                  )
                Err(error) => return Err(error)
              }
            }
            Err(error) => return Err(error)
          }
        ("--enable", value) =>
          match read_required_value(value, args, i, "--enable") {
            Ok((names, next)) => {
              i = next
              spec = spec.with_optional_checks(
                append_optional_checks(spec.optional_checks, split_csv(names)),
              )
            }
            Err(error) => return Err(error)
          }
        ("--source-path", value) =>
          match read_required_value(value, args, i, "--source-path") {
            Ok((path, next)) => {
              i = next
              for entry in split_source_paths(path) {
                spec = spec.add_source_path(entry)
              }
            }
            Err(error) => return Err(error)
          }
        ("--rcfile", value) =>
          match read_required_value(value, args, i, "--rcfile") {
            Ok((path, next)) => {
              i = next
              spec = spec.with_config_path_override(Some(path))
            }
            Err(error) => return Err(error)
          }
        ("--color", value) =>
          match parse_color_option(value) {
            Ok(parsed) => color = parsed
            Err(error) => return Err(error)
          }
        ("--wiki-link-count", value) =>
          match read_required_value(value, args, i, "--wiki-link-count") {
            Ok((count, next)) => {
              i = next
              match parse_nonnegative_int(count) {
                Ok(parsed) => wiki_link_count = parsed
                Err(error) => return Err(error)
              }
            }
            Err(error) => return Err(error)
          }
        ("--norc", _) => spec = spec.with_ignore_rc(true)
        ("--check-sourced", _) => spec = spec.with_check_sourced(true)
        ("--external-sources", _) => spec = spec.with_external_sources(true)
        ("--extended-analysis", value) =>
          match read_required_value(value, args, i, "--extended-analysis") {
            Ok((enabled, next)) => {
              i = next
              match parse_bool_value(enabled) {
                Some(parsed) => spec = spec.with_extended_analysis(parsed)
                None =>
                  return Err(
                    usage_error(
                      "Invalid boolean, expected true/false: " + enabled,
                    ),
                  )
              }
            }
            Err(error) => return Err(error)
          }
        ("--list-optional", _) =>
          action = choose_action(action, @driver.CliAction::ListOptional)
        ("--version", _) =>
          action = choose_action(action, @driver.CliAction::ShowVersion)
        ("--help", _) =>
          action = choose_action(action, @driver.CliAction::ShowHelp)
        (flag, _) => return Err(usage_error("Unknown option: " + flag))
      }
      // Most long options consume at most one argv slot beyond the current one,
      // so the outer loop can safely advance by one after updating `i`.
      i += 1
      continue
    }
    // Single-dash options may be bundled (`-axV`) or may end with a value
    // carrier (`-fjson`, `-W2`, `-s bash`).
    match parse_short_options(arg, args, i, spec, format_locked) {
      Ok((next, parsed)) => {
        i = next
        spec = parsed.0
        match parsed.1 {
          Some(parsed_format) =>
            if !format_locked {
              format = parsed_format
              format_locked = true
            }
          None => ()
        }
        match parsed.2 {
          Some(parsed_color) => color = parsed_color
          None => ()
        }
        match parsed.3 {
          Some(count) => wiki_link_count = count
          None => ()
        }
        action = choose_action(action, parsed.4)
      }
      Err(error) => return Err(error)
    }
    i += 1
  }
  if files.length() == 0 && action is @driver.CliAction::Run {
    // Match ShellCheck's CLI behavior: a plain run with no files reads stdin.
    files.push("-")
  }
  Ok({
    spec,
    format,
    // Color and wiki-link settings are formatter concerns, so they are
    // packaged separately from the checker spec.
    format_options: @formatter.FormatOptions::default()
    .with_wiki_link_count(wiki_link_count)
    .with_enable_color(resolve_color(color)),
    files,
    action,
  })
}

///|
/// Parses a short-option cluster such as `-ax`, `-fjson`, or `-S error`.
///
/// Flags that require a value consume either the remainder of the current token
/// or the next argv element and then return immediately, because any trailing
/// characters belong to that value rather than to more flags.
fn parse_short_options(
  arg : String,
  args : Array[String],
  index : Int,
  current_spec : @checker.CheckSpec,
  ignore_format : Bool,
) -> Result[
  (
    Int,
    (
      @checker.CheckSpec,
      @formatter.OutputFormat?,
      CliColorOption?,
      Int?,
      @driver.CliAction,
    ),
  ),
  CliError,
] {
  let mut spec = current_spec
  let mut format : @formatter.OutputFormat? = None
  let mut color : CliColorOption? = None
  let mut wiki_link_count : Int? = None
  let mut action = @driver.CliAction::Run
  let flags = arg.view(start_offset=1).to_string()
  guard flags != "" else { return Err(usage_error("Unknown option: " + arg)) }
  let view = flags[:]
  let mut j = 0
  let mut next = index
  while j < view.length() {
    let flag = view[j]
    let rest = flags.view(start_offset=j + 1).to_string()
    match flag {
      'a' => spec = spec.with_check_sourced(true)
      'x' => spec = spec.with_external_sources(true)
      'V' => action = @driver.CliAction::ShowVersion
      'C' => {
        // `-Cauto` and `-C auto` both funnel through the same parser. A bare
        // `-C` means "force color on", which matches `--color` without value.
        match parse_color_option(if rest == "" { None } else { Some(rest) }) {
          Ok(parsed) => color = Some(parsed)
          Err(error) => return Err(error)
        }
        return Ok((next, (spec, format, color, wiki_link_count, action)))
      }
      'f' => {
        // Options with values stop bundle processing because the remaining text
        // belongs to the value, not to another single-character flag.
        let (raw, consumed) = match read_short_value(rest, args, index, "-f") {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next = consumed
        if !ignore_format {
          match @formatter.parse_output_format(raw) {
            Some(parsed) => format = Some(parsed)
            None => return Err(unknown_format_error(raw))
          }
        }
        return Ok((next, (spec, format, color, wiki_link_count, action)))
      }
      's' => {
        let (raw, consumed) = match read_short_value(rest, args, index, "-s") {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next = consumed
        match parse_shell(raw) {
          Some(parsed) => spec = spec.with_shell_override(Some(parsed))
          None => return Err(support_error("Unknown shell: " + raw))
        }
        return Ok((next, (spec, format, color, wiki_link_count, action)))
      }
      'S' => {
        let (raw, consumed) = match read_short_value(rest, args, index, "-S") {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next = consumed
        match parse_severity(raw) {
          Some(parsed) => spec = spec.with_min_severity(parsed)
          None => return Err(unknown_severity_error())
        }
        return Ok((next, (spec, format, color, wiki_link_count, action)))
      }
      'i' => {
        let (raw, consumed) = match read_short_value(rest, args, index, "-i") {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next = consumed
        match parse_code_list(raw) {
          Ok(parsed) =>
            spec = spec.with_include_codes(
              append_ints(spec.include_codes, parsed),
            )
          Err(error) => return Err(error)
        }
        return Ok((next, (spec, format, color, wiki_link_count, action)))
      }
      'e' => {
        let (raw, consumed) = match read_short_value(rest, args, index, "-e") {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next = consumed
        match parse_code_list(raw) {
          Ok(parsed) =>
            spec = spec.with_exclude_codes(
              append_ints(spec.exclude_codes, parsed),
            )
          Err(error) => return Err(error)
        }
        return Ok((next, (spec, format, color, wiki_link_count, action)))
      }
      'o' => {
        let (raw, consumed) = match read_short_value(rest, args, index, "-o") {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next = consumed
        spec = spec.with_optional_checks(
          append_optional_checks(spec.optional_checks, split_csv(raw)),
        )
        return Ok((next, (spec, format, color, wiki_link_count, action)))
      }
      'P' => {
        let (raw, consumed) = match read_short_value(rest, args, index, "-P") {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next = consumed
        for entry in split_source_paths(raw) {
          spec = spec.add_source_path(entry)
        }
        return Ok((next, (spec, format, color, wiki_link_count, action)))
      }
      'W' => {
        let (raw, consumed) = match read_short_value(rest, args, index, "-W") {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        next = consumed
        match parse_nonnegative_int(raw) {
          Ok(parsed) => wiki_link_count = Some(parsed)
          Err(error) => return Err(error)
        }
        return Ok((next, (spec, format, color, wiki_link_count, action)))
      }
      _ => return Err(usage_error("Unknown option: -" + flag.to_string()))
    }
    j += 1
  }
  Ok((next, (spec, format, color, wiki_link_count, action)))
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
    @driver.CliAction::Run => next
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
        arg.view(end_offset=i).to_string(),
        Some(arg.view(start_offset=i + 1).to_string()),
      )
    }
    i += 1
  }
  (arg, None)
}

///|
/// Reads the required value for a long option from either `--flag=value` or the
/// next argv entry.
fn read_required_value(
  inline : String?,
  args : Array[String],
  index : Int,
  flag : String,
) -> Result[(String, Int), CliError] {
  match inline {
    Some(value) => Ok((value, index))
    None =>
      if index + 1 < args.length() {
        Ok((args[index + 1], index + 1))
      } else {
        Err(usage_error("Missing value for " + flag))
      }
  }
}

///|
/// Reads the value for a short option from the remainder of the current token
/// or the next argv entry.
fn read_short_value(
  inline : String,
  args : Array[String],
  index : Int,
  flag : String,
) -> Result[(String, Int), CliError] {
  if inline != "" {
    return Ok((inline, index))
  }
  if index + 1 < args.length() {
    return Ok((args[index + 1], index + 1))
  }
  Err(usage_error("Missing value for " + flag))
}

///|
/// Parses `--color` / `-C` semantics.
///
/// The slightly unusual `None => Always` branch is intentional: a present
/// flag without a value means "turn color on", not "auto-detect".
fn parse_color_option(value : String?) -> Result[CliColorOption, CliError] {
  match value {
    None => Ok(CliColorOption::Always)
    Some("auto") => Ok(CliColorOption::Auto)
    Some("always") => Ok(CliColorOption::Always)
    Some("never") => Ok(CliColorOption::Never)
    Some(_) =>
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
    CliColorOption::Always => true
    CliColorOption::Never => false
    CliColorOption::Auto =>
      if @env.get_env_var("NO_COLOR") is Some(_) {
        false
      } else {
        match @env.get_env_var("TERM") {
          Some(term) => term != "" && term != "dumb"
          None => false
        }
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
    "sh" => Some(@semantics.ShellDialect::Sh)
    "bash" => Some(@semantics.ShellDialect::Bash)
    "dash" => Some(@semantics.ShellDialect::Dash)
    "ksh" => Some(@semantics.ShellDialect::Ksh)
    "busybox-sh" | "busybox" => Some(@semantics.ShellDialect::BusyboxSh)
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
fn parse_code_list(text : String) -> Result[Array[Int], CliError] {
  let codes : Array[Int] = []
  for value in split_csv(text) {
    match parse_code(value) {
      Some(code) => codes.push(code)
      None => return Err(usage_error("Invalid number: " + value))
    }
  }
  Ok(codes)
}

///|
/// Parses one ShellCheck code in either `1234` or `SC1234` form.
fn parse_code(text : String) -> Int? {
  let trimmed = text.trim().to_string()
  let digits = if trimmed.has_prefix("SC") {
    trimmed.view(start_offset=2).to_string()
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
fn parse_nonnegative_int(text : String) -> Result[Int, CliError] {
  match parse_code(text) {
    Some(value) => Ok(value)
    None => Err(usage_error("Invalid number: " + text))
  }
}

///|
/// Splits a comma-separated list and discards empty / whitespace-only entries.
fn split_csv(text : String) -> Array[String] {
  let values : Array[String] = []
  for value in text.split(",") {
    let trimmed = value.to_string().trim().to_string()
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
    let trimmed = value.to_string().trim().to_string()
    if trimmed != "" {
      values.push(trimmed)
    }
  }
  values
}

///|
/// Returns a fresh array containing the contents of `lhs` followed by `rhs`.
fn append_ints(lhs : Array[Int], rhs : Array[Int]) -> Array[Int] {
  let values : Array[Int] = []
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
  { kind: CliErrorKind::Usage, message }
}

///|
/// Constructs a support error for syntactically valid but unsupported input.
fn support_error(message : String) -> CliError {
  { kind: CliErrorKind::Support, message }
}

///|
/// Formats the list of supported renderer names for an unknown `--format`
/// request.
fn unknown_format_error(format : String) -> CliError {
  support_error(
    "Unknown format " +
    format +
    "\nSupported formats:\n  checkstyle\n  diff\n  gcc\n  json\n  json1\n  quiet\n  tty",
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
fn cli_exit_code(kind : CliErrorKind) -> Int {
  match kind {
    CliErrorKind::Usage => 3
    CliErrorKind::Support => 4
  }
}
