///|
/// One logical line in the temporary line-based diff representation.
///
/// `Both` means the line appears in both versions, `First` means it only
/// appears in the original, and `Second` means it only appears in the updated
/// text.
priv enum DiffLine {
  Both(String)
  First(String)
  Second(String)
}

///|
/// Marker used by unified diff when one side omits the trailing newline.
const NO_NEWLINE_MARKER = "\\ No newline at end of file"

///|
/// Renders fixable diagnostics as unified diff output.
///
/// For each file, the renderer merges all compatible fixes, applies them to the
/// source, and diffs the original against the updated text. Files without
/// applicable or mergeable fixes simply produce no diff section.
fn render_diff(
  results : Array[@checker.CheckResult],
  options : FormatOptions,
) -> String {
  let outputs : Array[String] = []
  for result in results {
    let fixes : Array[@fixer.Fix] = []
    for diagnostic in result.diagnostics {
      match diagnostic.fix {
        Some(fix) => fixes.push(fix)
        None => ()
      }
    }
    match @fixer.merge_fixes(fixes) {
      Some(fix) =>
        match @fixer.apply_fix(fix, result.source) {
          Some(updated) if updated != result.source =>
            // Only emit a diff when applying the merged fix actually changes
            // the file contents.
            outputs.push(
              render_unified_diff(
                result.filename,
                result.source,
                updated,
                options,
              ),
            )
          _ => ()
        }
      None => ()
    }
  }
  outputs.join("\n")
}

///|
/// Renders one unified diff between the original and updated file contents.
///
/// The implementation first computes a line-based edit script, then groups the
/// edits into hunks with surrounding context.
fn render_unified_diff(
  filename : String,
  old : String,
  new : String,
  options : FormatOptions,
) -> String {
  let old_lines = split_lines(old)
  let new_lines = split_lines(new)
  let diffs = build_line_diff(old_lines, new_lines)
  let hunks = diff_hunks(diffs, 3)
  let old_missing_newline = source_missing_trailing_newline(old)
  let new_missing_newline = source_missing_trailing_newline(new)
  let lines : Array[String] = [
    diff_color("header", "--- " + diff_path("a", filename), options),
    diff_color("header", "+++ " + diff_path("b", filename), options),
  ]
  for hunk in hunks {
    let (old_start, old_count, new_start, new_count) = diff_hunk_header(
      diffs,
      hunk.0,
      hunk.1,
    )
    lines.push(
      diff_color(
        "hunk",
        "@@ -" +
        diff_range(old_start, old_count) +
        " +" +
        diff_range(new_start, new_count) +
        " @@",
        options,
      ),
    )
    let mut old_line = old_start
    let mut new_line = new_start
    let mut old_marker_emitted = false
    for line in diffs[hunk.0:hunk.1] {
      lines.push(render_diff_line(line, options))
      match line {
        Both(_) => {
          // When both versions lack the trailing newline on the final line, the
          // unified diff should emit the marker only once.
          if old_missing_newline &&
            new_missing_newline &&
            old_line == old_lines.length() &&
            new_line == new_lines.length() {
            lines.push(NO_NEWLINE_MARKER)
            old_marker_emitted = true
          }
          old_line += 1
          new_line += 1
        }
        First(_) => {
          if old_missing_newline && old_line == old_lines.length() {
            lines.push(NO_NEWLINE_MARKER)
            old_marker_emitted = true
          }
          old_line += 1
        }
        Second(_) => {
          if new_missing_newline &&
            new_line == new_lines.length() &&
            !old_marker_emitted {
            lines.push(NO_NEWLINE_MARKER)
          }
          new_line += 1
        }
      }
    }
  }
  lines.join("\n")
}

///|
/// Returns whether the source ends without a trailing newline.
fn source_missing_trailing_newline(source : String) -> Bool {
  source.length() > 0 && source[:][source.length() - 1] != '\n'
}

///|
/// Prefixes relative filenames with `a/` or `b/` for unified diff headers.
fn diff_path(prefix : String, filename : String) -> String {
  if filename.has_prefix("/") {
    filename
  } else {
    prefix + "/" + filename
  }
}

///|
/// Renders one line of the temporary diff representation.
fn render_diff_line(line : DiffLine, options : FormatOptions) -> String {
  match line {
    Both(text) => " " + text
    First(text) => diff_color("remove", "-" + text, options)
    Second(text) => diff_color("add", "+" + text, options)
  }
}

