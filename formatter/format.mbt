///|
/// Output formats supported by the public formatter API and CLI.
pub enum OutputFormat {
  Tty
  Json
  Json1
  Gcc
  CheckStyle
  Quiet
  Diff
} derive(Eq, Debug)

///|
/// Formatting knobs shared by multiple output renderers.
pub struct FormatOptions {
  wiki_link_count : Int
  enable_color : Bool
} derive(Eq, Debug)

///|
/// Returns the default formatting options.
pub fn FormatOptions::default() -> FormatOptions {
  { wiki_link_count: 3, enable_color: false }
}

///|
/// Returns a copy of the options with a new wiki-link limit.
pub fn FormatOptions::with_wiki_link_count(
  self : FormatOptions,
  wiki_link_count : Int,
) -> FormatOptions {
  { ..self, wiki_link_count, }
}

///|
/// Returns a copy of the options with ANSI color output enabled or disabled.
pub fn FormatOptions::with_enable_color(
  self : FormatOptions,
  enable_color : Bool,
) -> FormatOptions {
  { ..self, enable_color, }
}

///|
/// Returns the default output format used by the CLI.
pub fn OutputFormat::default() -> OutputFormat {
  OutputFormat::Tty
}

///|
/// Parses a lowercase format name such as `tty`, `json`, or `diff`.
pub fn parse_output_format(text : String) -> OutputFormat? {
  match text {
    "tty" => Some(OutputFormat::Tty)
    "json" => Some(OutputFormat::Json)
    "json1" => Some(OutputFormat::Json1)
    "gcc" => Some(OutputFormat::Gcc)
    "checkstyle" => Some(OutputFormat::CheckStyle)
    "quiet" => Some(OutputFormat::Quiet)
    "diff" => Some(OutputFormat::Diff)
    _ => None
  }
}

///|
/// Renders checker results using the selected output format.
///
/// All public rendering requests flow through this dispatcher, which keeps the
/// CLI and library API aligned on exactly the same formatter behavior.
pub fn render_results(
  results : Array[@checker.CheckResult],
  format : OutputFormat,
  options? : FormatOptions = FormatOptions::default(),
) -> String {
  match format {
    OutputFormat::Tty => render_tty(results, options)
    OutputFormat::Json => render_json(results)
    OutputFormat::Json1 => render_json1(results)
    OutputFormat::Gcc => render_gcc(results)
    OutputFormat::CheckStyle => render_checkstyle(results)
    OutputFormat::Quiet => render_quiet(results)
    OutputFormat::Diff => render_diff(results, options)
  }
}

///|
/// Converts a diagnostic severity into the textual level used by renderers.
pub fn severity_text(diagnostic : @checker.PositionedDiagnostic) -> String {
  match diagnostic.severity {
    @checker.DiagnosticSeverity::Error => "error"
    @checker.DiagnosticSeverity::Warning => "warning"
    @checker.DiagnosticSeverity::Info => "info"
    @checker.DiagnosticSeverity::Style => "style"
  }
}

///|
/// Formats a diagnostic code in the `SC1234` style ShellCheck users expect.
fn code_text(diagnostic : @checker.PositionedDiagnostic) -> String {
  match diagnostic.code {
    Some(code) => "SC" + code.to_string()
    None => "SC?"
  }
}

///|
/// Returns the source text for a 1-based line number in one check result.
fn line_text(result : @checker.CheckResult, line : Int) -> String {
  let lines = split_lines(result.source)
  if 1 <= line && line <= lines.length() {
    lines[line - 1]
  } else {
    ""
  }
}

///|
/// Splits source text into logical lines without retaining newline characters.
///
/// This helper is shared across multiple renderers so they all agree on how
/// line-based excerpts and diffs are computed.
fn split_lines(source : String) -> Array[String] {
  let lines : Array[String] = []
  let view = source[:]
  let mut start = 0
  let mut i = 0
  while i < view.length() {
    if view[i] == '\n' {
      lines.push(source.view(start_offset=start, end_offset=i).to_string())
      start = i + 1
    }
    i += 1
  }
  if start < view.length() {
    lines.push(source.view(start_offset=start).to_string())
  }
  lines
}

