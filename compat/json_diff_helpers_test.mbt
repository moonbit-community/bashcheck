///|
struct JsonDiffReplacement {
  line : Int
  end_line : Int
  column : Int
  end_column : Int
  insertion_point : String
  precedence : Int
  replacement : String
} derive(Eq, Debug)

///|
struct JsonDiffFix {
  replacements : Array[JsonDiffReplacement]
} derive(Eq, Debug)

///|
struct JsonDiffDiagnostic {
  file : String
  line : Int
  end_line : Int
  column : Int
  end_column : Int
  level : String
  code : Int?
  message : String
  fix : JsonDiffFix?
} derive(Eq, Debug)

///|
fn shellcheck_diff_spec() -> @checker.CheckSpec {
  @checker.CheckSpec::default().with_ignore_rc(true)
}

///|
async fn assert_shellcheck_json_matches(
  label : String,
  source : String,
  spec? : @checker.CheckSpec = shellcheck_diff_spec(),
) -> Unit {
  let (shellcheck_output, bashcheck_output) = run_shellcheck_json_pair(
    label, source, spec,
  )
  let expected = normalize_json_diff_diagnostics(shellcheck_output)
  let actual = normalize_json_diff_diagnostics(bashcheck_output)
  if actual != expected {
    abort(
      "\{label}: expected shellcheck json \{@debug.to_string(expected)}, got \{@debug.to_string(actual)}",
    )
  }
}

///|
async fn run_shellcheck_json_pair(
  label : String,
  source : String,
  spec : @checker.CheckSpec,
) -> (String, String) {
  let path = compat_diff_fixture_path(label)
  if !@fs.exists("_build/compat-diff") {
    ignore(@fs.mkdir("_build/compat-diff", permission=0o755, recursive=true)) catch {
      _ => ()
    }
  }
  @fs.write_file(path, source, create=0o644, truncate=true)

  let (shellcheck_exit, shellcheck_stdout, shellcheck_stderr) = @process.collect_output(
    "shellcheck",
    ["--norc", "-f", "json", path],
  )
  guard shellcheck_exit == 0 || shellcheck_exit == 1 else {
    abort(
      "\{label}: shellcheck failed with exit code \{shellcheck_exit}: \{shellcheck_stderr.text()}",
    )
  }

  let bashcheck = @driver.run_cli(
    @driver.CliAction::Run,
    [path],
    spec,
    match @formatter.parse_output_format("json") {
      Some(format) => format
      None => abort("missing json output format")
    },
    @formatter.FormatOptions::default(),
  )
  guard bashcheck.exit_code == 0 || bashcheck.exit_code == 1 else {
    abort(
      "\{label}: bashcheck json run failed with exit code \{bashcheck.exit_code}: \{bashcheck.output}",
    )
  }

  (shellcheck_stdout.text(), bashcheck.output)
}

///|
fn compat_diff_fixture_path(label : String) -> String {
  "_build/compat-diff/" + compat_diff_slug(label) + ".sh"
}

///|
fn compat_diff_slug(label : String) -> String {
  let view = label[:]
  let buf = StringBuilder::new()
  let mut wrote = false
  for ch in view {
    let char_ = ch
    if ('a' <= char_ && char_ <= 'z') ||
      ('A' <= char_ && char_ <= 'Z') ||
      ('0' <= char_ && char_ <= '9') {
      buf.write_char(char_)
      wrote = true
    } else if wrote {
      buf.write_char('-')
    }
  }
  let slug = trim_trailing_hyphen(buf.to_string())
  if slug == "" {
    "case"
  } else {
    slug
  }
}

///|
fn trim_trailing_hyphen(text : String) -> String {
  let view = text[:]
  let mut end = view.length()
  while end > 0 && view[end - 1].unsafe_to_char() == '-' {
    end -= 1
  }
  text.view(end_offset=end).to_string()
}

///|
fn normalize_json_diff_diagnostics(text : String) -> Array[JsonDiffDiagnostic] {
  let parsed = @json.parse(text) catch {
    err =>
      abort(
        "expected shellcheck-style JSON array, got parse error \{err.to_string()} from \{@debug.to_string(text)}",
      )
  }
  guard parsed is Array(items) else {
    abort("expected shellcheck-style JSON array, got \{@debug.to_string(text)}")
  }
  let diagnostics : Array[JsonDiffDiagnostic] = []
  for item in items {
    diagnostics.push(normalize_json_diff_diagnostic(item))
  }
  sort_json_diff_diagnostics(diagnostics)
}

///|
fn normalize_json_diff_diagnostic(json : Json) -> JsonDiffDiagnostic {
  let object = json_diff_expect_object(json)
  {
    file: "<input>",
    line: json_diff_object_int(object, "line"),
    end_line: json_diff_object_int(object, "endLine"),
    column: json_diff_object_int(object, "column"),
    end_column: json_diff_object_int(object, "endColumn"),
    level: json_diff_object_string(object, "level"),
    code: json_diff_object_optional_int(object, "code"),
    message: json_diff_object_string(object, "message"),
    fix: json_diff_object_optional_fix(object, "fix"),
  }
}

///|
fn json_diff_expect_object(json : Json) -> Map[String, Json] {
  guard json is Object(object) else {
    abort("expected JSON object, got \{json.stringify()}")
  }
  object
}