///|
/// Formats the range syntax used in unified diff hunk headers.
fn diff_range(start : Int, count : Int) -> String {
  if count == 0 {
    max_int(0, start - 1).to_string() + ",0"
  } else {
    start.to_string() + "," + count.to_string()
  }
}

///|
/// Groups changed lines into hunks with `context` lines on each side.
///
/// Nearby changed regions are merged when their context windows overlap.
fn diff_hunks(diffs : Array[DiffLine], context : Int) -> Array[(Int, Int)] {
  let changed : Array[Int] = []
  let mut i = 0
  while i < diffs.length() {
    match diffs[i] {
      Both(_) => ()
      _ => changed.push(i)
    }
    i += 1
  }
  let hunks : Array[(Int, Int)] = []
  if changed.length() == 0 {
    return hunks
  }
  let mut start = max_int(0, changed[0] - context)
  let mut end_ = min_int(diffs.length(), changed[0] + context + 1)
  let mut k = 1
  while k < changed.length() {
    let next_start = max_int(0, changed[k] - context)
    let next_end = min_int(diffs.length(), changed[k] + context + 1)
    if next_start <= end_ {
      end_ = max_int(end_, next_end)
    } else {
      hunks.push((start, end_))
      start = next_start
      end_ = next_end
    }
    k += 1
  }
  hunks.push((start, end_))
  hunks
}

///|
/// Computes the `(old_start, old_count, new_start, new_count)` tuple for one
/// hunk header.
fn diff_hunk_header(
  diffs : Array[DiffLine],
  start : Int,
  end_ : Int,
) -> (Int, Int, Int, Int) {
  let mut old_start = 1
  let mut new_start = 1
  let mut i = 0
  while i < start {
    // Count how many old/new lines are consumed before this hunk begins.
    let (old_delta, new_delta) = diff_line_counts(diffs[i])
    old_start += old_delta
    new_start += new_delta
    i += 1
  }
  let mut old_count = 0
  let mut new_count = 0
  i = start
  while i < end_ {
    // Count how many lines from each side are represented inside the hunk.
    let (old_delta, new_delta) = diff_line_counts(diffs[i])
    old_count += old_delta
    new_count += new_delta
    i += 1
  }
  (old_start, old_count, new_start, new_count)
}

///|
/// Returns how one diff line advances the old and new cursors.
fn diff_line_counts(line : DiffLine) -> (Int, Int) {
  match line {
    Both(_) => (1, 1)
    First(_) => (1, 0)
    Second(_) => (0, 1)
  }
}

///|
/// Builds a line-based diff using the longest common subsequence dynamic
/// programming algorithm.
///
/// `dp[i, j]` stores the length of the LCS between `old_lines[i:]` and
/// `new_lines[j:]`. After the table is filled, a second pass reconstructs an
/// edit script by walking greedily according to the stored lengths.
fn build_line_diff(
  old_lines : Array[String],
  new_lines : Array[String],
) -> Array[DiffLine] {
  let old_len = old_lines.length()
  let new_len = new_lines.length()
  let width = new_len + 1
  let dp = Array::make((old_len + 1) * width, 0)
  let mut i = old_len
  while i > 0 {
    i -= 1
    let mut j = new_len
    while j > 0 {
      j -= 1
      dp[dp_index(i, j, width)] = if old_lines[i] == new_lines[j] {
        dp[dp_index(i + 1, j + 1, width)] + 1
      } else {
        max_int(dp[dp_index(i + 1, j, width)], dp[dp_index(i, j + 1, width)])
      }
    }
  }
  let diffs : Array[DiffLine] = []
  i = 0
  let mut j = 0
  while i < old_len && j < new_len {
    if old_lines[i] == new_lines[j] {
      diffs.push(DiffLine::Both(old_lines[i]))
      i += 1
      j += 1
    } else if dp[dp_index(i + 1, j, width)] >= dp[dp_index(i, j + 1, width)] {
      // Dropping an old line keeps an LCS at least as long as dropping the new
      // one, so this line belongs only to the original side.
      diffs.push(DiffLine::First(old_lines[i]))
      i += 1
    } else {
      diffs.push(DiffLine::Second(new_lines[j]))
      j += 1
    }
  }
  while i < old_len {
    diffs.push(DiffLine::First(old_lines[i]))
    i += 1
  }
  while j < new_len {
    diffs.push(DiffLine::Second(new_lines[j]))
    j += 1
  }
  diffs
}

///|
/// Flattens 2D dynamic-programming coordinates into the backing 1D array.
fn dp_index(i : Int, j : Int, width : Int) -> Int {
  i * width + j
}
