///|
/// Base URL used for ShellCheck wiki references in tty output.
const WIKI_LINK_PREFIX = "https://www.shellcheck.net/wiki/"

///|
/// One unique wiki entry collected from the rendered diagnostics.
///
/// Entries are deduplicated by code and later sorted so the footer stays short
/// and deterministic even when many diagnostics share the same code.
struct WikiEntry {
  severity : @checker.DiagnosticSeverity
  code : Int
  message : String
} derive(Eq, Debug)

///|
/// Renders diagnostics in the human-oriented tty format.
///
/// Diagnostics are grouped by `(filename, line)` so the source line is printed
/// once, followed by every diagnostic arrow for that line and an optional fix
/// excerpt.
fn render_tty(
  results : Array[@checker.CheckResult],
  options : FormatOptions,
) -> String {
  let lines : Array[String] = []
  let wiki_entries : Array[WikiEntry] = []
  let mut is_first_group = true
  for result in results {
    let mut i = 0
    while i < result.diagnostics.length() {
      // Adjacent diagnostics are already sorted, so grouping by line can be
      // implemented as a simple forward scan.
      let group = diagnostics_for_line(result.diagnostics, i)
      let head = group[0]
      if !is_first_group {
        lines.push("")
      }
      is_first_group = false
      lines.push(
        tty_color(
          "message",
          "In \{head.filename} line \{head.span.start.line}:",
          options,
        ),
      )
      lines.push(
        tty_color("source", line_text(result, head.span.start.line), options),
      )
      for diagnostic in group {
        lines.push(
          tty_color(severity_text(diagnostic), cute_indent(diagnostic), options),
        )
        remember_wiki_entry(wiki_entries, diagnostic)
      }
      match render_group_fix_excerpt(result.source, group) {
        Some(excerpt) => {
          // When multiple diagnostics on the same line contribute compatible
          // fixes, show the merged replacement result directly below them.
          lines.push("")
          lines.push(tty_color("message", "Did you mean:", options))
          lines.push(excerpt)
        }
        None => ()
      }
      i += group.length()
    }
  }
  append_wiki_footer(lines, wiki_entries, options)
  lines.join("\n")
}

///|
/// Collects the maximal run of diagnostics that point to the same file and
/// starting line.
fn diagnostics_for_line(
  diagnostics : Array[@checker.PositionedDiagnostic],
  start : Int,
) -> Array[@checker.PositionedDiagnostic] {
  let grouped : Array[@checker.PositionedDiagnostic] = []
  let filename = diagnostics[start].filename
  let line = diagnostics[start].span.start.line
  let mut i = start
  while i < diagnostics.length() &&
        diagnostics[i].filename == filename &&
        diagnostics[i].span.start.line == line {
    grouped.push(diagnostics[i])
    i += 1
  }
  grouped
}

///|
/// Adds one diagnostic to the wiki footer set if it has a code we have not
/// seen yet.
fn remember_wiki_entry(
  wiki_entries : Array[WikiEntry],
  diagnostic : @checker.PositionedDiagnostic,
) -> Unit {
  match diagnostic.code {
    Some(code) =>
      if !wiki_entries_contains(wiki_entries, code) {
        wiki_entries.push({
          severity: diagnostic.severity,
          code,
          message: diagnostic.message,
        })
      }
    None => ()
  }
}

///|
/// Returns whether a wiki entry for `code` is already present.
fn wiki_entries_contains(entries : Array[WikiEntry], code : Int) -> Bool {
  for entry in entries {
    if entry.code == code {
      return true
    }
  }
  false
}

///|
/// Appends the "For more information" footer when enabled by options.
///
/// The footer is intentionally capped because tty output should remain readable
/// even for files with many warnings.
fn append_wiki_footer(
  lines : Array[String],
  wiki_entries : Array[WikiEntry],
  options : FormatOptions,
) -> Unit {
  if options.wiki_link_count <= 0 || wiki_entries.length() == 0 {
    return
  }
  if lines.length() > 0 {
    lines.push("")
  }
  lines.push(tty_color("message", "For more information:", options))
  let sorted_entries = sort_wiki_entries(wiki_entries)
  let limit = min_int(options.wiki_link_count, sorted_entries.length())
  let mut i = 0
  while i < limit {
    let entry = sorted_entries[i]
    lines.push(
      "  " +
      WIKI_LINK_PREFIX +
      "SC" +
      entry.code.to_string() +
      " -- " +
      shorten_text(entry.message, 36),
    )
    i += 1
  }
}