///|
fn json_diff_object_field(object : Map[String, Json], key : String) -> Json {
  match object.get(key) {
    Some(value) => value
    None => abort("missing JSON field \{key}")
  }
}

///|
fn json_diff_object_string(object : Map[String, Json], key : String) -> String {
  @json.from_json(json_diff_object_field(object, key)) catch {
    err =>
      abort("failed to decode JSON string field \{key}: \{err.to_string()}")
  }
}

///|
fn json_diff_object_int(object : Map[String, Json], key : String) -> Int {
  @json.from_json(json_diff_object_field(object, key)) catch {
    err => abort("failed to decode JSON int field \{key}: \{err.to_string()}")
  }
}

///|
fn json_diff_object_optional_int(
  object : Map[String, Json],
  key : String,
) -> Int? {
  match json_diff_object_field(object, key) {
    Null => None
    value =>
      Some(
        @json.from_json(value) catch {
          err =>
            abort(
              "failed to decode optional JSON int field \{key}: \{err.to_string()}",
            )
        },
      )
  }
}

///|
fn json_diff_object_optional_fix(
  object : Map[String, Json],
  key : String,
) -> JsonDiffFix? {
  match json_diff_object_field(object, key) {
    Null => None
    value => Some(normalize_json_diff_fix(value))
  }
}

///|
fn normalize_json_diff_fix(json : Json) -> JsonDiffFix {
  let object = json_diff_expect_object(json)
  let replacements = match json_diff_object_field(object, "replacements") {
    Array(items) => {
      let normalized : Array[JsonDiffReplacement] = []
      for item in items {
        normalized.push(normalize_json_diff_replacement(item))
      }
      sort_json_diff_replacements(normalized)
    }
    _ => abort("expected fix replacements array")
  }
  { replacements, }
}

///|
fn normalize_json_diff_replacement(json : Json) -> JsonDiffReplacement {
  let object = json_diff_expect_object(json)
  {
    line: json_diff_object_int(object, "line"),
    end_line: json_diff_object_int(object, "endLine"),
    column: json_diff_object_int(object, "column"),
    end_column: json_diff_object_int(object, "endColumn"),
    insertion_point: json_diff_object_string(object, "insertionPoint"),
    precedence: json_diff_object_int(object, "precedence"),
    replacement: json_diff_object_string(object, "replacement"),
  }
}

///|
fn sort_json_diff_diagnostics(
  diagnostics : Array[JsonDiffDiagnostic],
) -> Array[JsonDiffDiagnostic] {
  let sorted : Array[JsonDiffDiagnostic] = []
  for diagnostic in diagnostics {
    sorted.push(diagnostic)
  }
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      if json_diff_diagnostic_precedes(sorted[j], sorted[i]) {
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
fn json_diff_diagnostic_precedes(
  lhs : JsonDiffDiagnostic,
  rhs : JsonDiffDiagnostic,
) -> Bool {
  if lhs.line != rhs.line {
    return lhs.line < rhs.line
  }
  if lhs.end_line != rhs.end_line {
    return lhs.end_line < rhs.end_line
  }
  if lhs.column != rhs.column {
    return lhs.column < rhs.column
  }
  if lhs.end_column != rhs.end_column {
    return lhs.end_column < rhs.end_column
  }
  let lhs_rank = json_diff_level_rank(lhs.level)
  let rhs_rank = json_diff_level_rank(rhs.level)
  if lhs_rank != rhs_rank {
    return lhs_rank < rhs_rank
  }
  match (lhs.code, rhs.code) {
    (Some(lhs_code), Some(rhs_code)) if lhs_code != rhs_code =>
      return lhs_code < rhs_code
    (Some(_), None) => return true
    (None, Some(_)) => return false
    _ => ()
  }
  lhs.message < rhs.message
}

///|
fn json_diff_level_rank(level : String) -> Int {
  match level {
    "error" => 0
    "warning" => 1
    "info" => 2
    "style" => 3
    _ => 4
  }
}

///|
fn sort_json_diff_replacements(
  replacements : Array[JsonDiffReplacement],
) -> Array[JsonDiffReplacement] {
  let sorted : Array[JsonDiffReplacement] = []
  for replacement in replacements {
    sorted.push(replacement)
  }
  let mut i = 0
  while i < sorted.length() {
    let mut j = i + 1
    while j < sorted.length() {
      if json_diff_replacement_precedes(sorted[j], sorted[i]) {
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
fn json_diff_replacement_precedes(
  lhs : JsonDiffReplacement,
  rhs : JsonDiffReplacement,
) -> Bool {
  if lhs.line != rhs.line {
    return lhs.line < rhs.line
  }
  if lhs.end_line != rhs.end_line {
    return lhs.end_line < rhs.end_line
  }
  if lhs.column != rhs.column {
    return lhs.column < rhs.column
  }
  if lhs.end_column != rhs.end_column {
    return lhs.end_column < rhs.end_column
  }
  if lhs.precedence != rhs.precedence {
    return lhs.precedence < rhs.precedence
  }
  if lhs.insertion_point != rhs.insertion_point {
    return lhs.insertion_point < rhs.insertion_point
  }
  lhs.replacement < rhs.replacement
}
