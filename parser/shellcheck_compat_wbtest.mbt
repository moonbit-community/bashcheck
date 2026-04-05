///|
fn status_ok() -> String {
  "ok"
}

///|
fn status_warning() -> String {
  "warning"
}

///|
fn status_not_ok() -> String {
  "not_ok"
}

///|
fn fail_status(
  label : String,
  expected : String,
  actual : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  abort(
    "\{label}: expected \{expected}, got \{actual} with \{diagnostics.length()} diagnostics",
  )
}

///|
fn assert_gap_status(
  label : String,
  source : String,
  expected : String,
) -> Unit {
  let parser = Parser::new(source.view(), ParseOptions::default(), [])
  let actual = {
    parser.skip_command_gaps()
    if !parser.eof() {
      status_not_ok()
    } else if parser.diagnostics.length() == 0 {
      status_ok()
    } else {
      status_warning()
    }
  }
  if actual != expected {
    fail_status(label, expected, actual, parser.diagnostics)
  }
}

///|
fn assert_brace_status(
  label : String,
  fragment : String,
  expected : String,
) -> Unit {
  let parser = Parser::new(fragment.view(), ParseOptions::default(), [])
  let actual = try {
    ignore(parser.read_brace_expansion())
    if !parser.eof() {
      status_not_ok()
    } else if parser.diagnostics.length() == 0 {
      status_ok()
    } else {
      status_warning()
    }
  } catch {
    _ => status_not_ok()
  }
  if actual != expected {
    fail_status(label, expected, actual, parser.diagnostics)
  }
}

///|
fn is_blank_line(line : String) -> Bool {
  for ch in line {
    if ch != ' ' && ch != '\t' && ch != '\r' {
      return false
    }
  }
  true
}

///|
fn starts_comment(line : String) -> Bool {
  let view = line[:]
  let mut i = 0
  while i < view.length() &&
        (view[i] == ' ' || view[i] == '\t' || view[i] == '\r') {
    i += 1
  }
  i < view.length() && view[i] == '#'
}

///|
fn compat_config_options() -> ParseOptions {
  ParseOptions::new(false, true, false, false, None, [], [])
}

///|
fn assert_config_ok(label : String, source : String) -> Unit {
  let diagnostics : Array[Diagnostic] = []
  let mut line = 1
  for raw in source.split("\n") {
    let text = raw.to_string()
    if is_blank_line(text) || starts_comment(text) {
      line += 1
      continue
    }
    let line_diagnostics = try {
      let (_, diagnostics) = parse_annotation_line(
        "# shellcheck \{text}",
        { offset: 0, line, column: 1 },
        compat_config_options(),
      )
      diagnostics
    } catch {
      err =>
        abort(
          "\{label}: config parse raised \{err.to_string()} on line \{line}",
        )
    }
    for diagnostic in line_diagnostics {
      diagnostics.push(diagnostic)
    }
    line += 1
  }
  if diagnostics.length() != 0 {
    abort(
      "\{label}: expected clean config parse, got \{diagnostics.length()} diagnostics",
    )
  }
}

///|
fn is_any_shebang_text(line : String) -> Bool {
  match classify_shebang_line(line) {
    Some(kind) => is_any_shebang_line(kind)
    None => false
  }
}

///|
fn is_header_line(line : String) -> Bool {
  if is_any_shebang_text(line) {
    return false
  }
  is_blank_line(line) || starts_comment(line)
}

///|
fn shebang_status(source : String) -> String {
  let lines : Array[String] = []
  for part in source.split("\n") {
    lines.push(part.to_string())
  }
  if lines.length() == 0 {
    return status_not_ok()
  }
  match classify_shebang_line(lines[0]) {
    Some(ShebangLineKind::Correct) => status_ok()
    Some(_) => status_warning()
    None => {
      let mut i = 0
      while i < lines.length() && is_header_line(lines[i]) {
        i += 1
      }
      if i < lines.length() && is_any_shebang_text(lines[i]) {
        status_warning()
      } else {
        status_not_ok()
      }
    }
  }
}

///|
fn assert_shebang_status(
  label : String,
  source : String,
  expected : String,
) -> Unit {
  let actual = shebang_status(source)
  if actual != expected {
    abort("\{label}: expected \{expected}, got \{actual}")
  }
}

///|
test "shellcheck whitebox compatibility spacing samples" {
  assert_gap_status("prop_spacing1", "  \\\n # Comment", status_ok())
  assert_gap_status(
    "prop_spacing2",
    "# We can continue lines with \\",
    status_ok(),
  )
  assert_gap_status(
    "prop_spacing3",
    "   \\\n #  --verbose=true \\",
    status_warning(),
  )

  assert_gap_status("prop_allspacing", "#foo", status_ok())
  assert_gap_status("prop_allspacing2", " #foo\n # bar\n#baz\n", status_ok())
  assert_gap_status("prop_allspacing3", "#foo\n#bar\n#baz\n", status_ok())
}

///|
test "shellcheck whitebox compatibility brace expansion samples" {
  assert_brace_status("prop_readBraced", "{1..4}", status_ok())
  assert_brace_status("prop_readBraced2", "{foo,bar,\"baz lol\"}", status_ok())
  assert_brace_status("prop_readBraced3", "{1,\\},2}", status_ok())
  assert_brace_status("prop_readBraced4", "{1,{2,3}}", status_ok())
  assert_brace_status("prop_readBraced5", "{JP{,E}G,jp{,e}g}", status_ok())
  assert_brace_status("prop_readBraced6", "{foo,bar,$((${var}))}", status_ok())
  assert_brace_status("prop_readBraced7", "{}", status_not_ok())
  assert_brace_status("prop_readBraced8", "{foo}", status_not_ok())
}

///|
test "shellcheck whitebox compatibility config samples" {
  assert_config_ok("prop_readAnnotation11", "external-sources='true'")
  assert_config_ok("prop_readConfigKVs1", "disable=1234")
  assert_config_ok("prop_readConfigKVs2", "# Comment\ndisable=1234 # Comment\n")
  assert_config_ok("prop_readConfigKVs3", "")
  assert_config_ok("prop_readConfigKVs4", "\n\n\n\n\t \n")
  assert_config_ok(
    "prop_readConfigKVs5", "# shellcheck accepts annotation-like comments in rc files\ndisable=1234",
  )
}

///|
test "shellcheck whitebox compatibility shebang samples" {
  assert_shebang_status("prop_readShebang1", "#!/bin/sh\n", status_ok())
  assert_shebang_status("prop_readShebang2", "!# /bin/sh\n", status_warning())
  assert_shebang_status(
    "prop_readShebang3",
    "#shellcheck shell=/bin/sh\n",
    status_not_ok(),
  )
  assert_shebang_status("prop_readShebang4", "! /bin/sh", status_warning())
  assert_shebang_status("prop_readShebang5", "\n#!/bin/sh", status_warning())
  assert_shebang_status(
    "prop_readShebang6",
    " # Copyright \n!#/bin/bash",
    status_warning(),
  )
  assert_shebang_status(
    "prop_readShebang7",
    "# Copyright \nfoo\n#!/bin/bash",
    status_not_ok(),
  )
}
