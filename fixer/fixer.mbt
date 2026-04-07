///|
/// Determines how zero-width replacements attach to their target range.
pub enum InsertionPoint {
  InsertBefore
  InsertAfter
} derive(Eq, Debug)

///|
// CHECK THIS: THUNK

///|
/// Returns the insertion-point value that places text before the range start.
pub fn InsertionPoint::before() -> InsertionPoint {
  InsertionPoint::InsertBefore
}

///|
// CHECK THIS: THUNK

///|
/// Returns the insertion-point value that places text after the range end.
pub fn InsertionPoint::after() -> InsertionPoint {
  InsertionPoint::InsertAfter
}

///|
/// A textual replacement that can be applied to a single file.
pub struct Replacement {
  filename : String
  start : @parser.Position
  end : @parser.Position
  text : String
  precedence : Int
  insertion_point : InsertionPoint
} derive(Eq, Debug)

///|
/// Constructs a replacement spanning `start..end` in `filename`.
pub fn Replacement::new(
  filename : String,
  start : @parser.Position,
  end : @parser.Position,
  text : String,
  precedence : Int,
  insertion_point : InsertionPoint,
) -> Replacement {
  { filename, start, end, text, precedence, insertion_point }
}

///|
/// Returns a copy of the replacement with different inserted text.
pub fn Replacement::with_text(self : Replacement, text : String) -> Replacement {
  { ..self, text, }
}

///|
/// A collection of non-overlapping replacements that can be applied together.
pub struct Fix {
  replacements : Array[Replacement]
} derive(Eq, Debug)

///|
// CHECK THIS: THUNK

///|
/// Creates an empty fix.
pub fn Fix::new() -> Fix {
  { replacements: [] }
}

///|
/// Wraps an existing replacement list as a fix.
pub fn Fix::from_replacements(replacements : Array[Replacement]) -> Fix {
  { replacements, }
}

///|
/// Reports whether two replacements overlap in the same file.
///
/// Zero-width insertions are treated specially:
/// - two insertions at the same offset overlap;
/// - an insertion overlaps a non-empty range when it falls inside that range.
pub fn detect_overlap(lhs : Replacement, rhs : Replacement) -> Bool {
  if lhs.filename != rhs.filename {
    return false
  }
  let lhs_start = lhs.start.offset
  let lhs_end = lhs.end.offset
  let rhs_start = rhs.start.offset
  let rhs_end = rhs.end.offset
  if lhs_start == lhs_end && rhs_start == rhs_end {
    return lhs_start == rhs_start
  }
  if lhs_start == lhs_end {
    return rhs_start <= lhs_start && lhs_start < rhs_end
  }
  if rhs_start == rhs_end {
    return lhs_start <= rhs_start && rhs_start < lhs_end
  }
  lhs_start < rhs_end && rhs_start < lhs_end
}

///|
/// Merges multiple fixes into one, returning `None` when replacements overlap.
///
/// The function first flattens every replacement into one list, sorts the list
/// into application order, and then only needs to compare adjacent entries to
/// detect conflicts.
pub fn merge_fixes(fixes : Array[Fix]) -> Fix? {
  let replacements : Array[Replacement] = []
  for fix in fixes {
    for replacement in fix.replacements {
      replacements.push(replacement)
    }
  }
  let sorted = sort_replacements(replacements)
  let mut i = 0
  while i + 1 < sorted.length() {
    // Adjacent overlap checks are sufficient because the sort groups
    // same-file, same-region edits together.
    if detect_overlap(sorted[i], sorted[i + 1]) {
      return None
    }
    i += 1
  }
  Some({ replacements: sorted })
}

///|
/// Applies a position-mapping function to every replacement in a fix.
///
/// This is useful when another layer needs to reinterpret positions, for
/// example after converting visual columns to raw character columns.
pub fn map_positions(
  fix : Fix,
  mapper : (@parser.Position) -> @parser.Position,
) -> Fix {
  let replacements : Array[Replacement] = []
  for replacement in fix.replacements {
    replacements.push({
      ..replacement,
      start: mapper(replacement.start),
      end: mapper(replacement.end),
    })
  }
  { replacements, }
}

