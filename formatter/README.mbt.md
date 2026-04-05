# bashcheck/formatter

`formatter` turns `checker.CheckResult` values into the text formats exposed by
the CLI and library API.

## Choose An Output Target The Same Way The CLI Does

`parse_output_format` is the string-to-enum bridge used by the CLI, while
`OutputFormat::default` matches the package's default human-readable renderer.
The public enum covers tty, json, json1, gcc, checkstyle, quiet, and diff.

```mbt check
///|
test "doc formatter parses CLI format names" {
  match @formatter.parse_output_format("diff") {
    Some(@formatter.OutputFormat::Diff) => ()
    _ => abort("expected diff")
  }
  assert_true(@formatter.parse_output_format("bogus") is None)
  ignore(@formatter.OutputFormat::default())
}
```

## Render One Set Of Results In Different Representations

`render_results` is the main entry point. Feed it one or more
`checker.CheckResult` values and the target format you want. Use
`severity_text` when some surrounding integration needs the formatter's textual
severity labels.

```mbt check
///|
test "doc formatter renders the same result as tty and json" {
  let result = @checker.check_script(
    "echo `foo`\n",
    spec=@checker.CheckSpec::default().with_filename(Some("script.sh")),
  )
  let tty = @formatter.render_results(
    [result],
    match @formatter.parse_output_format("tty") {
      Some(format) => format
      None => abort("missing tty")
    },
    options=@formatter.FormatOptions::default().with_wiki_link_count(1),
  )
  let json = @formatter.render_results(
    [result],
    match @formatter.parse_output_format("json") {
      Some(format) => format
      None => abort("missing json")
    },
  )

  assert_true(tty.contains("SC2006"))
  assert_true(json.contains("\"code\":2006"))
  assert_true(result.diagnostics.length() > 0)
  ignore(@formatter.severity_text(result.diagnostics[0]))
}
```

## Tune Presentation Without Changing The Underlying Diagnostics

`FormatOptions` controls shared rendering behavior such as wiki-link count and
ANSI color. That lets the same `CheckResult` feed both machine-readable output
and nicer terminal output without changing the diagnostics themselves.

```mbt check
///|
test "doc formatter uses FormatOptions to shape output details" {
  let result = @checker.check_script("echo `foo`\n")
  let tty = match @formatter.parse_output_format("tty") {
    Some(format) => format
    None => abort("missing tty")
  }
  let plain = @formatter.render_results(
    [result],
    tty,
    options=@formatter.FormatOptions::default().with_wiki_link_count(0),
  )
  let colored = @formatter.render_results(
    [result],
    tty,
    options=@formatter.FormatOptions::default()
      .with_wiki_link_count(0)
      .with_enable_color(true),
  )

  assert_true(plain.contains("SC2006"))
  assert_true(colored.contains("\u001B["))
}
```