///|
/// Reports whether ANSI color sequences should be emitted.
fn supports_color(options : FormatOptions) -> Bool {
  options.enable_color
}

///|
/// Wraps text in one ANSI escape sequence when color is enabled.
fn ansi_wrap(code : Int, text : String, options : FormatOptions) -> String {
  if supports_color(options) {
    "\u001B[\{code}m" + text + "\u001B[0m"
  } else {
    text
  }
}

///|
/// Applies severity-aware coloring for tty output.
fn tty_color(level : String, text : String, options : FormatOptions) -> String {
  match level {
    "error" => ansi_wrap(31, text, options)
    "warning" => ansi_wrap(33, text, options)
    "info" => ansi_wrap(32, text, options)
    "style" => ansi_wrap(32, text, options)
    "message" => ansi_wrap(1, text, options)
    "source" => text
    _ => text
  }
}

///|
/// Applies diff-specific coloring for unified diff output.
fn diff_color(level : String, text : String, options : FormatOptions) -> String {
  match level {
    "header" => ansi_wrap(1, text, options)
    "hunk" => ansi_wrap(36, text, options)
    "remove" => ansi_wrap(31, text, options)
    "add" => ansi_wrap(32, text, options)
    "error" => ansi_wrap(1, ansi_wrap(31, text, options), options)
    _ => text
  }
}

///|
/// Truncates long text while reserving room for an ellipsis when possible.
fn shorten_text(text : String, max_length : Int) -> String {
  if text.length() <= max_length {
    text
  } else if max_length <= 3 {
    text.view(end_offset=max_length).to_string()
  } else {
    text.view(end_offset=max_length - 3).to_string() + "..."
  }
}

///|
/// Returns the smaller of two integers.
fn min_int(lhs : Int, rhs : Int) -> Int {
  if lhs < rhs {
    lhs
  } else {
    rhs
  }
}

///|
/// Returns the larger of two integers.
fn max_int(lhs : Int, rhs : Int) -> Int {
  if lhs > rhs {
    lhs
  } else {
    rhs
  }
}

///|
/// Escapes a string as JSON by delegating to the JSON encoder.
///
/// Reusing the encoder avoids duplicating string-escaping logic in each JSON
/// renderer.
fn json_escape(text : String) -> String {
  Json::string(text).stringify()
}

///|
/// Renders one replacement object using the JSON schema expected by compatible
/// ShellCheck consumers.
fn render_replacement_json(replacement : @fixer.Replacement) -> String {
  let insertion_point = match replacement.insertion_point {
    @fixer.InsertionPoint::InsertBefore => "beforeStart"
    @fixer.InsertionPoint::InsertAfter => "afterEnd"
  }
  "{\"column\":\{replacement.start.column},\"endColumn\":\{replacement.end.column},\"endLine\":\{replacement.end.line},\"insertionPoint\":\{json_escape(insertion_point)},\"line\":\{replacement.start.line},\"precedence\":\{replacement.precedence},\"replacement\":\{json_escape(replacement.text)}}"
}

///|
/// Renders an optional fix as either a JSON object or `null`.
fn render_fix_json(fix : @fixer.Fix?) -> String {
  match fix {
    Some(fix) => {
      let replacements : Array[String] = []
      for replacement in fix.replacements {
        replacements.push(render_replacement_json(replacement))
      }
      "{\"replacements\":[" + replacements.join(",") + "]}"
    }
    None => "null"
  }
}

///|
/// Renders one diagnostic as a ShellCheck-style JSON comment object.
fn render_comment_json(diagnostic : @checker.PositionedDiagnostic) -> String {
  let code_json = match diagnostic.code {
    Some(code) => code.to_string()
    None => "null"
  }
  "{\"file\":\{json_escape(diagnostic.filename)},\"line\":\{diagnostic.span.start.line},\"endLine\":\{diagnostic.span.end.line},\"column\":\{diagnostic.span.start.column},\"endColumn\":\{diagnostic.span.end.column},\"level\":\{json_escape(severity_text(diagnostic))},\"code\":\{code_json},\"message\":\{json_escape(diagnostic.message)},\"fix\":\{render_fix_json(diagnostic.fix)}}"
}