///|
/// Sorts wiki entries by severity, then code, then message.
fn sort_wiki_entries(entries : Array[WikiEntry]) -> Array[WikiEntry] {
  let sorted : Array[WikiEntry] = []
  for entry in entries {
    sorted.push(entry)
  }
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      // The entry count is tiny, so a hand-written sort keeps the ordering
      // rules obvious without adding abstraction.
      if wiki_entry_precedes(sorted[j], sorted[i]) {
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
/// Returns whether `lhs` should appear before `rhs` in the wiki footer.
fn wiki_entry_precedes(lhs : WikiEntry, rhs : WikiEntry) -> Bool {
  let lhs_rank = wiki_entry_severity_rank(lhs.severity)
  let rhs_rank = wiki_entry_severity_rank(rhs.severity)
  if lhs_rank != rhs_rank {
    return lhs_rank < rhs_rank
  }
  if lhs.code != rhs.code {
    return lhs.code < rhs.code
  }
  lhs.message < rhs.message
}

///|
/// Maps severities to footer sort priority.
fn wiki_entry_severity_rank(severity : @checker.DiagnosticSeverity) -> Int {
  match severity {
    @checker.DiagnosticSeverity::Error => 0
    @checker.DiagnosticSeverity::Warning => 1
    @checker.DiagnosticSeverity::Info => 2
    @checker.DiagnosticSeverity::Style => 3
  }
}

///|
/// Renders the merged fix excerpt for one diagnostic group, if possible.
///
/// Only diagnostics with fixes participate; incompatible fixes are silently
/// dropped because tty rendering is best-effort and should not fail the run.
fn render_group_fix_excerpt(
  source : String,
  diagnostics : Array[@checker.PositionedDiagnostic],
) -> String? {
  let fixes : Array[@fixer.Fix] = []
  for diagnostic in diagnostics {
    match diagnostic.fix {
      Some(fix) => fixes.push(fix)
      None => ()
    }
  }
  if fixes.length() == 0 {
    return None
  }
  match @fixer.merge_fixes(fixes) {
    Some(merged) =>
      match @fixer.apply_fix(merged, source) {
        Some(updated) => render_fixed_excerpt(updated, merged)
        None => None
      }
    None => None
  }
}

///|
/// Extracts the affected source lines after applying a merged fix.
fn render_fixed_excerpt(source : String, fix : @fixer.Fix) -> String? {
  let lines = split_lines(source)
  if lines.length() == 0 {
    return Some("")
  }
  let (min_line, max_line) = affected_line_range(fix)
  let start = max_int(1, min_line)
  let end_ = min_int(max_line, lines.length())
  if start > end_ {
    return Some(source.trim_end(chars="\n").to_string())
  }
  Some(lines[start - 1:end_].join("\n"))
}

///|
/// Computes the min/max line range touched by a merged fix.
fn affected_line_range(fix : @fixer.Fix) -> (Int, Int) {
  let mut min_line = fix.replacements[0].start.line
  let mut max_line = fix.replacements[0].end.line
  for replacement in fix.replacements {
    min_line = min_int(min_line, replacement.start.line)
    max_line = max_int(max_line, replacement.end.line)
  }
  (min_line, max_line)
}

///|
/// Builds the familiar ShellCheck-style caret line for one diagnostic.
fn cute_indent(diagnostic : @checker.PositionedDiagnostic) -> String {
  let start = diagnostic.span.start.column
  " ".repeat(start - 1) +
  make_arrow(diagnostic) +
  " " +
  code_text(diagnostic) +
  " (" +
  severity_text(diagnostic) +
  "): " +
  diagnostic.message
}

///|
/// Renders either a short `^--` marker or a ranged `^---^` marker depending on
/// how wide the diagnostic span is.
fn make_arrow(diagnostic : @checker.PositionedDiagnostic) -> String {
  let start = diagnostic.span.start.column
  let end_ = diagnostic.span.end.column
  let delta = end_ - start
  if diagnostic.span.start.line == diagnostic.span.end.line &&
    2 < delta &&
    delta < 32 {
    "^" + "-".repeat(delta - 2) + "^"
  } else {
    "^--"
  }
}
