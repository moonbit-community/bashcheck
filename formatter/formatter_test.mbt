///|
fn named_format(name : String) -> OutputFormat {
  match parse_output_format(name) {
    Some(format) => format
    None => panic()
  }
}

///|
fn count_substring(text : String, pattern : String) -> Int {
  if pattern == "" {
    return 0
  }
  let mut count = 0
  let mut start = 0
  while start + pattern.length() <= text.length() {
    if text.view(start_offset=start).to_string().has_prefix(pattern) {
      count += 1
      start += pattern.length()
    } else {
      start += 1
    }
  }
  count
}

///|
fn substring_index(text : String, pattern : String) -> Int? {
  if pattern == "" {
    return Some(0)
  }
  let mut start = 0
  while start + pattern.length() <= text.length() {
    if text.view(start_offset=start).to_string().has_prefix(pattern) {
      return Some(start)
    }
    start += 1
  }
  None
}

///|
fn substring_index_or_panic(text : String, pattern : String) -> Int {
  match substring_index(text, pattern) {
    Some(index) => index
    None => panic()
  }
}

///|
fn check_ok(
  source : String,
  spec? : @checker.CheckSpec = @checker.CheckSpec::default(),
) -> @checker.CheckResult {
  @checker.check_script(source, spec~)
}

///|
test "formatter renders supported output formats" {
  let result = check_ok(
    "echo before\necho `foo`\necho after\n",
    spec=@checker.CheckSpec::default().with_filename(Some("script.sh")),
  )
  let results = [result]

  let tty = render_results(
    results,
    named_format("tty"),
    options=FormatOptions::default().with_wiki_link_count(1),
  )
  let json = render_results(results, named_format("json"))
  let json1 = render_results(results, named_format("json1"))
  let gcc = render_results(results, named_format("gcc"))
  let checkstyle = render_results(results, named_format("checkstyle"))
  let diff = render_results(
    results,
    named_format("diff"),
    options=FormatOptions::default().with_wiki_link_count(0),
  )

  assert_true(tty.contains("In script.sh line 2:"))
  assert_true(tty.contains("^---^ SC2006"))
  assert_true(tty.contains("Did you mean:"))
  assert_true(tty.contains("echo $(foo)"))
  assert_true(tty.contains("For more information:"))
  assert_true(tty.contains("https://www.shellcheck.net/wiki/SC"))
  assert_eq(count_substring(tty, "https://www.shellcheck.net/wiki/SC"), 1)
  assert_true(json.contains("\"code\":2006"))
  assert_true(json1.contains("\"comments\":"))
  assert_true(gcc.contains("[SC2006]"))
  assert_true(checkstyle.contains("<checkstyle"))
  assert_eq(render_results(results, named_format("quiet")), "")
  assert_true(diff.contains("--- a/script.sh"))
  assert_true(diff.contains("+++ b/script.sh"))
  assert_true(diff.contains("@@ -1,3 +1,3 @@"))
  assert_true(diff.contains(" echo before"))
  assert_true(diff.contains("-echo `foo`"))
  assert_true(diff.contains("+echo $(foo)"))
  assert_true(diff.contains(" echo after"))
}

///|
test "formatter colorizes tty and diff output when enabled" {
  let result = @checker.check_script("echo `foo`\n")
  let results = [result]
  let options = FormatOptions::default()
    .with_wiki_link_count(0)
    .with_enable_color(true)

  let tty = render_results(results, named_format("tty"), options~)
  let diff = render_results(results, named_format("diff"), options~)

  assert_true(tty.contains("\u001B["))
  assert_true(diff.contains("\u001B["))
}

///|
test "formatter parses named formats" {
  assert_true(parse_output_format("tty") is Some(_))
  assert_true(parse_output_format("json") is Some(_))
  assert_true(parse_output_format("checkstyle") is Some(_))
  assert_true(parse_output_format("bogus") is None)
}

///|
test "formatter orders wiki footer like shellcheck severity buckets" {
  let result = check_ok(
    "#!/bin/bash\n# shellcheck disable=SC2034\necho `foo`\nread foo\n",
    spec=@checker.CheckSpec::default().with_filename(Some("script.sh")),
  )
  let tty = render_results(
    [result],
    named_format("tty"),
    options=FormatOptions::default().with_wiki_link_count(3),
  )
  let first = substring_index_or_panic(tty, "SC2046 --")
  let second = substring_index_or_panic(tty, "SC2162 --")
  let third = substring_index_or_panic(tty, "SC2005 --")
  assert_true(first < second)
  assert_true(second < third)
}

///|
test "formatter diff marks missing trailing newline" {
  let result = check_ok(
    "#!/bin/bash\necho `foo`",
    spec=@checker.CheckSpec::default().with_filename(Some("script.sh")),
  )
  let diff = render_results([result], named_format("diff"))
  assert_true(diff.contains("-echo `foo`"))
  assert_true(diff.contains("\\ No newline at end of file"))
  assert_true(diff.contains("+echo $(foo)"))
}

///|
test "formatter json fix replacements match shellcheck field shape" {
  let result = check_ok(
    "#!/bin/bash\necho `foo`\nread foo\n",
    spec=@checker.CheckSpec::default().with_filename(Some("script.sh")),
  )
  let json1 = render_results([result], named_format("json1"))
  let diff = render_results([result], named_format("diff"))

  assert_true(
    json1.contains(
      "\"replacements\":[{\"column\":6,\"endColumn\":11,\"endLine\":2,\"insertionPoint\":\"beforeStart\",\"line\":2,\"precedence\":0,\"replacement\":\"$(foo)\"}]",
    ),
  )
  assert_true(!json1.contains("\"replacements\":[{\"file\":"))
  assert_true(diff.contains("+echo $(foo)"))
  assert_true(diff.contains("+read -r foo"))
}