///|
/// Recomputes visual columns so fixes align with sources that contain tabs.
///
/// Diagnostics often speak in display columns, while replacement application
/// needs raw character offsets/columns. This pass converts each replacement
/// using the original source lines as context.
pub fn realign_columns_for_tabs(fix : Fix, source : String) -> Fix {
  let lines : Array[String] = []
  for line in source.split("\n") {
    lines.push(line.to_string())
  }
  map_positions(fix, fn(position) {
    @parser.Position::new(
      position.offset,
      position.line,
      realign_tabstop_column(line_at(lines, position.line), position.column),
    )
  })
}

///|
/// Applies a fix to source text.
///
/// Returns `None` if replacements overlap, point outside the source, or target
/// multiple files.
pub fn apply_fix(fix : Fix, source : String) -> String? {
  let merged = match merge_fixes([fix]) {
    Some(merged) => merged
    None => return None
  }
  if merged.replacements.length() == 0 {
    return Some(source)
  }
  let first_file = merged.replacements[0].filename
  for replacement in merged.replacements {
    // `apply_fix` operates on exactly one in-memory source string, so every
    // replacement must target the same file and remain within bounds.
    if replacement.filename != first_file {
      return None
    }
    if replacement.start.offset < 0 ||
      replacement.end.offset < replacement.start.offset ||
      replacement.end.offset > source.length() {
      return None
    }
  }
  let builder = StringBuilder::new()
  let mut current_offset = 0
  for replacement in merged.replacements {
    let start = replacement.start.offset
    let end_ = replacement.end.offset
    // Copy unchanged text between the previous replacement and this one, then
    // write the new text for the replacement itself.
    builder.write_string(
      source.view(start_offset=current_offset, end_offset=start).to_string(),
    )
    builder.write_string(replacement.text)
    current_offset = end_
  }
  builder.write_string(source.view(start_offset=current_offset).to_string())
  Some(builder.to_string())
}

///|
/// Sorts replacements into deterministic application order.
///
/// The sort order is chosen so later overlap detection and application can be
/// implemented as a single forward pass.
fn sort_replacements(replacements : Array[Replacement]) -> Array[Replacement] {
  let sorted = copy_replacements(replacements)
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      // The code uses a tiny hand-written sort because replacement lists are
      // small and custom ordering is easier to read inline than through a
      // generic comparator API.
      if replacement_precedes(sorted[j], sorted[i]) {
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
/// Returns whether `lhs` should be applied before `rhs`.
///
/// Precedence is compared in reverse numeric order so larger precedence values
/// win when two zero-width insertions land at the same position.
fn replacement_precedes(lhs : Replacement, rhs : Replacement) -> Bool {
  if lhs.filename != rhs.filename {
    return lhs.filename < rhs.filename
  }
  if lhs.start.offset != rhs.start.offset {
    return lhs.start.offset < rhs.start.offset
  }
  if lhs.end.offset != rhs.end.offset {
    return lhs.end.offset < rhs.end.offset
  }
  if lhs.precedence != rhs.precedence {
    return lhs.precedence > rhs.precedence
  }
  insertion_rank(lhs.insertion_point) < insertion_rank(rhs.insertion_point)
}

///|
/// Converts insertion semantics into a sortable tiebreaker.
fn insertion_rank(point : InsertionPoint) -> Int {
  match point {
    InsertionPoint::InsertBefore => 0
    InsertionPoint::InsertAfter => 1
  }
}

///|
/// Copies replacements into a fresh array before sorting.
fn copy_replacements(replacements : Array[Replacement]) -> Array[Replacement] {
  let copied : Array[Replacement] = []
  for replacement in replacements {
    copied.push(replacement)
  }
  copied
}

///|
/// Returns a 1-based line from `lines`, or `""` when out of range.
fn line_at(lines : Array[String], line : Int) -> String {
  if 1 <= line && line <= lines.length() {
    lines[line - 1].to_string()
  } else {
    ""
  }
}

///|
/// Converts a display column into the underlying character column for one line.
///
/// Tabs expand to the next tab stop visually, but still occupy one character in
/// the source string. The function walks the line until the requested display
/// column is reached and then returns the matching raw column.
fn realign_tabstop_column(line : String, target : Int) -> Int {
  if target <= 0 {
    return target
  }
  let view = line[:]
  let mut actual = 0
  let mut display = 0
  let mut i = 0
  while i < view.length() {
    if target <= display {
      return actual
    }
    let ch = view[i]
    if ch == '\t' {
      // MoonBit follows the same 8-column tab stop convention ShellCheck uses.
      actual += 1
      display += 8 - display % 8
    } else {
      actual += 1
      display += 1
    }
    i += 1
  }
  actual + (target - display)
}
