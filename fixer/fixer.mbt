///|
/// Determines how zero-width replacements attach to their target range.
pub enum InsertionPoint {
  InsertBefore
  InsertAfter
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend InsertionPoint with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend InsertionPoint with Debug::{to_repr}

///|
// CHECK THIS: THUNK

///|
/// Returns the insertion-point value that places text before the range start.
pub fn InsertionPoint::before() -> InsertionPoint {
  InsertBefore
}

///|
// CHECK THIS: THUNK

///|
/// Returns the insertion-point value that places text after the range end.
pub fn InsertionPoint::after() -> InsertionPoint {
  InsertAfter
}

///|
/// A textual replacement that can be applied to a single file.
pub struct Replacement {
  filename : String
  start : @parser.Position
  end : @parser.Position
  text : String
  precedence : Int32
  insertion_point : InsertionPoint
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend Replacement with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Replacement with Debug::{to_repr}

///|
/// Constructs a replacement spanning `start..end` in `filename`.
pub fn Replacement::new(
  filename : String,
  start : @parser.Position,
  end : @parser.Position,
  text : String,
  precedence : Int32,
  insertion_point : InsertionPoint,
) -> Replacement {
  { filename, start, end, text, precedence, insertion_point, }
}

///|
/// A collection of non-overlapping replacements that can be applied together.
pub struct Fix {
  replacements : Array[Replacement]
} derive(Eq, Debug)

///|
#deprecated
#doc(hidden)
pub extend Fix with Eq::{not_equal, equal}

///|
#deprecated
#doc(hidden)
pub extend Fix with Debug::{to_repr}

///|
// CHECK THIS: THUNK

///|
/// Wraps an existing replacement list as a fix.
pub fn Fix::from_replacements(replacements : Array[Replacement]) -> Fix {
  { replacements, }
}

///|
/// Reports whether two replacements overlap in the same file.
///
/// Replacements use half-open offsets. Zero-width insertions therefore do not
/// overlap other replacements when they sit exactly on a range boundary, but
/// they do overlap when they land strictly inside another range.
pub fn detect_overlap(lhs : Replacement, rhs : Replacement) -> Bool {
  if lhs.filename != rhs.filename {
    return false
  }
  let lhs_start = lhs.start.offset
  let lhs_end = lhs.end.offset
  let rhs_start = rhs.start.offset
  let rhs_end = rhs.end.offset
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
  Some({ replacements: sorted, })
}

///|
/// Applies a fix to source text.
///
/// Returns `None` if replacements overlap, point outside the source, or target
/// multiple files.
pub fn apply_fix(fix : Fix, source : String) -> String? {
  let merged = if merge_fixes([fix]) is Some(merged) {
    merged
  } else {
    return None
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
  let builder = StringBuilder()
  let mut current_offset = 0
  for replacement in merged.replacements {
    let start = replacement.start.offset
    let end_ = replacement.end.offset
    // Copy unchanged text between the previous replacement and this one, then
    // write the new text for the replacement itself.
    builder.write_string(
      source.view(start_offset=current_offset, end_offset=start).to_owned(),
    )
    builder.write_string(replacement.text)
    current_offset = end_
  }
  builder.write_string(source.view(start_offset=current_offset).to_owned())
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
  if lhs.start.offset == lhs.end.offset && rhs.start.offset == rhs.end.offset {
    if lhs.insertion_point != rhs.insertion_point {
      return insertion_rank(lhs.insertion_point) <
        insertion_rank(rhs.insertion_point)
    }
    match lhs.insertion_point {
      InsertBefore =>
        if lhs.precedence != rhs.precedence {
          return lhs.precedence > rhs.precedence
        }
      InsertAfter =>
        if lhs.precedence != rhs.precedence {
          return lhs.precedence < rhs.precedence
        }
    }
  }
  if lhs.precedence != rhs.precedence {
    return lhs.precedence > rhs.precedence
  }
  insertion_rank(lhs.insertion_point) < insertion_rank(rhs.insertion_point)
}

///|
/// Converts insertion semantics into a sortable tiebreaker.
fn insertion_rank(point : InsertionPoint) -> Int32 {
  match point {
    InsertBefore => 0
    InsertAfter => 1
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
