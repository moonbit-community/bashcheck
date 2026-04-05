# bashcheck/parser

`parser` turns shell source into AST nodes with spans, annotations, and parse
diagnostics. It is the package in this repository that is closest to
`ShellCheck.Parser`.

## Parse Complete Scripts And Keep Structure

Use `parse_script` when parse failure should stop the caller immediately, and
use `parse_script_report` when you want a `ParseReport` that may still carry a
partially parsed `Script` plus diagnostics. Most downstream packages start from
these entry points and then inspect `Script`, `ListItem`, `Command`,
`CommandKind`, `Word`, `Span`, and `Diagnostic`.

```mbt check
///|
test "doc parser parses complete scripts into AST nodes" {
  let script = match @parser.parse_script("FOO=bar echo \"hi $USER\" >out\n") {
    Ok(script) => script
    Err(err) => abort(err.to_string())
  }
  let command = script.items[0].and_or.head.segments[0].command

  assert_eq(script.items.length(), 1)
  match command.kind {
    @parser.CommandKind::Simple(simple) => {
      assert_eq(simple.assignments.length(), 1)
      assert_eq(simple.assignments[0].name, "FOO")
      assert_eq(simple.words.length(), 2)
      assert_eq(simple.words[0].source, "echo")
      assert_eq(simple.words[1].source, "\"hi $USER\"")
      assert_eq(command.redirects.length(), 1)
    }
    _ => abort("expected simple command")
  }
}

///|
test "doc parser can report diagnostics without raising immediately" {
  let report = @parser.parse_script_report("echo 'unterminated")
  assert_true(report.diagnostics.length() > 0)
}
```

## Resolve Sourced Files And Feed Parser Context

Use `ParseOptions` and `parse_script_with_options` when the parser needs extra
context: whether the current file is sourced, where `. file` lookups should
start, and which in-memory `source_files` should stand in for filesystem reads.
The same package also exposes `parse_config_report` and
`merge_script_annotations` when you want to turn rc-style text into parser
annotations before later analysis stages run.

```mbt check
///|
test "doc parser can inline sourced files with explicit options" {
  let options = @parser.ParseOptions::new(
    true,
    false,
    false,
    true,
    Some("/tmp/main.sh"),
    [],
    [("lib.sh", "echo inside\n")],
  )
  let report = @parser.parse_script_with_options(". lib.sh\n", options)
  let script = match report.script {
    Some(script) => script
    None => abort("expected parsed script")
  }
  let command = script.items[0].and_or.head.segments[0].command

  assert_eq(report.diagnostics.length(), 0)
  match command.kind {
    @parser.CommandKind::Source(source) => {
      assert_eq(source.keyword, ".")
      assert_eq(source.path.source, "lib.sh")
      assert_true(source.included is Some(_))
    }
    _ => abort("expected source command")
  }
}
```

## Parse Focused Fragments Instead Of Whole Files

When a caller only needs shell fragment semantics, `parse_text_as_word` and
`parse_arithmetic_expr` are cheaper entry points than parsing a whole script.
These APIs return the same public fragment types used inside the full AST, such
as `Word`, `WordPart`, `ArithmeticExpr`, `ArithmeticToken`, and `ArrayIndex`.

```mbt check
///|
test "doc parser can parse word and arithmetic fragments directly" {
  let word = @parser.parse_text_as_word("\"$HOME\"/*.sh")
  assert_eq(word.source, "\"$HOME\"/*.sh")
  assert_true(word.parts.length() >= 2)

  let expr = @parser.parse_arithmetic_expr("x + arr[i]")
  assert_eq(expr.raw, "x + arr[i]")
  assert_true(expr.tokens.length() >= 3)
  match expr.tokens[2] {
    @parser.ArithmeticToken::Variable(name, indexes) => {
      assert_eq(name, "arr")
      assert_eq(indexes.length(), 1)
    }
    _ => abort("expected indexed variable token")
  }
}
```
