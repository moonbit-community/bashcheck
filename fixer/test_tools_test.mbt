///|
using @fixer {type Fix, type Replacement}

///|
/// Applies a position-mapping function to every replacement in a fix.
///
/// This is useful when another layer needs to reinterpret positions, for
/// example after converting visual columns to raw character columns.
fn map_positions(
  fix : Fix,
  mapper : (@parser.Position) -> @parser.Position,
) -> Fix {
  let replacements : Array[Replacement] = []
  for replacement in fix.replacements {
    replacements.push(
      @fixer.Replacement::new(
        replacement.filename,
        mapper(replacement.start),
        mapper(replacement.end),
        replacement.text,
        replacement.precedence,
        replacement.insertion_point,
      ),
    )
  }
  @fixer.Fix::from_replacements(replacements)
}

///|
/// Recomputes visual columns so fixes align with sources that contain tabs.
///
/// Diagnostics often speak in display columns, while replacement application
/// needs raw character offsets/columns. This pass converts each replacement
/// using the original source lines as context.
fn realign_columns_for_tabs(fix : Fix, source : String) -> Fix {
  let lines : Array[String] = []
  for line in source.split("\n") {
    lines.push(line.to_owned())
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
/// Returns a 1-based line from `lines`, or `""` when out of range.
fn line_at(lines : Array[String], line : Int32) -> String {
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
fn realign_tabstop_column(line : String, target : Int32) -> Int32 {
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

///|
fn @fixer.Replacement::with_text(
  self : @fixer.Replacement,
  text : String,
) -> @fixer.Replacement {
  @fixer.Replacement::new(
    self.filename,
    self.start,
    self.end,
    text,
    self.precedence,
    self.insertion_point,
  )
}
