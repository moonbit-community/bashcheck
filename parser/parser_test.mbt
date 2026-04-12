///|
fn parse_ok(source : String) -> @parser.Script {
  match @parser.parse_script(source) {
    Ok(script) => script
    Err(err) => abort("parse failed: \{err}")
  }
}

///|
fn parse_error(source : String) -> String {
  match @parser.parse_script(source) {
    Ok(script) => abort("expected parse error, got \{script.dump()}")
    Err(err) => err.to_string()
  }
}

///|
fn first_command(script : @parser.Script) -> @parser.Command {
  script.items[0].and_or.head.segments[0].command
}

///|
fn command_at(script : @parser.Script, index : Int) -> @parser.Command {
  script.items[index].and_or.head.segments[0].command
}

///|
fn first_simple(
  script : @parser.Script,
) -> (@parser.Command, @parser.SimpleCommand) {
  let command = first_command(script)
  match command.kind {
    @parser.CommandKind::Simple(simple) => (command, simple)
    _ => abort("expected simple command, got \{script.dump()}")
  }
}

///|
fn simple_at(
  script : @parser.Script,
  index : Int,
) -> (@parser.Command, @parser.SimpleCommand) {
  let command = command_at(script, index)
  match command.kind {
    @parser.CommandKind::Simple(simple) => (command, simple)
    _ => abort("expected simple command, got \{script.dump()}")
  }
}

///|
fn parse_report(source : String) -> @parser.ParseReport {
  @parser.parse_script_report(source)
}

///|
fn parse_report_with_options(
  source : String,
  options : @parser.ParseOptions,
) -> @parser.ParseReport {
  @parser.parse_script_with_options(source, options)
}

///|
fn report_has_code(report : @parser.ParseReport, code : Int) -> Bool {
  for diagnostic in report.diagnostics {
    if diagnostic.code == Some(code) {
      return true
    }
  }
  false
}

///|
fn report_has_code_on_line(
  report : @parser.ParseReport,
  code : Int,
  line : Int,
) -> Bool {
  for diagnostic in report.diagnostics {
    if diagnostic.code == Some(code) && diagnostic.span.start.line == line {
      return true
    }
  }
  false
}

///|
fn report_has_message(report : @parser.ParseReport, needle : String) -> Bool {
  for diagnostic in report.diagnostics {
    if diagnostic.message.contains(needle) {
      return true
    }
  }
  false
}

///|
fn report_script(report : @parser.ParseReport) -> @parser.Script {
  match report.script {
    Some(script) => script
    None => abort("expected parsed script report")
  }
}

///|
fn arithmetic_raw(expr : @parser.ArithmeticExpr) -> String {
  expr.raw
}

///|
fn index_raw(index : @parser.ArrayIndex) -> String {
  index.raw
}

///|
fn assignment_word(value : @parser.AssignmentValue) -> @parser.Word {
  match value {
    @parser.AssignmentValue::Word(word) => word
    _ => abort("expected assignment word value")
  }
}

///|
fn arithmetic_index_expr(index : @parser.ArrayIndex) -> @parser.ArithmeticExpr {
  match index.arithmetic {
    Some(expr) => expr
    None => abort("expected arithmetic index expression")
  }
}

///|
fn arithmetic_variable_index(
  expr : @parser.ArithmeticExpr,
  name : String,
) -> @parser.ArrayIndex {
  for token in expr.tokens {
    match token {
      @parser.ArithmeticToken::Variable(token_name, indexes) =>
        if token_name == name && indexes.length() > 0 {
          return indexes[0]
        }
      _ => ()
    }
  }
  abort("expected arithmetic variable \{name}")
}

///|
fn braced_parameter(part : @parser.WordPart) -> @parser.ParameterExpansion {
  match part {
    @parser.WordPart::BracedParameter(expansion) => expansion
    _ => abort("expected braced parameter")
  }
}

///|
test "fragment parsers keep direct word and arithmetic structure" {
  let word = @parser.parse_text_as_word("\"$HOME\"/*.sh")
  assert_eq(word.source, "\"$HOME\"/*.sh")
  assert_true(word.parts.length() >= 2)
  match word.parts[0] {
    @parser.WordPart::DoubleQuoted(parts) => assert_true(parts.length() > 0)
    _ => fail("expected double-quoted prefix in direct word parse")
  }

  let expr = @parser.parse_arithmetic_expr("x + arr[i]")
  assert_eq(expr.raw, "x + arr[i]")
  assert_true(expr.tokens.length() >= 3)
  match expr.tokens[2] {
    @parser.ArithmeticToken::Variable(name, indexes) => {
      assert_eq(name, "arr")
      assert_eq(indexes.length(), 1)
      assert_eq(index_raw(indexes[0]), "i")
    }
    _ => fail("expected indexed variable token in arithmetic parse")
  }
}

///|
test "simple command with assignment, quotes, and redirect" {
  let script = parse_ok("FOO=bar echo \"hi $USER\" >out")
  let (command, simple) = first_simple(script)
  assert_eq(script.items.length(), 1)
  assert_eq(simple.assignments.length(), 1)
  assert_eq(simple.words.length(), 2)
  assert_eq(command.redirects.length(), 1)
  let assignment = simple.assignments[0]
  assert_eq(assignment.name, "FOO")
  assert_eq(assignment.append, false)
  assert_eq(assignment.indexes.length(), 0)
  assert_eq(assignment_word(assignment.value).source, "bar")
  assert_eq(simple.words[0].source, "echo")
  assert_eq(simple.words[1].source, "\"hi $USER\"")
  match simple.words[1].parts[0] {
    @parser.WordPart::DoubleQuoted(parts) => {
      assert_eq(parts.length(), 2)
      match parts[0] {
        @parser.WordPart::Literal(text) => assert_eq(text, "hi ")
        _ => fail("expected literal text, got \{script.dump()}")
      }
      match parts[1] {
        @parser.WordPart::Parameter(name) => assert_eq(name, "USER")
        _ => fail("expected parameter expansion, got \{script.dump()}")
      }
    }
    _ => fail("expected double quoted word, got \{script.dump()}")
  }
  match command.redirects[0].target {
    @parser.RedirectionTarget::Word(word) => assert_eq(word.source, "out")
    _ => fail("expected file redirection target, got \{script.dump()}")
  }
}

///|
test "pipeline and boolean chain dump" {
  let script = parse_ok("echo a | grep a && echo ok || echo no")
  assert_eq(
    script.dump(),
    (
      #|script[simple(assign=[], words=[word([lit("echo")]), word([lit("a")])]) | simple(assign=[], words=[word([lit("grep")]), word([lit("a")])]) && simple(assign=[], words=[word([lit("echo")]), word([lit("ok")])]) || simple(assign=[], words=[word([lit("echo")]), word([lit("no")])])]
    ),
  )
}

///|
test "reserved-word prefixes remain ordinary words" {
  let script = parse_ok("while true; do done-thing; done")
  let command = first_command(script)
  match command.kind {
    @parser.CommandKind::While(clause) => {
      let (_, simple) = first_simple(clause.body)
      assert_eq(simple.words.length(), 1)
      assert_eq(simple.words[0].source, "done-thing")
    }
    _ => fail("expected while clause, got \{script.dump()}")
  }
}

///|
test "derived debug works for ast" {
  let script = parse_ok("echo x")
  let text = @debug.to_string(script)
  assert_true(text.contains("Simple"))
  assert_true(text.contains("Literal"))
}

///|
test "function with brace body and if clause" {
  let script = parse_ok(
    "foo() { if test -n \"$x\"; then echo yes; else echo no; fi; }",
  )
  let command = first_command(script)
  match command.kind {
    @parser.CommandKind::Function(function_) => {
      assert_eq(function_.name, "foo")
      assert_eq(function_.uses_keyword, false)
      assert_eq(function_.has_parentheses, true)
      match function_.body.kind {
        @parser.CommandKind::BraceGroup(body) => {
          assert_eq(body.items.length(), 1)
          let inner = first_command(body)
          match inner.kind {
            @parser.CommandKind::If(clause) => {
              assert_eq(clause.arms.length(), 1)
              assert_true(clause.else_body is Some(_))
            }
            _ => fail("expected if clause, got \{body.dump()}")
          }
        }
        _ => fail("expected brace group body, got \{script.dump()}")
      }
    }
    _ => fail("expected function definition, got \{script.dump()}")
  }
}

///|
test "function bodies require brace groups or subshells like shellcheck" {
  let report = parse_report("foo() if true; then echo hi; fi")
  assert_true(report.script is None)
  assert_true(report_has_code(report, 1073))
  assert_true(report_has_code(report, 1064))
  assert_true(report_has_code(report, 1072))
}

///|
test "function keyword accepts extended shellcheck-style names" {
  let script = parse_ok("function []!() { true; }")
  let command = first_command(script)
  match command.kind {
    @parser.CommandKind::Function(function_) => {
      assert_eq(function_.name, "[]!")
      assert_true(function_.uses_keyword)
      assert_true(function_.has_parentheses)
    }
    _ => fail("expected function definition, got \{script.dump()}")
  }
}

///|
test "bare function names follow shellcheck-style character rules" {
  let script = parse_ok(
    (
      #|@require(){ :; }
      #|foo#bar(){ :; }
      #|
    ),
  )
  match first_command(script).kind {
    @parser.CommandKind::Function(function_) =>
      assert_eq(function_.name, "@require")
    _ => fail("expected first function definition")
  }
  match script.items[1].and_or.head.segments[0].command.kind {
    @parser.CommandKind::Function(function_) =>
      assert_eq(function_.name, "foo#bar")
    _ => fail("expected second function definition")
  }

  let invalid = parse_report("*(){ :; }")
  assert_true(invalid.script is None)
  assert_true(invalid.diagnostics.length() >= 1)
}

///|
test "function diagnostics remain recoverable" {
  let report = parse_report(
    (
      #|foo(a, b) { true; }
      #|function foo{
      #|true
      #|}
      #|
    ),
  )
  let script = report_script(report)
  assert_eq(script.items.length(), 2)
  assert_true(report_has_code(report, 1065))
  assert_true(report_has_code(report, 1095))

  match first_command(script).kind {
    @parser.CommandKind::Function(function_) => {
      assert_eq(function_.name, "foo")
      assert_true(function_.has_parentheses)
    }
    _ => fail("expected first recoverable function definition")
  }

  match script.items[1].and_or.head.segments[0].command.kind {
    @parser.CommandKind::Function(function_) => {
      assert_eq(function_.name, "foo")
      assert_true(function_.uses_keyword)
      assert_true(!function_.has_parentheses)
    }
    _ => fail("expected second recoverable function definition")
  }
}

///|
test "time command wraps compound commands and pipelines" {
  let timed_if = parse_ok("time if true; then echo foo; fi")
  match first_command(timed_if).kind {
    @parser.CommandKind::Time(clause) => {
      assert_eq(clause.flags.length(), 0)
      assert_eq(clause.body.segments.length(), 1)
      match clause.body.segments[0].command.kind {
        @parser.CommandKind::If(inner) => assert_eq(inner.arms.length(), 1)
        _ => fail("expected timed if body")
      }
    }
    _ => fail("expected time command")
  }

  let timed_pipeline = parse_ok("time -p echo a | grep a && echo done")
  assert_eq(timed_pipeline.items.length(), 1)
  assert_eq(timed_pipeline.items[0].and_or.tail.length(), 1)
  match timed_pipeline.items[0].and_or.head.segments[0].command.kind {
    @parser.CommandKind::Time(clause) => {
      assert_eq(clause.flags.length(), 1)
      assert_eq(clause.flags[0].source, "-p")
      assert_eq(clause.body.segments.length(), 2)
      assert_eq(clause.body.operators.length(), 1)
    }
    _ => fail("expected timed pipeline")
  }

  let bare = parse_ok("time")
  let (_, simple) = first_simple(bare)
  assert_eq(simple.words.length(), 1)
  assert_eq(simple.words[0].source, "time")
}

///|
test "for loop with command substitution in double quotes" {
  let script = parse_ok(
    "for name in a \"b c\"; do echo \"$(printf %s \"$name\")\"; done",
  )
  let command = first_command(script)
  match command.kind {
    @parser.CommandKind::ForIn(clause) => {
      assert_eq(clause.name, "name")
      assert_eq(clause.values.length(), 2)
      assert_eq(clause.values[0].source, "a")
      assert_eq(clause.values[1].source, "\"b c\"")
      let (_, simple) = first_simple(clause.body)
      assert_eq(simple.words.length(), 2)
      match simple.words[1].parts[0] {
        @parser.WordPart::DoubleQuoted(parts) =>
          match parts[0] {
            @parser.WordPart::CommandSubstitution(inner) =>
              assert_true(inner.dump().contains("printf"))
            _ =>
              fail("expected command substitution, got \{clause.body.dump()}")
          }
        _ =>
          fail(
            "expected double quoted command substitution, got \{clause.body.dump()}",
          )
      }
    }
    _ => fail("expected for loop, got \{script.dump()}")
  }
}

///|
test "simple here doc stores parsed parts" {
  let script = parse_ok(
    (
      #|cat <<EOF
      #|hello $USER
      #|EOF
      #|
    ),
  )
  let (command, simple) = first_simple(script)
  assert_eq(simple.words.length(), 1)
  assert_eq(command.redirects.length(), 1)
  match command.redirects[0].target {
    @parser.RedirectionTarget::HereDoc(doc) => {
      assert_eq(doc.delimiter, "EOF")
      assert_eq(
        doc.body,
        (
          #|hello $USER
          #|
        ),
      )
      assert_eq(doc.quoted, false)
      match doc.parts {
        Some(parts) => assert_true(parts.length() >= 2)
        None => fail("expected parsed heredoc parts")
      }
    }
    _ => fail("expected here doc, got \{script.dump()}")
  }
}

///|
test "unquoted here doc keeps quote characters literal" {
  let script = parse_ok(
    (
      #|cat <<EOF
      #|"$USER"
      #|EOF
      #|
    ),
  )
  let command = first_command(script)
  match command.redirects[0].target {
    @parser.RedirectionTarget::HereDoc(doc) =>
      match doc.parts {
        Some(parts) => {
          assert_eq(parts.length(), 3)
          match parts[0] {
            @parser.WordPart::Literal(text) => assert_eq(text, "\"")
            _ => fail("expected literal opening quote, got \{script.dump()}")
          }
          match parts[1] {
            @parser.WordPart::Parameter(name) => assert_eq(name, "USER")
            _ => fail("expected parameter expansion, got \{script.dump()}")
          }
          match parts[2] {
            @parser.WordPart::Literal(text) =>
              assert_eq(
                text,
                (
                  #|"
                  #|
                ),
              )
            _ => fail("expected literal closing quote, got \{script.dump()}")
          }
        }
        None => fail("expected parsed heredoc parts")
      }
    _ => fail("expected here doc, got \{script.dump()}")
  }
}

///|
test "here doc can hang off command inside if" {
  let script = parse_ok(
    (
      #|if true; then cat <<EOF; fi
      #|hello
      #|EOF
      #|
    ),
  )
  let command = first_command(script)
  match command.kind {
    @parser.CommandKind::If(clause) => {
      let inner = first_command(clause.arms[0].body)
      match inner.kind {
        @parser.CommandKind::Simple(_) =>
          match inner.redirects[0].target {
            @parser.RedirectionTarget::HereDoc(doc) =>
              assert_eq(
                doc.body,
                (
                  #|hello
                  #|
                ),
              )
            _ => fail("expected here doc in if body, got \{script.dump()}")
          }
        _ => fail("expected simple command in if body, got \{script.dump()}")
      }
    }
    _ => fail("expected if clause, got \{script.dump()}")
  }
}

///|
test "top level metadata and source command" {
  let script = parse_ok(
    (
      #|#!/usr/bin/env bash
      #|# shellcheck disable=SC2086 shell=bash
      #|source lib.sh foo
      #|
    ),
  )
  match script.shebang {
    Some(line) => assert_eq(line, "#!/usr/bin/env bash")
    None => fail("expected shebang")
  }
  assert_eq(script.annotations.length(), 2)
  let command = first_command(script)
  match command.kind {
    @parser.CommandKind::Source(source) => {
      assert_eq(source.assignments.length(), 0)
      assert_eq(source.keyword, "source")
      assert_eq(source.path.source, "lib.sh")
      assert_eq(source.args.length(), 1)
      assert_eq(source.args[0].source, "foo")
    }
    _ => fail("expected source command, got \{script.dump()}")
  }
}

///|
test "source command captures options and resolves includes from parse options" {
  let options = @parser.ParseOptions::new(
    false,
    false,
    false,
    true,
    Some("scripts/main.sh"),
    ["scripts/lib"],
    [
      (
        "scripts/lib/helpers.sh",
        (
          #|echo hi
          #|
        ),
      ),
    ],
  )
  let report = parse_report_with_options(
    (
      #|source -p vendor/lib helpers.sh foo
      #|
    ),
    options,
  )
  let script = report_script(report)
  match first_command(script).kind {
    @parser.CommandKind::Source(source) => {
      assert_eq(source.assignments.length(), 0)
      assert_eq(source.options.length(), 2)
      assert_eq(source.options[0].source, "-p")
      assert_eq(source.options[1].source, "vendor/lib")
      assert_eq(source.path.source, "helpers.sh")
      assert_eq(source.args.length(), 1)
      assert_eq(source.args[0].source, "foo")
      match source.resolved_path {
        Some(path) => assert_eq(path, "scripts/lib/helpers.sh")
        None => fail("expected resolved source path")
      }
      match source.included {
        Some(included) => {
          let (_, simple) = first_simple(included)
          assert_eq(simple.words[0].source, "echo")
          assert_eq(simple.words[1].source, "hi")
        }
        None => fail("expected included script")
      }
    }
    _ => fail("expected source command")
  }
}

///|
test "source resolution accepts quoted constants and source annotations" {
  let options = @parser.ParseOptions::new(
    false,
    false,
    false,
    true,
    Some("scripts/main.sh"),
    ["scripts/lib"],
    [
      (
        "scripts/lib/helpers.sh",
        (
          #|echo hi
          #|
        ),
      ),
    ],
  )

  let quoted_report = parse_report_with_options(
    (
      #|source "helpers.sh"
      #|
    ),
    options,
  )
  let quoted_script = report_script(quoted_report)
  match first_command(quoted_script).kind {
    @parser.CommandKind::Source(source) => {
      match source.resolved_path {
        Some(path) => assert_eq(path, "scripts/lib/helpers.sh")
        None => fail("expected resolved quoted source path")
      }
      assert_true(source.included is Some(_))
    }
    _ => fail("expected source command")
  }

  let override_report = parse_report_with_options(
    (
      #|echo before
      #|# shellcheck source=helpers.sh
      #|source "$lib"
      #|
    ),
    options,
  )
  let override_script = report_script(override_report)
  assert_eq(override_script.items[1].annotations.length(), 1)
  match override_script.items[1].and_or.head.segments[0].command.kind {
    @parser.CommandKind::Source(source) => {
      match source.resolved_path {
        Some(path) => assert_eq(path, "scripts/lib/helpers.sh")
        None => fail("expected source override to resolve include")
      }
      assert_true(source.included is Some(_))
    }
    _ => fail("expected annotated source command")
  }
}

///|
test "pipeline segments preserve repeated and inline bang prefixes" {
  let script = parse_ok("! ! true | ! false")
  let pipeline = script.items[0].and_or.head
  assert_eq(pipeline.segments.length(), 2)
  assert_eq(pipeline.segments[0].bangs, 2)
  assert_eq(pipeline.segments[1].bangs, 1)
  match pipeline.segments[0].command.kind {
    @parser.CommandKind::Simple(simple) =>
      assert_eq(simple.words[0].source, "true")
    _ => fail("expected first negated simple command")
  }
  match pipeline.segments[1].command.kind {
    @parser.CommandKind::Simple(simple) =>
      assert_eq(simple.words[0].source, "false")
    _ => fail("expected second negated simple command")
  }
}

///|
test "supported env split-string shebang is accepted" {
  let script = parse_ok(
    (
      #|#!/usr/bin/env --split-string=FOO=bar bash -eu
      #|true
      #|
    ),
  )
  match script.shebang {
    Some(line) =>
      assert_eq(line, "#!/usr/bin/env --split-string=FOO=bar bash -eu")
    None => fail("expected shebang")
  }
}

///|
test "shellcheck shell directive overrides shebang shell validation" {
  let script = parse_ok(
    (
      #|#!/usr/bin/perl
      #|# shellcheck shell=bash
      #|echo hi
      #|
    ),
  )
  assert_eq(script.annotations.length(), 1)
  match script.annotations[0] {
    @parser.Annotation::Shell(shell) => assert_eq(shell, "bash")
    _ => fail("expected shell override annotation")
  }
}

///|
test "shellcheck shell directive accepts shellcheck-known aliases" {
  let script = parse_ok(
    (
      #|# shellcheck shell="busybox ash"
      #|true
      #|
    ),
  )
  assert_eq(script.annotations.length(), 1)
  match script.annotations[0] {
    @parser.Annotation::Shell(shell) => assert_eq(shell, "busybox ash")
    _ => fail("expected busybox ash shell annotation")
  }
}

///|
test "malformed first-line shebangs report explicit errors" {
  let leading = parse_error(
    (
      #|  #!/bin/bash
      #|echo hi
      #|
    ),
  )
  assert_true(leading.contains("Remove leading spaces before the shebang."))

  let spaced = parse_error(
    (
      #|# !/bin/bash
      #|echo hi
      #|
    ),
  )
  assert_true(spaced.contains("Remove spaces between # and ! in the shebang."))

  let swapped = parse_error(
    (
      #|!#/bin/bash
      #|echo hi
      #|
    ),
  )
  assert_true(swapped.contains("Use #!, not !#, for the shebang."))

  let missing_hash = parse_error(
    (
      #|! /bin/bash
      #|echo hi
      #|
    ),
  )
  assert_true(missing_hash.contains("Use #!, not just !, for the shebang."))

  let missing_bang = parse_error(
    (
      #|# /bin/bash
      #|echo hi
      #|
    ),
  )
  assert_true(missing_bang.contains("Use #!, not just #, for the shebang."))
}

///|
test "shebangs after headers are rejected" {
  let blank_prefixed = parse_error(
    (
      #|
      #|#!/bin/bash
      #|echo hi
      #|
    ),
  )
  assert_true(
    blank_prefixed.contains(
      "The shebang must be on the first line. Delete blanks and move comments.",
    ),
  )

  let comment_prefixed = parse_error(
    (
      #|# Copyright
      #|#!/bin/bash
      #|echo hi
      #|
    ),
  )
  assert_true(
    comment_prefixed.contains(
      "The shebang must be on the first line. Delete blanks and move comments.",
    ),
  )
}

///|
test "unsupported and unknown shebang shells are rejected without override" {
  let unsupported_report = parse_report(
    (
      #|#!/usr/bin/perl
      #|echo hi
      #|
    ),
  )
  assert_true(report_has_code(unsupported_report, 1071))
  let unsupported = parse_error(
    (
      #|#!/usr/bin/perl
      #|echo hi
      #|
    ),
  )
  assert_true(unsupported.contains("unsupported shebang shell 'perl'"))

  let unknown_report = parse_report(
    (
      #|#!/usr/bin/env customsh
      #|echo hi
      #|
    ),
  )
  assert_true(report_has_code(unknown_report, 1008))
  let unknown = parse_error(
    (
      #|#!/usr/bin/env customsh
      #|echo hi
      #|
    ),
  )
  assert_true(unknown.contains("unrecognized shebang shell 'customsh'"))
}

///|
test "utf-8 bom emits shellcheck-style diagnostic while preserving metadata" {
  let report = parse_report(
    (
      #|﻿echo hi
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report_has_code(report, 1082))
  assert_true(script.has_bom)
}

///|
test "unknown shell directive values are rejected" {
  let unknown = parse_error(
    (
      #|# shellcheck shell=customsh
      #|true
      #|
    ),
  )
  assert_true(unknown.contains("unknown shell directive value 'customsh'"))

  let path = parse_error(
    (
      #|# shellcheck shell=/bin/bash
      #|true
      #|
    ),
  )
  assert_true(path.contains("unknown shell directive value '/bin/bash'"))
}

///|
test "quoted shellcheck annotations preserve valid keys and report forbidden inline external-sources" {
  let report = parse_report(
    (
      #|# shellcheck source-path="foo bar" external_sources=true extended_analysis=false
      #|true
      #|
    ),
  )
  let script = report_script(report)
  assert_eq(script.annotations.length(), 2)
  assert_eq(report.diagnostics.length(), 1)
  match script.annotations[0] {
    @parser.Annotation::SourcePath(path) => assert_eq(path, "foo bar")
    _ => fail("expected quoted source-path annotation")
  }
  match script.annotations[1] {
    @parser.Annotation::ExtendedAnalysis(flag) => assert_eq(flag, false)
    _ => fail("expected extended_analysis annotation")
  }
  assert_true(
    report.diagnostics[0].message.contains(
      "external-sources can only be enabled",
    ),
  )
}

///|
test "quoted shellcheck directive values preserve backslashes literally" {
  let script = parse_ok(
    (
      #|# shellcheck source="lib\\ name.sh" source-path="foo\\bar"
      #|true
      #|
    ),
  )
  assert_eq(script.annotations.length(), 2)
  match script.annotations[0] {
    @parser.Annotation::Source(path) => assert_eq(path, "lib\\\\ name.sh")
    _ => fail("expected source directive with literal backslash")
  }
  match script.annotations[1] {
    @parser.Annotation::SourcePath(path) => assert_eq(path, "foo\\\\bar")
    _ => fail("expected source-path directive with literal backslashes")
  }
}

///|
test "disable and enable directives accept shellcheck-style values" {
  let script = parse_ok(
    (
      #|# shellcheck disable='SC1000,SC2000-SC3000,all' enable="quote-safe,require-variable-braces"
      #|true
      #|
    ),
  )
  assert_eq(script.annotations.length(), 5)
  match script.annotations[0] {
    @parser.Annotation::Disable(code) => assert_eq(code, "SC1000")
    _ => fail("expected first disable code")
  }
  match script.annotations[1] {
    @parser.Annotation::Disable(code) => assert_eq(code, "SC2000-SC3000")
    _ => fail("expected disable range")
  }
  match script.annotations[2] {
    @parser.Annotation::Disable(code) => assert_eq(code, "all")
    _ => fail("expected disable all")
  }
  match script.annotations[3] {
    @parser.Annotation::Enable(name) => assert_eq(name, "quote-safe")
    _ => fail("expected first enable name")
  }
  match script.annotations[4] {
    @parser.Annotation::Enable(name) =>
      assert_eq(name, "require-variable-braces")
    _ => fail("expected second enable name")
  }
}

///|
test "invalid shellcheck boolean values become diagnostics" {
  let report = parse_report(
    (
      #|# shellcheck external-sources=yes extended-analysis=maybe
      #|true
      #|
    ),
  )
  let script = report_script(report)
  assert_eq(script.annotations.length(), 0)
  assert_eq(report.diagnostics.length(), 2)
}

///|
test "shellcheck directives reject unterminated quoted values" {
  let err = parse_error(
    (
      #|# shellcheck source="foo bar
      #|true
      #|
    ),
  )
  assert_true(err.contains("missing terminating quote for directive"))
}

///|
test "unknown shellcheck keys are ignored while valid ones still parse" {
  let script = parse_ok(
    (
      #|# shellcheck frob=wat disable=SC2086 source=lib.sh
      #|true
      #|
    ),
  )
  assert_eq(script.annotations.length(), 2)
  match script.annotations[0] {
    @parser.Annotation::Disable(code) => assert_eq(code, "SC2086")
    _ => fail("expected disable annotation")
  }
  match script.annotations[1] {
    @parser.Annotation::Source(path) => assert_eq(path, "lib.sh")
    _ => fail("expected source annotation")
  }
}

///|
test "invalid directive pairs ignore the rest of the line" {
  let report = parse_report(
    (
      #|# shellcheck disable=SC2086 broken shell=bash source=lib.sh
      #|true
      #|
    ),
  )
  let script = report_script(report)
  assert_eq(script.annotations.length(), 1)
  match script.annotations[0] {
    @parser.Annotation::Disable(code) => assert_eq(code, "SC2086")
    _ => fail("expected disable annotation before invalid pair")
  }
  assert_true(report.diagnostics[0].message.contains("invalid key=value pair"))
}

///|
test "invalid disable and enable values become diagnostics and stop the rest of the line" {
  let disable_report = parse_report(
    (
      #|# shellcheck disable=SC2086 disable=wat source=lib.sh
      #|true
      #|
    ),
  )
  let disable_script = report_script(disable_report)
  assert_eq(disable_script.annotations.length(), 1)
  match disable_script.annotations[0] {
    @parser.Annotation::Disable(code) => assert_eq(code, "SC2086")
    _ => fail("expected only the valid disable before invalid one")
  }
  assert_true(disable_report.diagnostics[0].message.contains("invalid disable"))

  let enable_report = parse_report(
    (
      #|# shellcheck enable=require-variable-braces,123 source=lib.sh
      #|true
      #|
    ),
  )
  let enable_script = report_script(enable_report)
  assert_eq(enable_script.annotations.length(), 0)
  assert_true(enable_report.diagnostics[0].message.contains("invalid enable"))
}

///|
test "directive csv whitespace becomes a diagnostic" {
  let report = parse_report(
    (
      #|# shellcheck disable=SC2086, SC2154 source=lib.sh
      #|true
      #|
    ),
  )
  let script = report_script(report)
  assert_eq(script.annotations.length(), 0)
  assert_true(report.diagnostics[0].message.contains("invalid disable"))
}

///|
test "directive values do not treat backslashes as shell escapes" {
  let report = parse_report(
    (
      #|# shellcheck source=foo\ bar disable=SC2086
      #|true
      #|
    ),
  )
  let script = report_script(report)
  assert_eq(script.annotations.length(), 1)
  match script.annotations[0] {
    @parser.Annotation::Source(path) => assert_eq(path, "foo\\")
    _ => fail("expected literal backslash source path")
  }
  assert_true(report.diagnostics[0].message.contains("invalid key=value pair"))
}

///|
test "list items preserve shellcheck annotations beyond file metadata" {
  let script = parse_ok(
    (
      #|echo one
      #|# shellcheck disable=SC2086 source=lib.sh
      #|# ordinary comment
      #|echo two
      #|
    ),
  )
  assert_eq(script.annotations.length(), 0)
  assert_eq(script.items.length(), 2)
  assert_eq(script.items[0].annotations.length(), 0)
  assert_eq(script.items[1].annotations.length(), 2)
  match script.items[1].annotations[0] {
    @parser.Annotation::Disable(code) => assert_eq(code, "SC2086")
    _ => fail("expected disable annotation on second item")
  }
  match script.items[1].annotations[1] {
    @parser.Annotation::Source(path) => assert_eq(path, "lib.sh")
    _ => fail("expected source annotation on second item")
  }
}

///|
test "nested compound bodies preserve shellcheck annotations on list items" {
  let script = parse_ok(
    (
      #|if true; then
      #|# shellcheck disable=SC2016
      #|echo '$HOME'
      #|fi
      #|
    ),
  )
  match first_command(script).kind {
    @parser.CommandKind::If(clause) => {
      assert_eq(clause.arms.length(), 1)
      assert_eq(clause.arms[0].body.items.length(), 1)
      assert_eq(clause.arms[0].body.items[0].annotations.length(), 1)
      match clause.arms[0].body.items[0].annotations[0] {
        @parser.Annotation::Disable(code) => assert_eq(code, "SC2016")
        _ => fail("expected nested disable annotation")
      }
    }
    _ => fail("expected if clause")
  }
}

///|
test "command-leading braces become brace groups while literal braces still work in words" {
  let report = parse_report(
    (
      #|{foo;}
      #|echo {bar} foo{baz} }qux
      #|
    ),
  )
  let script = match report.script {
    Some(script) => script
    None => fail(@debug.to_string(report))
  }
  match first_command(script).kind {
    @parser.CommandKind::BraceGroup(body) => {
      let (_, simple) = first_simple(body)
      assert_eq(simple.words.length(), 1)
      assert_eq(simple.words[0].source, "foo")
    }
    _ => fail("expected brace group at command start")
  }
  assert_eq(report.diagnostics.length(), 6)
  assert_eq(report.diagnostics[0].code, Some(1054))
  assert_eq(report.diagnostics[0].message, "You need a space after the '{'.")
  for i in 1..<report.diagnostics.length() {
    assert_eq(report.diagnostics[i].code, Some(1083))
  }
  let command = script.items[1].and_or.head.segments[0].command
  match command.kind {
    @parser.CommandKind::Simple(simple) => {
      assert_eq(simple.words.length(), 4)
      assert_eq(simple.words[0].source, "echo")
      assert_eq(simple.words[1].source, "{bar}")
      assert_eq(simple.words[2].source, "foo{baz}")
      assert_eq(simple.words[3].source, "}qux")
    }
    _ => fail("expected simple command, got \{script.dump()}")
  }
}

///|
test "top-level closing brace reports reserved-word error" {
  let err = parse_error(
    (
      #|}
      #|
    ),
  )
  assert_true(err.contains("unexpected reserved word '}'"))
}

///|
test "single and double bracket conditions parse as dedicated commands" {
  let double_script = parse_ok("[[ -n $x ]]")
  match first_command(double_script).kind {
    @parser.CommandKind::Condition(condition) => {
      match condition.kind {
        @parser.ConditionKind::DoubleBracket => ()
        _ => fail("expected double bracket kind")
      }
      assert_true(condition.raw.contains("$x"))
      match condition.expr {
        @parser.ConditionExpr::Unary(op, _, operand) => {
          assert_eq(op, "-n")
          assert_eq(operand.source, "$x")
        }
        _ => fail("expected unary condition expression")
      }
    }
    _ => fail("expected double bracket condition")
  }
  let single_script = parse_ok("[ -n \"$x\" ]")
  match first_command(single_script).kind {
    @parser.CommandKind::Condition(condition) => {
      match condition.kind {
        @parser.ConditionKind::SingleBracket => ()
        _ => fail("expected single bracket kind")
      }
      assert_true(condition.raw.contains("\"$x\""))
      match condition.expr {
        @parser.ConditionExpr::Unary(op, _, operand) => {
          assert_eq(op, "-n")
          assert_eq(operand.source, "\"$x\"")
        }
        _ => fail("expected unary single-bracket expression")
      }
    }
    _ => fail("expected single bracket condition")
  }
}

///|
test "condition expressions capture grouping and boolean operators" {
  let script = parse_ok("[[ (a == b) || (c == d) ]]")
  match first_command(script).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Or(left, right) => {
          match left {
            @parser.ConditionExpr::Group(inner) =>
              match inner {
                @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
                  assert_eq(op, "==")
                  assert_eq(lhs.source, "a")
                  assert_eq(rhs.source, "b")
                }
                _ => fail("expected grouped binary lhs")
              }
            _ => fail("expected grouped lhs")
          }
          match right {
            @parser.ConditionExpr::Group(inner) =>
              match inner {
                @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
                  assert_eq(op, "==")
                  assert_eq(lhs.source, "c")
                  assert_eq(rhs.source, "d")
                }
                _ => fail("expected grouped binary rhs")
              }
            _ => fail("expected grouped rhs")
          }
        }
        _ => fail("expected boolean condition expression")
      }
    _ => fail("expected condition command")
  }
}

///|
test "grouped conditions require closing parentheses" {
  let double_err = parse_error("[[ (a == b ]]")
  assert_true(double_err.contains("missing ')' in condition expression"))

  let single_err = parse_error("[ \\( a = b ]")
  assert_true(single_err.contains("missing ')' in condition expression"))
}

///|
test "condition expressions support negation, escaped groups, and regex words" {
  let negated = parse_ok("[[ ! -n $x ]]")
  match first_command(negated).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Not(inner) =>
          match inner {
            @parser.ConditionExpr::Unary(op, _, operand) => {
              assert_eq(op, "-n")
              assert_eq(operand.source, "$x")
            }
            _ => fail("expected negated unary condition")
          }
        _ => fail("expected negated condition")
      }
    _ => fail("expected condition command")
  }

  let grouped = parse_ok("[ \\( a = b \\) -a \\( c = d \\) ]")
  match first_command(grouped).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::And(left, right) => {
          match left {
            @parser.ConditionExpr::Group(inner) =>
              match inner {
                @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
                  assert_eq(op, "=")
                  assert_eq(lhs.source, "a")
                  assert_eq(rhs.source, "b")
                }
                _ => fail("expected grouped lhs binary")
              }
            _ => fail("expected grouped lhs")
          }
          match right {
            @parser.ConditionExpr::Group(inner) =>
              match inner {
                @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
                  assert_eq(op, "=")
                  assert_eq(lhs.source, "c")
                  assert_eq(rhs.source, "d")
                }
                _ => fail("expected grouped rhs binary")
              }
            _ => fail("expected grouped rhs")
          }
        }
        _ => fail("expected single-bracket grouped condition")
      }
    _ => fail("expected condition command")
  }

  let regex = parse_ok("[[ $1 =~ a(b)|c ]]")
  match first_command(regex).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
          assert_eq(op, "=~")
          assert_eq(lhs.source, "$1")
          assert_eq(rhs.source, "a(b)|c")
        }
        _ => fail("expected regex comparison")
      }
    _ => fail("expected condition command")
  }
}

///|
test "double bracket string comparison operators parse like shellcheck" {
  let greater = parse_ok("[[ $cword > 1 ]]")
  match first_command(greater).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
          assert_eq(op, ">")
          assert_eq(lhs.source, "$cword")
          assert_eq(rhs.source, "1")
        }
        _ => fail("expected binary string comparison")
      }
    _ => fail("expected condition command")
  }

  let lesser = parse_ok("[[ $cword < 10 ]]")
  match first_command(lesser).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
          assert_eq(op, "<")
          assert_eq(lhs.source, "$cword")
          assert_eq(rhs.source, "10")
        }
        _ => fail("expected binary string comparison")
      }
    _ => fail("expected condition command")
  }
}

///|
test "condition parser preserves unknown operators for checks" {
  let unary = parse_report("[ -M a ]")
  assert_true(!report_has_code(unary, 1073))
  let unary_script = report_script(unary)
  match first_command(unary_script).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Unary(op, _, operand) => {
          assert_eq(op, "-M")
          assert_eq(operand.source, "a")
        }
        _ => fail("expected unknown unary operator to be preserved")
      }
    _ => fail("expected condition command")
  }

  let longer_unary = parse_report("[ -abc a ]")
  assert_true(!report_has_code(longer_unary, 1073))
  let longer_unary_script = report_script(longer_unary)
  match first_command(longer_unary_script).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Unary(op, _, operand) => {
          assert_eq(op, "-abc")
          assert_eq(operand.source, "a")
        }
        _ => fail("expected longer unknown unary operator to be preserved")
      }
    _ => fail("expected condition command")
  }

  let binary = parse_report("[[ a -xz b ]]")
  assert_true(!report_has_code(binary, 1073))
  let binary_script = report_script(binary)
  match first_command(binary_script).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
          assert_eq(op, "-xz")
          assert_eq(lhs.source, "a")
          assert_eq(rhs.source, "b")
        }
        _ => fail("expected unknown binary operator to be preserved")
      }
    _ => fail("expected condition command")
  }

  let longer_binary = parse_report("[[ a -xyz b ]]")
  assert_true(!report_has_code(longer_binary, 1073))
  let longer_binary_script = report_script(longer_binary)
  match first_command(longer_binary_script).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
          assert_eq(op, "-xyz")
          assert_eq(lhs.source, "a")
          assert_eq(rhs.source, "b")
        }
        _ => fail("expected longer unknown binary operator to be preserved")
      }
    _ => fail("expected condition command")
  }
}

///|
test "dash-prefixed non-operators do not become unknown operators" {
  let dash_number = parse_report("[ -1 a ]")
  assert_true(!report_has_code(dash_number, 1019))

  let double_dash = parse_report("[ -- a ]")
  assert_true(!report_has_code(double_dash, 1019))

  let dash_dot = parse_report("[ -. a ]")
  assert_true(!report_has_code(dash_dot, 1019))

  let binary_number = parse_report("[[ a -1 b ]]")
  assert_true(!report_has_code(binary_number, 1027))

  let binary_double_dash = parse_report("[[ a -- b ]]")
  assert_true(!report_has_code(binary_double_dash, 1027))

  let binary_dash_dot = parse_report("[[ a -. b ]]")
  assert_true(!report_has_code(binary_dash_dot, 1027))
}

///|
test "conditions reject missing operands and trailing words" {
  let unary_report = parse_report("[[ -n ]]")
  assert_true(report_has_code(unary_report, 1073))
  assert_true(report_has_code(unary_report, 1019))
  assert_true(report_has_code(unary_report, 1072))

  let binary_report = parse_report("[[ foo == ]]")
  assert_true(report_has_code(binary_report, 1073))
  assert_true(report_has_code(binary_report, 1027))
  assert_true(report_has_code(binary_report, 1072))

  let single_binary_report = parse_report("[ foo = ]")
  assert_true(report_has_code(single_binary_report, 1073))
  assert_true(report_has_code(single_binary_report, 1027))
  assert_true(report_has_code(single_binary_report, 1072))

  let trailing_expr = parse_error("[[ foo bar ]]")
  assert_true(
    trailing_expr.contains("unexpected tokens after condition expression"),
  )

  let double_trailing = parse_report(
    (
      #|[[ x ]] foo
      #|
    ),
  )
  assert_true(report_has_code_on_line(double_trailing, 1140, 1))

  let single_trailing = parse_report(
    (
      #|[ x ] foo
      #|
    ),
  )
  assert_true(report_has_code_on_line(single_trailing, 1140, 1))

  let double_legacy = parse_report(
    (
      #|[[ x ]] -a [[ y ]]
      #|
    ),
  )
  assert_true(report_has_code_on_line(double_legacy, 1139, 1))

  let single_legacy = parse_report(
    (
      #|[ x ] or [ y ]
      #|
    ),
  )
  assert_true(report_has_code_on_line(single_legacy, 1139, 1))
}

///|
test "compound commands require separators before following words" {
  let brace_report = parse_report(
    (
      #|{ echo hi; } foo
      #|
    ),
  )
  assert_true(report_has_code_on_line(brace_report, 1141, 1))

  let arithmetic_report = parse_report(
    (
      #|((x)) bar
      #|
    ),
  )
  assert_true(report_has_code_on_line(arithmetic_report, 1141, 1))
}

///|
test "regex conditions keep grouped patterns and embedded closing brackets" {
  let grouped = parse_ok("[[ $c =~ f( ]] )* ]]")
  match first_command(grouped).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
          assert_eq(op, "=~")
          assert_eq(lhs.source, "$c")
          assert_eq(rhs.source, "f( ]] )*")
        }
        _ => fail("expected grouped regex comparison")
      }
    _ => fail("expected condition command")
  }

  let embedded = parse_ok("[[ $c =~ f( ($var ]]) )* ]]")
  match first_command(embedded).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
          assert_eq(op, "=~")
          assert_eq(lhs.source, "$c")
          assert_eq(rhs.source, "f( ($var ]]) )*")
        }
        _ => fail("expected embedded-bracket regex comparison")
      }
    _ => fail("expected condition command")
  }

  let escaped = parse_ok("[[ $1 =~ ^(a\\ b)$ ]]")
  match first_command(escaped).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
          assert_eq(op, "=~")
          assert_eq(lhs.source, "$1")
          assert_eq(rhs.source, "^(a\\ b)$")
        }
        _ => fail("expected escaped-space regex comparison")
      }
    _ => fail("expected condition command")
  }

  let logical_chars = parse_ok("[[ $v =~ a&&b|c||d ]]")
  match first_command(logical_chars).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
          assert_eq(op, "=~")
          assert_eq(lhs.source, "$v")
          assert_eq(rhs.source, "a&&b|c||d")
        }
        _ => fail("expected regex with logical-looking literals")
      }
    _ => fail("expected condition command")
  }

  let escaped_groups = parse_ok("[[ $1 =~ \\.a\\.(\\.b\\.)\\.c\\. ]]")
  match first_command(escaped_groups).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Binary(op, _, lhs, rhs) => {
          assert_eq(op, "=~")
          assert_eq(lhs.source, "$1")
          assert_eq(rhs.source, "\\.a\\.(\\.b\\.)\\.c\\.")
        }
        _ => fail("expected escaped-group regex comparison")
      }
    _ => fail("expected condition command")
  }
}

///|
test "regex condition parts preserve backslashes" {
  let script = parse_ok("[[ $1 =~ \\.a\\.(\\.b\\.)\\.c\\. ]]")
  match first_command(script).kind {
    @parser.CommandKind::Condition(condition) =>
      match condition.expr {
        @parser.ConditionExpr::Binary(_, _, _, rhs) => {
          assert_eq(rhs.source, "\\.a\\.(\\.b\\.)\\.c\\.")
          match rhs.parts[0] {
            @parser.WordPart::Literal(text) =>
              assert_eq(text, "\\.a\\.(\\.b\\.)\\.c\\.")
            _ => fail("expected regex literal part")
          }
        }
        _ => fail("expected regex condition")
      }
    _ => fail("expected condition command")
  }
}

///|
test "arithmetic command and arithmetic for loop" {
  let arithmetic = parse_ok("(( i += 1 ))")
  match first_command(arithmetic).kind {
    @parser.CommandKind::Arithmetic(command) => {
      assert_true(command.raw.contains("i += 1"))
      assert_true(command.expr.tokens.length() >= 3)
    }
    _ => fail("expected arithmetic command")
  }
  let for_script = parse_ok("for ((i = 0; i < 3; i++)); do echo $i; done")
  match first_command(for_script).kind {
    @parser.CommandKind::ForArithmetic(clause) => {
      assert_eq(arithmetic_raw(clause.init), "i = 0")
      assert_eq(arithmetic_raw(clause.condition), "i < 3")
      assert_eq(arithmetic_raw(clause.step), "i++")
      assert_eq(clause.body.items.length(), 1)
    }
    _ => fail("expected arithmetic for loop")
  }
}

///|
test "arithmetic for loop delimiter diagnostics align more closely with shellcheck" {
  let spaced = parse_report(
    (
      #|for ( (i = 0; i < 3; i++) ) do echo $i; done
      #|
    ),
  )
  let spaced_script = report_script(spaced)
  assert_true(report_has_code(spaced, 1138))
  match first_command(spaced_script).kind {
    @parser.CommandKind::ForArithmetic(clause) => {
      assert_eq(arithmetic_raw(clause.init), "i = 0")
      assert_eq(arithmetic_raw(clause.condition), "i < 3")
      assert_eq(arithmetic_raw(clause.step), "i++")
    }
    _ => fail("expected arithmetic for loop with spaced delimiters")
  }

  let missing_open = parse_report(
    (
      #|for (;;); do echo $i; done
      #|
    ),
  )
  assert_true(report_has_code(missing_open, 1137))
  assert_true(missing_open.script is None)
}

///|
test "arithmetic nodes preserve variable indices" {
  let script = parse_ok("(( arr[i + 1] += total ))")
  match first_command(script).kind {
    @parser.CommandKind::Arithmetic(command) => {
      let mut saw_indexed = false
      for token in command.expr.tokens {
        match token {
          @parser.ArithmeticToken::Variable(name, indexes) =>
            if name == "arr" {
              saw_indexed = true
              assert_eq(indexes.length(), 1)
              assert_eq(index_raw(indexes[0]), "i + 1")
              assert_eq(
                arithmetic_raw(arithmetic_index_expr(indexes[0])),
                "i + 1",
              )
            }
          _ => ()
        }
      }
      assert_true(saw_indexed)
    }
    _ => fail("expected arithmetic command")
  }
}

///|
test "arithmetic expressions keep shell fragments and line continuations structured" {
  let script = parse_ok(
    (
      #|(( 1+`echo 2` + $foo + $? + 10#08 * 16#f + \
      #|  foo[9*y+x] ))
    ),
  )
  match first_command(script).kind {
    @parser.CommandKind::Arithmetic(command) => {
      let mut saw_backtick = false
      let mut saw_parameter = false
      let mut saw_special = false
      let mut saw_base = false
      let mut saw_continuation_literal = false
      let mut saw_index = false
      for token in command.expr.tokens {
        match token {
          @parser.ArithmeticToken::Expansion(word) =>
            match word.parts[0] {
              @parser.WordPart::BackQuoted(inner) => {
                saw_backtick = true
                assert_true(inner.dump().contains("echo"))
              }
              @parser.WordPart::Parameter(name) =>
                if name == "foo" {
                  saw_parameter = true
                }
              @parser.WordPart::SpecialParameter(name) =>
                if name == "?" {
                  saw_special = true
                }
              _ => ()
            }
          @parser.ArithmeticToken::Literal(text) =>
            if text == "10#08" || text == "16#f" {
              saw_base = true
            } else if text == "\\" {
              saw_continuation_literal = true
            }
          @parser.ArithmeticToken::Variable(name, indexes) =>
            if name == "foo" {
              saw_index = true
              assert_eq(index_raw(indexes[0]), "9*y+x")
              assert_eq(
                arithmetic_raw(arithmetic_index_expr(indexes[0])),
                "9*y+x",
              )
            }
          _ => ()
        }
      }
      assert_true(saw_backtick)
      assert_true(saw_parameter)
      assert_true(saw_special)
      assert_true(saw_base)
      assert_true(saw_index)
      assert_true(!saw_continuation_literal)
    }
    _ => fail("expected arithmetic command")
  }
}

///|
test "ambiguous dollar-double-paren falls back to command substitution with a diagnostic" {
  let report = parse_report("echo $((echo hi))")
  let script = report_script(report)
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::CommandSubstitution(inner) =>
      match first_command(inner).kind {
        @parser.CommandKind::Subshell(body) => {
          let (_, nested) = first_simple(body)
          assert_eq(nested.words[0].source, "echo")
          assert_eq(nested.words[1].source, "hi")
        }
        _ => fail("expected subshell command substitution")
      }
    _ => fail("expected command substitution fallback")
  }
  let mut saw_ambiguity = false
  for diagnostic in report.diagnostics {
    if diagnostic.code == Some(1102) {
      saw_ambiguity = true
    }
  }
  assert_true(saw_ambiguity)
}

///|
test "ambiguous dollar-double-paren diagnostic keeps shellcheck severity and span" {
  let report = parse_report(
    (
      #|echo $(((1)) && 3)
      #|
    ),
  )
  let mut found = false
  for diagnostic in report.diagnostics {
    if diagnostic.code == Some(1102) {
      found = true
      match diagnostic.severity {
        @parser.DiagnosticSeverity::Error => ()
        _ => fail("expected SC1102 to stay an error-severity diagnostic")
      }
      assert_eq(diagnostic.span.start.line, 1)
      assert_eq(diagnostic.span.start.column, 6)
    }
  }
  assert_true(found)
}

///|
test "ambiguous double-paren compound commands fall back to subshells" {
  let report = parse_report(
    (
      #|(( i++ ) # comment
      #|)
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report_has_code(report, 1105))
  match first_command(script).kind {
    @parser.CommandKind::Subshell(body) => assert_eq(body.items.length(), 1)
    _ => fail("expected subshell fallback")
  }
}

///|
test "select, case, and coproc commands" {
  let select_script = parse_ok("select name in a b; do echo $name; done")
  match first_command(select_script).kind {
    @parser.CommandKind::Select(clause) => {
      assert_eq(clause.name, "name")
      assert_eq(clause.values.length(), 2)
    }
    _ => fail("expected select clause")
  }

  let case_script = parse_ok(
    "case $x in a|b) echo one ;; c) echo two ;& d) echo three ;; esac",
  )
  match first_command(case_script).kind {
    @parser.CommandKind::Case(clause) => {
      assert_eq(clause.items.length(), 3)
      assert_eq(clause.items[0].patterns.length(), 2)
      match clause.items[1].separator {
        @parser.CaseSeparator::FallThrough => ()
        _ => fail("expected fallthrough case separator")
      }
    }
    _ => fail("expected case clause")
  }

  let implicit_break = parse_ok(
    (
      #|case x in a) echo hi
      #|esac
    ),
  )
  match first_command(implicit_break).kind {
    @parser.CommandKind::Case(clause) => {
      assert_eq(clause.items.length(), 1)
      match clause.items[0].separator {
        @parser.CaseSeparator::Break => ()
        _ => fail("expected implicit break before esac")
      }
    }
    _ => fail("expected case clause")
  }

  let coproc_script = parse_ok("coproc worker { echo hi; }")
  match first_command(coproc_script).kind {
    @parser.CommandKind::CoProc(clause) => {
      match clause.name {
        Some(word) => assert_eq(word.source, "worker")
        None => fail("expected coproc name")
      }
      match clause.body.kind {
        @parser.CommandKind::BraceGroup(_) => ()
        _ => fail("expected brace group body")
      }
    }
    _ => fail("expected coproc clause")
  }

  let anonymous_simple = parse_ok("coproc worker echo hi")
  match first_command(anonymous_simple).kind {
    @parser.CommandKind::CoProc(clause) => {
      assert_true(clause.name is None)
      match clause.body.kind {
        @parser.CommandKind::Simple(simple) => {
          assert_eq(simple.words.length(), 3)
          assert_eq(simple.words[0].source, "worker")
          assert_eq(simple.words[1].source, "echo")
          assert_eq(simple.words[2].source, "hi")
        }
        _ => fail("expected simple coproc body")
      }
    }
    _ => fail("expected coproc clause")
  }
}

///|
test "select loops accept newline separators before do without in clause" {
  let script = parse_ok(
    (
      #|select choice
      #|do echo "$choice"; done
      #|
    ),
  )
  match first_command(script).kind {
    @parser.CommandKind::Select(clause) => {
      assert_eq(clause.name, "choice")
      assert_eq(clause.values.length(), 0)
      let (_, simple) = first_simple(clause.body)
      assert_eq(simple.words[0].source, "echo")
      assert_eq(simple.words[1].source, "\"$choice\"")
    }
    _ => fail("expected select clause")
  }
}

///|
test "bats parser keeps malformed @test syntax recoverable" {
  let newline_report = parse_report(
    (
      #|@test foo 
      #|{
      #| true
      #|}
      #|
    ),
  )
  assert_true(newline_report.script is Some(_))
  assert_true(report_has_code(newline_report, 1073))
  assert_true(report_has_code(newline_report, 1072))

  let no_brace_report = parse_report(
    (
      #|@test foo
      #|
    ),
  )
  assert_true(no_brace_report.script is Some(_))
  assert_true(report_has_code(no_brace_report, 1073))
  assert_true(report_has_code(no_brace_report, 1072))

  let comment_report = parse_report(
    (
      #|@test foo # comment
      #|{
      #| true
      #|}
      #|
    ),
  )
  assert_true(comment_report.script is Some(_))
  assert_true(report_has_code(comment_report, 1073))
}

///|
test "bats parser allows empty same-line test names like shellcheck" {
  let script = parse_ok(
    (
      #|@test  {
      #|  true
      #|}
      #|
    ),
  )
  match first_command(script).kind {
    @parser.CommandKind::BatsTest(clause) => {
      assert_eq(clause.name, "")
      assert_eq(clause.body.items.length(), 1)
    }
    _ => fail("expected bats test clause")
  }
}

///|
test "comments terminate commands and inline shellcheck directives warn" {
  let script = parse_ok(
    (
      #|echo foo # comment
      #|bar && # note
      #|baz
      #|
    ),
  )
  let (_, first) = first_simple(script)
  assert_eq(first.words.length(), 2)
  assert_eq(first.words[0].source, "echo")
  assert_eq(first.words[1].source, "foo")

  assert_eq(script.items.length(), 2)
  match script.items[1].and_or.head.segments[0].command.kind {
    @parser.CommandKind::Simple(simple) =>
      assert_eq(simple.words[0].source, "bar")
    _ => fail("expected leading simple command after comment")
  }
  assert_eq(script.items[1].and_or.tail.length(), 1)
  match script.items[1].and_or.tail[0].1.segments[0].command.kind {
    @parser.CommandKind::Simple(simple) =>
      assert_eq(simple.words[0].source, "baz")
    _ => fail("expected trailing simple command after comment")
  }

  let directive = parse_report(
    (
      #|echo hi # shellcheck disable=SC2086
      #|
    ),
  )
  let directive_script = report_script(directive)
  assert_true(report_has_code(directive, 1126))
  let (_, directive_simple) = first_simple(directive_script)
  assert_eq(directive_simple.words.length(), 2)
}

///|
test "trailing shellcheck directives at eof use expected-command diagnostics" {
  let report = parse_report(
    (
      #|echo hi
      #|# shellcheck disable=SC2086
      #|
    ),
  )
  assert_true(report.script is None)
  assert_true(report_has_code(report, 1072))
  assert_true(!report_has_code(report, 1123))
}

///|
test "separator diagnostics align more closely with shellcheck" {
  let redirect_prefix = parse_ok("&> /dev/null echo foo")
  let (redirect_command, redirect_simple) = first_simple(redirect_prefix)
  assert_eq(redirect_command.redirects.length(), 1)
  assert_eq(redirect_simple.words.length(), 2)

  let background_semicolon = parse_report(
    (
      #|a &; b
      #|
    ),
  )
  let background_script = report_script(background_semicolon)
  assert_true(report_has_code(background_semicolon, 1045))
  assert_eq(background_script.items.length(), 2)

  let html_amp = parse_report(
    (
      #|a &amp; b
      #|
    ),
  )
  assert_true(report_has_code(html_amp, 1109))

  let html_gt = parse_report(
    (
      #|a &gt; file; b
      #|
    ),
  )
  assert_true(report_has_code(html_gt, 1109))

  let url = parse_report(
    (
      #|curl https://example.com/?foo=moo&bar=cow
      #|
    ),
  )
  assert_true(report_has_code(url, 1132))

  let bad_pipe_break = parse_report(
    (
      #|echo hi
      #|| cat
      #|
    ),
  )
  assert_true(report_has_code(bad_pipe_break, 1133))

  let bad_and_break = parse_report(
    (
      #|true
      #|&& echo hi
      #|
    ),
  )
  assert_true(report_has_code(bad_and_break, 1133))
}

///|
test "case branch annotations emit shellcheck-style diagnostics" {
  let report = parse_report(
    (
      #|case $x in
      #|# shellcheck disable=SC2086
      #|a) echo one ;;
      #|esac
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report_has_code(report, 1009))
  assert_true(report_has_code(report, 1073))
  assert_true(report_has_code(report, 1124))
  assert_true(report_has_code(report, 1072))
  assert_true(report_has_code(report, 1085))
  match first_command(script).kind {
    @parser.CommandKind::Case(clause) => {
      assert_eq(clause.items.length(), 1)
      assert_eq(clause.items[0].patterns[0].source, "a")
    }
    _ => fail("expected case clause")
  }
}

///|
test "case items recover missing separators and pattern closers" {
  let missing_separator = parse_report(
    (
      #|case x in
      #|a) echo one
      #|b) echo two ;;
      #|esac
      #|
    ),
  )
  let separator_script = report_script(missing_separator)
  assert_true(report_has_code(missing_separator, 1074))
  match first_command(separator_script).kind {
    @parser.CommandKind::Case(clause) => assert_eq(clause.items.length(), 2)
    _ => fail("expected recovered case clause")
  }

  let missing_paren = parse_report(
    (
      #|case x in
      #|a echo one ;;
      #|esac
      #|
    ),
  )
  assert_true(report_has_code(missing_paren, 1085))
}

///|
test "case item bodies do not mistake function and arithmetic headers for patterns" {
  let script = parse_ok(
    (
      #|case $x in
      #|
    ) +
    (
      #|a)
      #|
    ) +
    (
      #|  func_usage ()
      #|
    ) +
    (
      #|  {
      #|
    ) +
    (
      #|    echo hi
      #|
    ) +
    (
      #|  }
      #|
    ) +
    (
      #|  for ((i=0; i<1; i++)); do
      #|
    ) +
    (
      #|    echo "$i"
      #|
    ) +
    (
      #|  done
      #|
    ) +
    (
      #|  ;;
      #|
    ) +
    (
      #|esac
      #|
    ),
  )
  match first_command(script).kind {
    @parser.CommandKind::Case(clause) => {
      assert_eq(clause.items.length(), 1)
      let body_items = clause.items[0].body.items
      assert_eq(body_items.length(), 2)
      match body_items[0].and_or.head.segments[0].command.kind {
        @parser.CommandKind::Function(function_def) =>
          assert_eq(function_def.name, "func_usage")
        _ => fail("expected function definition inside case item body")
      }
      match body_items[1].and_or.head.segments[0].command.kind {
        @parser.CommandKind::ForArithmetic(_) => ()
        _ => fail("expected arithmetic for loop inside case item body")
      }
    }
    _ => fail("expected case clause")
  }
}

///|
test "bats tests are parsed as compound commands" {
  let simple = parse_ok(
    (
      #|@test 'can parse' {
      #|  true
      #|}
    ),
  )
  match first_command(simple).kind {
    @parser.CommandKind::BatsTest(clause) => {
      assert_eq(clause.name, "'can parse'")
      assert_eq(clause.body.items.length(), 1)
    }
    _ => fail("expected bats test")
  }

  let nested_name = parse_ok(
    (
      #|@test foo { bar { baz {
      #|  true
      #|}
    ),
  )
  match first_command(nested_name).kind {
    @parser.CommandKind::BatsTest(clause) => {
      assert_eq(clause.name, "foo { bar { baz")
      assert_eq(clause.body.items.length(), 1)
    }
    _ => fail("expected bats test with brace-rich name")
  }

  let quoted_brace = parse_ok(
    (
      #|@test 'brace { in name' {
      #|  true
      #|}
    ),
  )
  match first_command(quoted_brace).kind {
    @parser.CommandKind::BatsTest(clause) => {
      assert_eq(clause.name, "'brace { in name'")
      assert_eq(clause.body.items.length(), 1)
    }
    _ => fail("expected bats test with quoted brace")
  }
}

///|
test "word forms cover bash expansions" {
  let script = parse_ok(
    "echo $'hi' $\"yo\" $[1+2] `printf x` <(echo a) foo@(bar) {a,b} *.sh",
  )
  let (_, simple) = first_simple(script)
  assert_eq(simple.words.length(), 9)
  match simple.words[1].parts[0] {
    @parser.WordPart::DollarSingleQuoted(text) => assert_eq(text, "hi")
    _ => fail("expected dollar single quote")
  }
  match simple.words[2].parts[0] {
    @parser.WordPart::DollarDoubleQuoted(parts) => assert_eq(parts.length(), 1)
    _ => fail("expected dollar double quote")
  }
  match simple.words[3].parts[0] {
    @parser.WordPart::DollarBracket(expr) =>
      assert_eq(arithmetic_raw(expr), "1+2")
    _ => fail("expected dollar bracket expansion")
  }
  match simple.words[4].parts[0] {
    @parser.WordPart::BackQuoted(inner) =>
      assert_true(inner.dump().contains("printf"))
    _ => fail("expected backquoted substitution")
  }
  match simple.words[5].parts[0] {
    @parser.WordPart::ProcessSubstitution(kind, inner) => {
      assert_eq(kind, "<")
      assert_true(inner.dump().contains("echo"))
    }
    _ => fail("expected process substitution")
  }
  match simple.words[6].parts[1] {
    @parser.WordPart::ExtGlob(pattern) => {
      assert_eq(pattern.raw, "@(bar)")
      assert_eq(pattern.alternatives.length(), 1)
      assert_eq(pattern.alternatives[0].source, "bar")
    }
    _ => fail("expected extglob")
  }
  match simple.words[7].parts[0] {
    @parser.WordPart::BraceExpansion(expansion) => {
      assert_eq(expansion.raw, "{a,b}")
      assert_eq(expansion.elements.length(), 2)
      assert_eq(expansion.elements[0].source, "a")
      assert_eq(expansion.elements[1].source, "b")
    }
    _ => fail("expected brace expansion")
  }
  match simple.words[8].parts[0] {
    @parser.WordPart::Glob(raw) => assert_eq(raw, "*.sh")
    _ => fail("expected glob")
  }
}

///|
test "brace expansion ignores separators inside quotes" {
  let script = parse_ok(
    (
      #|echo {"a,b"}
      #|
    ),
  )
  let (_, simple) = first_simple(script)
  assert_eq(simple.words[1].source, "{\"a,b\"}")
  assert_eq(simple.words[1].parts.length(), 3)
  match simple.words[1].parts[0] {
    @parser.WordPart::Literal(text) => assert_eq(text, "{")
    _ => fail("expected literal opening brace")
  }
  match simple.words[1].parts[1] {
    @parser.WordPart::DoubleQuoted(parts) =>
      match parts[0] {
        @parser.WordPart::Literal(text) => assert_eq(text, "a,b")
        _ => fail("expected quoted comma to stay literal")
      }
    _ => fail("expected quoted middle section")
  }
  match simple.words[1].parts[2] {
    @parser.WordPart::Literal(text) => assert_eq(text, "}")
    _ => fail("expected literal closing brace")
  }
}

///|
test "escaped words stay literal and quoted escapes keep backslashes" {
  let script = parse_ok("echo \\*.sh \"\\q\" \\{a,b\\}")
  let (_, simple) = first_simple(script)

  assert_eq(simple.words[1].source, "\\*.sh")
  assert_eq(simple.words[1].parts.length(), 2)
  match simple.words[1].parts[0] {
    @parser.WordPart::Literal(text) => assert_eq(text, "*")
    _ => fail("expected escaped glob prefix to stay literal")
  }
  match simple.words[1].parts[1] {
    @parser.WordPart::Literal(text) => assert_eq(text, ".sh")
    _ => fail("expected escaped glob suffix to stay literal")
  }

  match simple.words[2].parts[0] {
    @parser.WordPart::DoubleQuoted(parts) =>
      match parts[0] {
        @parser.WordPart::Literal(text) => assert_eq(text, "\\q")
        _ => fail("expected ordinary double-quoted escape to keep backslash")
      }
    _ => fail("expected double quoted word")
  }

  assert_eq(simple.words[3].parts.length(), 3)
  match simple.words[3].parts[0] {
    @parser.WordPart::Literal(text) => assert_eq(text, "{")
    _ => fail("expected escaped brace prefix to stay literal")
  }
  match simple.words[3].parts[1] {
    @parser.WordPart::Literal(text) => assert_eq(text, "a,b")
    _ => fail("expected escaped brace body to stay literal")
  }
  match simple.words[3].parts[2] {
    @parser.WordPart::Literal(text) => assert_eq(text, "}")
    _ => fail("expected escaped brace suffix to stay literal")
  }
}

///|
test "brace command substitution is parsed as a word part" {
  let script = parse_ok("echo ${ echo hi; }")
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::BraceCommandSubstitution(false, inner) =>
      assert_true(inner.dump().contains("echo"))
    _ => fail("expected brace command substitution")
  }
}

///|
test "brace command substitution handles comments, nested groups, and piped form" {
  let script = parse_ok(
    (
      #|echo ${ if true; then { echo hi; } # }
      #|fi; } ${| REPLY=42; }
      #|
    ),
  )
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::BraceCommandSubstitution(false, inner) =>
      match first_command(inner).kind {
        @parser.CommandKind::If(clause) => assert_eq(clause.arms.length(), 1)
        _ => fail("expected if clause inside brace command substitution")
      }
    _ => fail("expected ordinary brace command substitution")
  }
  match simple.words[2].parts[0] {
    @parser.WordPart::BraceCommandSubstitution(true, inner) => {
      let (_, nested) = first_simple(inner)
      assert_eq(nested.assignments.length(), 1)
      assert_eq(nested.assignments[0].name, "REPLY")
    }
    _ => fail("expected piped brace command substitution")
  }
}

///|
test "ksh-style brace command substitution failures keep shellcheck context" {
  let report = parse_report(
    (
      #|echo ${ # comment
      #|x//)/_}
      #|
    ),
  )
  assert_true(report.script is None)
  assert_true(report_has_code(report, 1009))
  assert_true(report_has_code(report, 1073))
  assert_true(report_has_code(report, 1072))
  assert_true(
    !report_has_message(
      report, "unexpected tokens after command; missing ;/&&/||/|?",
    ),
  )
}

///|
test "braced parameter expansion is structured" {
  let script = parse_ok(
    "echo ${#arr[@]} ${foo:-bar} ${foo/bar/baz} ${file::1} ${!name} ${arr[$i]}",
  )
  let (_, simple) = first_simple(script)
  let length = braced_parameter(simple.words[1].parts[0])
  assert_true(length.length_prefix)
  match length.name {
    Some(name) => assert_eq(name, "arr")
    None => fail("expected length parameter name")
  }
  match length.index {
    Some(index) => assert_eq(index_raw(index), "@")
    None => fail("expected array index")
  }

  let defaulted = braced_parameter(simple.words[2].parts[0])
  match defaulted.operator {
    Some(@parser.ParameterOperator::DefaultValue(value)) =>
      assert_eq(value, "bar")
    _ => fail("expected default operator")
  }

  let replaced = braced_parameter(simple.words[3].parts[0])
  match replaced.operator {
    Some(@parser.ParameterOperator::Replace(mode, pattern, replacement)) => {
      match mode {
        @parser.ParameterReplaceMode::First => ()
        _ => fail("expected first replacement mode")
      }
      assert_eq(pattern, "bar")
      match replacement {
        Some(value) => assert_eq(value, "baz")
        None => fail("expected replacement value")
      }
    }
    _ => fail("expected replace operator")
  }

  let sliced = braced_parameter(simple.words[4].parts[0])
  match sliced.operator {
    Some(@parser.ParameterOperator::Slice(offset, Some(length))) => {
      assert_eq(offset, "")
      assert_eq(length, "1")
    }
    _ => fail("expected slice operator")
  }

  let indirect = braced_parameter(simple.words[5].parts[0])
  assert_true(indirect.indirect)
  match indirect.name {
    Some(name) => assert_eq(name, "name")
    None => fail("expected indirect name")
  }

  let indexed = braced_parameter(simple.words[6].parts[0])
  match indexed.index {
    Some(index) => assert_eq(index_raw(index), "$i")
    None => fail("expected dynamic array index")
  }
}

///|
test "braced parameter expansion supports transforms and case operators" {
  let script = parse_ok("echo ${var@Q} ${var^^} ${var,,[A-Z]} ${var~}")
  let (_, simple) = first_simple(script)

  let transformed = braced_parameter(simple.words[1].parts[0])
  match transformed.operator {
    Some(@parser.ParameterOperator::Transform(kind)) => assert_eq(kind, "Q")
    _ => fail("expected transform operator")
  }

  let upper = braced_parameter(simple.words[2].parts[0])
  match upper.operator {
    Some(@parser.ParameterOperator::CaseModify(mode, pattern)) => {
      match mode {
        @parser.ParameterCaseMode::UpperAll => ()
        _ => fail("expected upper-all mode")
      }
      match pattern {
        None => ()
        Some(_) => fail("expected no case pattern")
      }
    }
    _ => fail("expected uppercase case operator")
  }

  let lower = braced_parameter(simple.words[3].parts[0])
  match lower.operator {
    Some(@parser.ParameterOperator::CaseModify(mode, pattern)) => {
      match mode {
        @parser.ParameterCaseMode::LowerAll => ()
        _ => fail("expected lower-all mode")
      }
      match pattern {
        Some(value) => assert_eq(value, "[A-Z]")
        None => fail("expected case pattern")
      }
    }
    _ => fail("expected lowercase case operator")
  }

  let toggled = braced_parameter(simple.words[4].parts[0])
  match toggled.operator {
    Some(@parser.ParameterOperator::CaseModify(mode, pattern)) => {
      match mode {
        @parser.ParameterCaseMode::ToggleFirst => ()
        _ => fail("expected toggle-first mode")
      }
      match pattern {
        None => ()
        Some(_) => fail("expected no toggle pattern")
      }
    }
    _ => fail("expected toggle case operator")
  }
}

///|
test "braced parameter expansion keeps nested content and names operators" {
  let script = parse_ok(
    "echo ${foo:-${bar}} ${foo%%$(echo cow\\})} ${!prefix*} ${!prefix@}",
  )
  let (_, simple) = first_simple(script)

  let nested = braced_parameter(simple.words[1].parts[0])
  match nested.operator {
    Some(@parser.ParameterOperator::DefaultValue(value)) =>
      assert_eq(value, "${bar}")
    _ => fail("expected nested default expansion")
  }

  let command_sub = braced_parameter(simple.words[2].parts[0])
  match command_sub.operator {
    Some(@parser.ParameterOperator::RemoveLongestSuffix(value)) =>
      assert_eq(value, "$(echo cow\\})")
    _ => fail("expected command-substitution suffix trim")
  }

  let star_names = braced_parameter(simple.words[3].parts[0])
  assert_true(star_names.indirect)
  match star_names.operator {
    Some(@parser.ParameterOperator::Names(mode)) =>
      match mode {
        @parser.ParameterNamesMode::Star => ()
        _ => fail("expected star names mode")
      }
    _ => fail("expected names operator")
  }

  let at_names = braced_parameter(simple.words[4].parts[0])
  assert_true(at_names.indirect)
  match at_names.operator {
    Some(@parser.ParameterOperator::Names(mode)) =>
      match mode {
        @parser.ParameterNamesMode::At => ()
        _ => fail("expected at names mode")
      }
    _ => fail("expected names operator")
  }
}

///|
test "assignments, arrays, and named redirections are preserved" {
  let script = parse_ok("arr[0]+=x vals=(a b) printf x {fd}>>out &>>all.log")
  let (command, simple) = first_simple(script)
  assert_eq(simple.assignments.length(), 2)
  assert_eq(index_raw(simple.assignments[0].indexes[0]), "0")
  assert_eq(simple.assignments[0].append, true)
  assert_eq(assignment_word(simple.assignments[0].value).source, "x")
  match simple.assignments[1].value {
    @parser.AssignmentValue::ArrayLiteral(elements) => {
      assert_eq(elements.length(), 2)
      assert_eq(elements[0].indexes.length(), 0)
      assert_eq(assignment_word(elements[0].value).source, "a")
      assert_eq(assignment_word(elements[1].value).source, "b")
    }
    _ => fail("expected array literal assignment")
  }
  assert_eq(command.redirects.length(), 2)
  match command.redirects[0].source {
    Some(@parser.RedirectionSource::Named(name)) => assert_eq(name, "fd")
    _ => fail("expected named redirection source")
  }
  match command.redirects[1].source {
    Some(@parser.RedirectionSource::All) => ()
    _ => fail("expected all-stream redirection source")
  }
}

///|
test "modifier commands accept assignment suffixes" {
  let exported = parse_ok("export foo=(bar baz)")
  let (_, export_simple) = first_simple(exported)
  assert_eq(export_simple.words.length(), 1)
  assert_eq(export_simple.words[0].source, "export")
  assert_eq(export_simple.assignments.length(), 1)
  match export_simple.assignments[0].value {
    @parser.AssignmentValue::ArrayLiteral(elements) => {
      assert_eq(elements.length(), 2)
      assert_eq(assignment_word(elements[0].value).source, "bar")
      assert_eq(assignment_word(elements[1].value).source, "baz")
    }
    _ => fail("expected export array assignment")
  }

  let typed = parse_ok("typeset -a foo=(lol)")
  let (_, typed_simple) = first_simple(typed)
  assert_eq(typed_simple.words.length(), 2)
  assert_eq(typed_simple.words[0].source, "typeset")
  assert_eq(typed_simple.words[1].source, "-a")
  assert_eq(typed_simple.assignments.length(), 1)
  match typed_simple.assignments[0].value {
    @parser.AssignmentValue::ArrayLiteral(elements) =>
      assert_eq(assignment_word(elements[0].value).source, "lol")
    _ => fail("expected typeset array assignment")
  }
}

///|
test "array literal supports indexed and nested elements" {
  let script = parse_ok("arr=([2]=foo [3]=(bar baz) qux)")
  let (_, simple) = first_simple(script)
  match simple.assignments[0].value {
    @parser.AssignmentValue::ArrayLiteral(elements) => {
      assert_eq(elements.length(), 3)
      assert_eq(index_raw(elements[0].indexes[0]), "2")
      assert_eq(elements[0].append, false)
      assert_eq(assignment_word(elements[0].value).source, "foo")
      assert_eq(index_raw(elements[1].indexes[0]), "3")
      assert_eq(elements[1].append, false)
      match elements[1].value {
        @parser.AssignmentValue::ArrayLiteral(nested) => {
          assert_eq(nested.length(), 2)
          assert_eq(assignment_word(nested[0].value).source, "bar")
          assert_eq(assignment_word(nested[1].value).source, "baz")
        }
        _ => fail("expected nested array literal")
      }
      assert_eq(assignment_word(elements[2].value).source, "qux")
    }
    _ => fail("expected structured array literal")
  }
}

///|
test "backquoted and heredoc escapes preserve backslashes" {
  let backquoted = parse_ok("echo `printf \\q`")
  let (_, simple) = first_simple(backquoted)
  match simple.words[1].parts[0] {
    @parser.WordPart::BackQuoted(inner) => {
      let (_, nested) = first_simple(inner)
      assert_eq(nested.words.length(), 2)
      assert_eq(nested.words[0].source, "printf")
      assert_eq(nested.words[1].source, "\\q")
    }
    _ => fail("expected backquoted substitution")
  }

  let heredoc = parse_ok(
    (
      #|cat <<EOF
      #|\a
      #|\$USER
      #|EOF
      #|
    ),
  )
  let (command, _) = first_simple(heredoc)
  match command.redirects[0].target {
    @parser.RedirectionTarget::HereDoc(doc) => {
      assert_eq(
        doc.body,
        (
          #|\a
          #|\$USER
          #|
        ),
      )
      match doc.parts {
        Some(parts) =>
          match parts[0] {
            @parser.WordPart::Literal(text) =>
              assert_eq(
                text,
                (
                  #|\a
                  #|$USER
                  #|
                ),
              )
            _ => fail("expected literal here-doc part")
          }
        None => fail("expected parsed heredoc parts")
      }
    }
    _ => fail("expected here doc")
  }
}

///|
test "assignment diagnostics align more closely with shellcheck" {
  let report = parse_report(
    (
      #|foo= bar
      #|IFS= value
      #|foo==bar
      #|a=((1))
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report_has_code_on_line(report, 1007, 1))
  assert_true(!report_has_code_on_line(report, 1007, 2))
  assert_true(report_has_code_on_line(report, 1097, 3))
  assert_true(report_has_code_on_line(report, 1116, 4))

  match first_command(script).kind {
    @parser.CommandKind::Simple(simple) => {
      assert_eq(simple.assignments.length(), 1)
      assert_eq(simple.words.length(), 1)
      assert_eq(simple.words[0].source, "bar")
      match simple.assignments[0].value {
        @parser.AssignmentValue::Empty => ()
        _ => fail("expected empty assignment value before spaced word")
      }
    }
    _ => fail("expected first simple assignment command")
  }

  match script.items[2].and_or.head.segments[0].command.kind {
    @parser.CommandKind::Simple(simple) => {
      assert_eq(simple.assignments.length(), 1)
      assert_eq(assignment_word(simple.assignments[0].value).source, "=bar")
    }
    _ => fail("expected double-equals assignment probe")
  }
}

///|
test "bang spacing and dollar-left array assignments emit shellcheck diagnostics" {
  let bang = parse_report(
    (
      #|!foo
      #|
    ),
  )
  let bang_script = report_script(bang)
  assert_true(report_has_code(bang, 1035))
  let segment = bang_script.items[0].and_or.head.segments[0]
  assert_eq(segment.bangs, 1)
  match segment.command.kind {
    @parser.CommandKind::Simple(simple) =>
      assert_eq(simple.words[0].source, "foo")
    _ => fail("expected negated simple command")
  }

  let lhs = parse_report(
    (
      #|$foo=(bar)
      #|
    ),
  )
  assert_true(report_has_code(lhs, 1066))
  assert_true(lhs.script is None)

  let indexed_lhs = parse_report(
    (
      #|$foo[${x//]/_}]=(bar)
      #|
    ),
  )
  assert_true(report_has_code(indexed_lhs, 1066))
  assert_true(indexed_lhs.script is None)
}

///|
test "double-quoted lonely dollars and bare expansions emit shellcheck-style diagnostics" {
  let report = parse_report(
    (
      #|echo "$"5
      #|echo $10
      #|echo $arr[@]
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report_has_code(report, 1135))
  assert_true(report_has_code(report, 1037))
  assert_true(report_has_code(report, 1087))

  match first_command(script).kind {
    @parser.CommandKind::Simple(simple) => {
      assert_eq(simple.words[1].parts.length(), 2)
      match simple.words[1].parts[0] {
        @parser.WordPart::DoubleQuoted(parts) =>
          match parts[0] {
            @parser.WordPart::Literal(text) => assert_eq(text, "$")
            _ => fail("expected literal dollar in double quotes")
          }
        _ => fail("expected double-quoted literal dollar")
      }
      match simple.words[1].parts[1] {
        @parser.WordPart::Literal(text) => assert_eq(text, "5")
        _ => fail("expected suffix literal after literal dollar")
      }
    }
    _ => fail("expected first simple command")
  }

  match script.items[1].and_or.head.segments[0].command.kind {
    @parser.CommandKind::Simple(simple) => {
      assert_eq(simple.words[1].parts.length(), 2)
      match simple.words[1].parts[0] {
        @parser.WordPart::SpecialParameter(name) => assert_eq(name, "1")
        _ => fail("expected positional parameter token")
      }
      match simple.words[1].parts[1] {
        @parser.WordPart::Literal(text) => assert_eq(text, "0")
        _ => fail("expected literal suffix for $10")
      }
    }
    _ => fail("expected second simple command")
  }

  match script.items[2].and_or.head.segments[0].command.kind {
    @parser.CommandKind::Simple(simple) => {
      assert_eq(simple.words[1].parts.length(), 2)
      match simple.words[1].parts[0] {
        @parser.WordPart::Parameter(name) => assert_eq(name, "arr")
        _ => fail("expected array name parameter")
      }
      match simple.words[1].parts[1] {
        @parser.WordPart::Glob(raw) => assert_eq(raw, "[@]")
        _ => fail("expected glob suffix for unbraced array expansion")
      }
    }
    _ => fail("expected third simple command")
  }
}

///|
test "bare dollar diagnostics preserve shellcheck-style spans and recovery" {
  let report = parse_report(
    (
      #|echo "$"5
      #|echo $10
      #|echo $arr[@]
      #|
    ),
  )
  let script = report_script(report)

  let mut saw_1135 = false
  let mut saw_1037 = false
  let mut saw_1087 = false
  for diagnostic in report.diagnostics {
    if diagnostic.code == Some(1135) {
      saw_1135 = true
      assert_eq(diagnostic.span.start.line, 1)
      assert_eq(diagnostic.span.start.column, 7)
    }
    if diagnostic.code == Some(1037) {
      saw_1037 = true
      assert_eq(diagnostic.span.start.line, 2)
      assert_eq(diagnostic.span.start.column, 6)
    }
    if diagnostic.code == Some(1087) {
      saw_1087 = true
      assert_eq(diagnostic.span.start.line, 3)
      assert_eq(diagnostic.span.start.column, 6)
    }
  }
  assert_true(saw_1135)
  assert_true(saw_1037)
  assert_true(saw_1087)

  match script.items[1].and_or.head.segments[0].command.kind {
    @parser.CommandKind::Simple(simple) => {
      assert_eq(simple.words[1].parts.length(), 2)
      match simple.words[1].parts[0] {
        @parser.WordPart::SpecialParameter(name) => assert_eq(name, "1")
        _ => fail("expected positional parameter recovery for $10")
      }
      match simple.words[1].parts[1] {
        @parser.WordPart::Literal(text) => assert_eq(text, "0")
        _ => fail("expected trailing digit to stay literal after $10")
      }
    }
    _ => fail("expected second simple command")
  }

  match script.items[2].and_or.head.segments[0].command.kind {
    @parser.CommandKind::Simple(simple) => {
      assert_eq(simple.words[1].parts.length(), 2)
      match simple.words[1].parts[0] {
        @parser.WordPart::Parameter(name) => assert_eq(name, "arr")
        _ => fail("expected bare parameter before array warning")
      }
      match simple.words[1].parts[1] {
        @parser.WordPart::Glob(text) => assert_eq(text, "[@]")
        _ => fail("expected trailing [@] to remain as glob text")
      }
    }
    _ => fail("expected third simple command")
  }
}

///|
test "normal word diagnostics align with shellcheck for escapes and reserved words" {
  let escapes = parse_report(
    (
      #|echo \n \t \r \c
      #|
    ),
  )
  let escapes_script = report_script(escapes)
  assert_true(report_has_code(escapes, 1012))
  assert_true(report_has_code(escapes, 1001))
  let (_, simple) = first_simple(escapes_script)
  assert_eq(simple.words.length(), 5)
  assert_eq(simple.words[1].source, "\\n")
  assert_eq(simple.words[2].source, "\\t")
  assert_eq(simple.words[3].source, "\\r")
  assert_eq(simple.words[4].source, "\\c")

  let line_break = parse_report(
    (
      #|echo foo\ 
      #|bar
      #|
    ),
  )
  let line_break_script = report_script(line_break)
  assert_true(report_has_code(line_break, 1101))
  assert_eq(line_break_script.items.length(), 2)

  let single_quote = parse_report(
    (
      #|echo 'it\'s'
      #|
    ),
  )
  assert_true(report_has_code(single_quote, 1003))
  assert_true(single_quote.script is None)
}

///|
test "literal apostrophe escapes stay quiet like shellcheck" {
  let simple = parse_report(
    (
      #|echo \'
      #|
    ),
  )
  assert_true(!report_has_code(simple, 1001))

  let pattern = parse_report(
    (
      #|case $x in
      #|*-dark\') echo ok ;;
      #|\'*HighContrast*) echo hi ;;
      #|esac
      #|
    ),
  )
  assert_true(!report_has_code(pattern, 1001))
  match first_command(report_script(pattern)).kind {
    @parser.CommandKind::Case(clause) => assert_eq(clause.items.length(), 2)
    _ => fail("expected case clause")
  }
}

///|
test "multiline single quotes can concatenate with adjacent double quotes" {
  let report = parse_report(
    (
      #|echo 'foo
      #|bar'"baz"
      #|
    ),
  )
  assert_true(!report_has_code(report, 1078))
  assert_true(!report_has_code(report, 1079))
  match first_command(report_script(report)).kind {
    @parser.CommandKind::Simple(simple) =>
      assert_eq(
        simple.words[1].source,
        (
          #|'foo
          #|bar'"baz"
        ),
      )
    _ => fail("expected simple command")
  }
}

///|
test "literal curly braces in normal words warn like shellcheck" {
  let report = parse_report(
    (
      #|echo HEAD^{commit} HEAD^2^{tree} foo/{}
      #|
    ),
  )
  let script = report_script(report)
  let mut literal_brace_warnings = 0
  for diagnostic in report.diagnostics {
    if diagnostic.code == Some(1083) {
      literal_brace_warnings += 1
    }
  }
  assert_eq(literal_brace_warnings, 4)
  let (_, simple) = first_simple(script)
  assert_eq(simple.words[1].source, "HEAD^{commit}")
  assert_eq(simple.words[2].source, "HEAD^2^{tree}")
  assert_eq(simple.words[3].source, "foo/{}")
}

///|
test "here doc parsing propagates nested diagnostics" {
  let report = parse_report(
    (
      #|cat <<EOF
      #|“hi”
      #|EOF
      #|
    ),
  )
  let mut saw_unicode_quote = false
  for diagnostic in report.diagnostics {
    if diagnostic.message.contains("unicode quote") {
      saw_unicode_quote = true
    }
  }
  assert_true(saw_unicode_quote)
}

///|
test "here doc reports specific delimiter mismatches" {
  let trailing_space_report = parse_report(
    (
      #|cat <<EOF
      #|hi
      #|EOF 
      #|
    ),
  )
  let trailing_space_script = report_script(trailing_space_report)
  assert_true(report_has_code(trailing_space_report, 1118))
  match first_command(trailing_space_script).redirects[0].target {
    @parser.RedirectionTarget::HereDoc(doc) =>
      assert_eq(
        doc.body,
        (
          #|hi
          #|
        ),
      )
    _ => fail("expected recovered here doc with trailing-space delimiter")
  }

  let indentation = parse_report(
    (
      #|cat <<EOF
      #|hi
      #|  EOF
      #|
    ),
  )
  assert_true(report_has_code(indentation, 1039))

  let tabs_only = parse_report(
    (
      #|cat <<-EOF
      #|hi
      #|  EOF
      #|
    ),
  )
  assert_true(report_has_code(tabs_only, 1040))

  let trailer = parse_report(
    (
      #|cat <<EOF
      #|hi
      #|EOF # nope
      #|
    ),
  )
  assert_true(report_has_code(trailer, 1120))
}

///|
test "here doc delimiter quote removal respects shell quoting rules" {
  let script = parse_ok(
    (
      #|cat <<'\"foo'
      #|bar
      #|\"foo
      #|
    ),
  )
  let command = first_command(script)
  match command.redirects[0].target {
    @parser.RedirectionTarget::HereDoc(doc) => {
      assert_eq(doc.delimiter, "\\\"foo")
      assert_eq(
        doc.body,
        (
          #|bar
          #|
        ),
      )
      assert_true(doc.quoted)
    }
    _ => fail("expected here doc")
  }
}

///|
test "here doc delimiters do not emit ordinary word escape diagnostics" {
  let report = parse_report(
    (
      #|cat <<\EOF
      #|x
      #|EOF
      #|
    ),
  )
  assert_true(!report_has_code(report, 1001))
  match first_command(report_script(report)).redirects[0].target {
    @parser.RedirectionTarget::HereDoc(here_doc) => {
      assert_eq(here_doc.delimiter, "EOF")
      assert_true(here_doc.quoted)
    }
    _ => fail("expected here doc redirection")
  }
}

///|
test "simple command diagnostics cover shellcheck-style command validation" {
  let report = parse_report(
    (
      #|// Lol
      #|ElseIf foo
      #|trap 'if true; then echo hi' INT
      #|
    ),
  )
  let script = report_script(report)
  assert_eq(script.items.length(), 3)
  assert_true(report_has_code(report, 1127))
  assert_true(report_has_code(report, 1131))
  assert_true(report_has_code(report, 1046))
  assert_true(report_has_code(report, 1047))
}

///|
test "keyword-like command words emit shellcheck-style spacing and case diagnostics" {
  let report = parse_report(
    (
      #|If
      #|if[
      #|then#oops
      #|else!
      #|do:
      #|
    ),
  )
  let script = report_script(report)
  assert_eq(script.items.length(), 5)
  assert_true(report_has_code(report, 1081))
  assert_true(report_has_code(report, 1069))
  assert_true(report_has_code(report, 1099))
  assert_true(report_has_code(report, 1129))
  assert_true(report_has_code(report, 1130))
}

///|
test "eval and let commands emit shellcheck-style diagnostics" {
  let let_report = parse_report(
    (
      #|let 'a -lt 3'
      #|
    ),
  )
  let let_script = report_script(let_report)
  assert_true(report_has_code(let_report, 1106))
  match first_command(let_script).kind {
    @parser.CommandKind::Simple(simple) =>
      assert_eq(simple.words[0].source, "let")
    _ => fail("expected let simple command")
  }

  let eval_report = parse_report(
    (
      #|command eval ( foo )
      #|
    ),
  )
  assert_true(report_has_code(eval_report, 1098))
}

///|
test "source parse failure becomes a skip diagnostic" {
  let options = @parser.ParseOptions::new(
    false,
    false,
    false,
    true,
    Some("scripts/main.sh"),
    ["scripts/lib"],
    [
      (
        "scripts/lib/bad.sh",
        (
          #|echo "unterminated
          #|
        ),
      ),
    ],
  )
  let report = parse_report_with_options(
    (
      #|source bad.sh
      #|
    ),
    options,
  )
  let script = report_script(report)
  assert_true(report_has_code(report, 1094))
  match first_command(script).kind {
    @parser.CommandKind::Source(source) => {
      match source.resolved_path {
        Some(path) => assert_eq(path, "scripts/lib/bad.sh")
        None => fail("expected resolved bad source path")
      }
      assert_true(source.included is None)
    }
    _ => fail("expected source command")
  }
}

///|
test "source commands keep leading assignments and path-focused diagnostics" {
  let options = @parser.ParseOptions::new(
    false,
    false,
    false,
    true,
    Some("scripts/main.sh"),
    ["scripts/lib"],
    [],
  )
  let report = parse_report_with_options(
    (
      #|FOO=bar source missing.sh
      #|
    ),
    options,
  )
  let script = report_script(report)
  assert_eq(report.diagnostics.length(), 1)
  assert_eq(report.diagnostics[0].code, Some(1091))
  assert_eq(report.diagnostics[0].span.start.line, 1)
  assert_eq(report.diagnostics[0].span.start.column, 16)
  match first_command(script).kind {
    @parser.CommandKind::Source(source) => {
      assert_eq(source.assignments.length(), 1)
      assert_eq(source.assignments[0].name, "FOO")
      assert_eq(source.path.source, "missing.sh")
      assert_eq(source.args.length(), 0)
      assert_true(source.included is None)
    }
    _ => fail("expected source command")
  }
}

///|
test "here doc trailer and eof diagnostics align more closely with shellcheck" {
  let paren = parse_report(
    (
      #|cat <<EOF
      #|hi
      #|EOF)
      #|
    ),
  )
  assert_true(report_has_code(paren, 1119))
  assert_true(report_has_code(paren, 1009))
  assert_true(report_has_code(paren, 1073))
  assert_true(report_has_code(paren, 1072))

  let comment = parse_report(
    (
      #|cat <<EOF
      #|hi
      #|EOF # nope
      #|
    ),
  )
  assert_true(report_has_code(comment, 1120))
  assert_true(report_has_code(comment, 1009))
  assert_true(report_has_code(comment, 1073))
  assert_true(report_has_code(comment, 1072))

  let terminator = parse_report(
    (
      #|cat <<EOF
      #|hi
      #|EOF ; echo later
      #|
    ),
  )
  assert_true(report_has_code(terminator, 1121))
  assert_true(report_has_code(terminator, 1009))
  assert_true(report_has_code(terminator, 1073))
  assert_true(report_has_code(terminator, 1072))

  let spaced_trailer = parse_report(
    (
      #|cat <<EOF
      #|hi
      #|EOF   x
      #|
    ),
  )
  assert_true(report_has_code(spaced_trailer, 1122))
  assert_true(report_has_code(spaced_trailer, 1009))
  assert_true(report_has_code(spaced_trailer, 1073))
  assert_true(report_has_code(spaced_trailer, 1072))

  let glued = parse_report(
    (
      #|cat <<EOF
      #|helloEOFworld
      #|
    ),
  )
  assert_true(report_has_code(glued, 1041))
  assert_true(report_has_code(glued, 1042))

  let wrong_case = parse_report(
    (
      #|cat <<EOF
      #|eof
      #|
    ),
  )
  assert_true(report_has_code(wrong_case, 1043))
  assert_true(report_has_code(wrong_case, 1009))
  assert_true(report_has_code(wrong_case, 1073))
  assert_true(report_has_code(wrong_case, 1072))

  let missing = parse_report(
    (
      #|cat <<EOF
      #|hello
      #|
    ),
  )
  assert_true(report_has_code(missing, 1044))
  assert_true(report_has_code(missing, 1009))
  assert_true(report_has_code(missing, 1073))
  assert_true(report_has_code(missing, 1072))

  let opener_only = parse_report("cat << eof")
  assert_true(report_has_code(opener_only, 1044))
  assert_true(report_has_code(opener_only, 1073))
  assert_true(report_has_code(opener_only, 1072))
}

///|
test "for loops accept brace-group bodies" {
  let regular = parse_ok("for f in *; { rm \"$f\"; }")
  match first_command(regular).kind {
    @parser.CommandKind::ForIn(clause) => {
      assert_eq(clause.body.items.length(), 1)
      let (_, simple) = first_simple(clause.body)
      assert_eq(simple.words[0].source, "rm")
    }
    _ => fail("expected for-in loop")
  }

  let arithmetic = parse_ok("for ((;;)) { true; }")
  match first_command(arithmetic).kind {
    @parser.CommandKind::ForArithmetic(clause) =>
      assert_eq(clause.body.items.length(), 1)
    _ => fail("expected arithmetic for loop")
  }
}

///|
test "for loops warn about dollar-prefixed iterator names" {
  let report = parse_report(
    (
      #|for $a in *; do echo "$a"; done
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report_has_code(report, 1086))
  match first_command(script).kind {
    @parser.CommandKind::ForIn(clause) => assert_eq(clause.name, "a")
    _ => fail("expected recoverable for-in loop")
  }
}

///|
test "loop header separators align more closely with shellcheck" {
  let for_report = parse_report(
    (
      #|for i in a b do true; done
      #|
    ),
  )
  assert_true(report_has_code(for_report, 1063))
  match first_command(report_script(for_report)).kind {
    @parser.CommandKind::ForIn(_) => ()
    _ => fail("expected recoverable for loop")
  }

  let select_report = parse_report(
    (
      #|select i in a b do echo "$i"; done
      #|
    ),
  )
  assert_true(report_has_code(select_report, 1063))
  match first_command(report_script(select_report)).kind {
    @parser.CommandKind::Select(_) => ()
    _ => fail("expected recoverable select loop")
  }

  let missing_separator = parse_report(
    (
      #|select i do echo "$i"; done
      #|
    ),
  )
  assert_true(missing_separator.script is None)

  let invalid_values = parse_report(
    (
      #|select i (a b)
      #|
    ),
  )
  assert_true(invalid_values.script is None)
}

///|
test "orphan shellcheck annotations before branch keywords become diagnostics" {
  let report = parse_report(
    (
      #|if true; then echo ok
      #|# shellcheck disable=SC2086
      #|elif false; then :; fi
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report.diagnostics.length() >= 1)
  assert_eq(report.diagnostics[0].code, Some(1123))
  match first_command(script).kind {
    @parser.CommandKind::If(clause) => {
      assert_eq(clause.arms.length(), 2)
      assert_eq(clause.arms[0].body.items.length(), 1)
      assert_eq(clause.arms[1].body.items.length(), 1)
    }
    _ => fail("expected if clause")
  }
}

///|
test "else if on the same line emits a shellcheck-style diagnostic" {
  let report = parse_report(
    (
      #|if false; then :; else if true; then echo hi; fi; fi
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report_has_code(report, 1075))
  match first_command(script).kind {
    @parser.CommandKind::If(clause) => assert_true(clause.else_body is Some(_))
    _ => fail("expected if clause with recoverable else-if diagnostic")
  }
}

///|
test "if clauses recover missing keywords and empty branches" {
  let report = parse_report(
    (
      #|if true; fi
      #|if true; then; else; fi
      #|if true; then echo hi
      #|
    ),
  )
  let script = report_script(report)
  assert_eq(script.items.length(), 3)
  assert_true(report_has_code(report, 1049))
  assert_true(report_has_code(report, 1050))
  assert_true(report_has_code(report, 1048))
  assert_true(report_has_code(report, 1051))
  assert_true(report_has_code(report, 1053))
  assert_true(report_has_code(report, 1046))
  assert_true(report_has_code(report, 1047))

  match first_command(script).kind {
    @parser.CommandKind::If(clause) =>
      assert_eq(clause.arms[0].body.items.length(), 0)
    _ => fail("expected first recoverable if clause")
  }
  match script.items[1].and_or.head.segments[0].command.kind {
    @parser.CommandKind::If(clause) => assert_true(clause.else_body is Some(_))
    _ => fail("expected second recoverable if clause")
  }
  match script.items[2].and_or.head.segments[0].command.kind {
    @parser.CommandKind::If(clause) =>
      assert_eq(clause.arms[0].body.items.length(), 1)
    _ => fail("expected third recoverable if clause")
  }
}

///|
test "loop do groups recover missing keywords and direct semicolons" {
  let report = parse_report(
    (
      #|while true; done
      #|while true; do; done
      #|while true; do echo hi
      #|
    ),
  )
  let script = report_script(report)
  assert_eq(script.items.length(), 3)
  assert_true(report_has_code(report, 1057))
  assert_true(report_has_code(report, 1058))
  assert_true(report_has_code(report, 1060))
  assert_true(report_has_code(report, 1059))
  assert_true(report_has_code(report, 1061))
  assert_true(report_has_code(report, 1062))

  match first_command(script).kind {
    @parser.CommandKind::While(clause) =>
      assert_eq(clause.body.items.length(), 0)
    _ => fail("expected first recoverable while clause")
  }
  match script.items[2].and_or.head.segments[0].command.kind {
    @parser.CommandKind::While(clause) =>
      assert_eq(clause.body.items.length(), 1)
    _ => fail("expected third recoverable while clause")
  }
}

///|
test "brace groups recover missing closing braces at eof" {
  let report = parse_report(
    (
      #|{ echo hi
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report_has_code(report, 1056))
  match first_command(script).kind {
    @parser.CommandKind::BraceGroup(body) => assert_eq(body.items.length(), 1)
    _ => fail("expected recoverable brace group")
  }
}

///|
test "array indices follow associative declarations like shellcheck" {
  let regular = parse_ok(
    (
      #|arr[i + 1]=x
      #|echo ${arr[$j + 2]}
      #|(( arr[k + 3]++ ))
      #|
    ),
  )
  let (_, regular_assignment) = simple_at(regular, 0)
  assert_eq(
    arithmetic_raw(
      arithmetic_index_expr(regular_assignment.assignments[0].indexes[0]),
    ),
    "i + 1",
  )

  let (_, regular_echo) = simple_at(regular, 1)
  match braced_parameter(regular_echo.words[1].parts[0]).index {
    Some(index) =>
      assert_eq(arithmetic_raw(arithmetic_index_expr(index)), "$j + 2")
    None => fail("expected regular array parameter expansion index")
  }

  match command_at(regular, 2).kind {
    @parser.CommandKind::Arithmetic(command) =>
      assert_eq(
        arithmetic_raw(
          arithmetic_index_expr(arithmetic_variable_index(command.expr, "arr")),
        ),
        "k + 3",
      )
    _ => fail("expected regular arithmetic command")
  }

  let associative = parse_ok(
    (
      #|declare -A map=([foo]=bar)
      #|map[$key + 1]=x
      #|echo ${map[$item + 2]}
      #|(( map[$expr + 3]++ ))
      #|
    ),
  )
  let (_, associative_assignment) = simple_at(associative, 1)
  assert_true(
    associative_assignment.assignments[0].indexes[0].arithmetic is None,
  )
  assert_eq(
    index_raw(associative_assignment.assignments[0].indexes[0]),
    "$key + 1",
  )

  let (_, associative_echo) = simple_at(associative, 2)
  match braced_parameter(associative_echo.words[1].parts[0]).index {
    Some(index) => {
      assert_true(index.arithmetic is None)
      assert_eq(index_raw(index), "$item + 2")
    }
    None => fail("expected associative array parameter expansion index")
  }

  match command_at(associative, 3).kind {
    @parser.CommandKind::Arithmetic(command) => {
      let index = arithmetic_variable_index(command.expr, "map")
      assert_true(index.arithmetic is None)
      assert_eq(index_raw(index), "$expr + 3")
    }
    _ => fail("expected associative arithmetic command")
  }
}

///|
test "special diagnostics cover unicode input carriage returns and process substitution redirect typos" {
  let unicode_quote = parse_report("echo “hi”")
  assert_true(unicode_quote.diagnostics.length() >= 2)
  assert_true(unicode_quote.diagnostics[0].message.contains("unicode quote"))

  let unicode_space = parse_report("echo hi")
  assert_true(unicode_space.diagnostics.length() >= 1)
  assert_true(
    unicode_space.diagnostics[0].message.contains("non-breaking space"),
  )

  let carriage_return = parse_report(
    (
      $|echo hi\{'\r'}
      $|echo bye\{'\r'}
      $|
    ),
  )
  assert_true(carriage_return.diagnostics.length() >= 2)
  assert_true(
    carriage_return.diagnostics[0].message.contains("carriage return"),
  )

  let procsub = parse_report("while true; do foo; done <(echo hi)")
  let procsub_script = report_script(procsub)
  assert_true(report_has_code(procsub, 1142))
  match first_command(procsub_script).kind {
    @parser.CommandKind::While(clause) =>
      assert_eq(clause.body.items.length(), 1)
    _ => fail("expected while clause with process-substitution diagnostic")
  }
}

///|
test "line continuations keep parse errors on the right line" {
  let err = parse_error(
    (
      #|echo foo \
      #|"unterminated
    ),
  )
  assert_true(err.has_prefix("2:"))
}

///|
test "comment backslashes after line continuations emit shellcheck-style diagnostics" {
  let report = parse_report(
    (
      #|echo foo \
      #|# comment \
      #|echo bar
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report_has_code_on_line(report, 1143, 2))
  assert_eq(script.items.length(), 2)
}

///|
test "unterminated double quote reports readable error" {
  let err = parse_error("echo \"unterminated")
  assert_true(
    err.contains(
      "Couldn't parse this double quoted string. Fix to allow more checks.",
    ),
  )
}

///|
test "backquoted substitutions unescape shell-special backslashes" {
  let script = parse_ok(
    (
      #|echo `printf \$HOME`
      #|
    ),
  )
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::BackQuoted(inner) => {
      let (_, nested) = first_simple(inner)
      assert_eq(nested.words.length(), 2)
      assert_eq(nested.words[0].source, "printf")
      assert_eq(nested.words[1].source, "$HOME")
      match nested.words[1].parts[0] {
        @parser.WordPart::Parameter(name) => assert_eq(name, "HOME")
        _ => fail("expected parameter expansion inside backticks")
      }
    }
    _ => fail("expected backquoted substitution")
  }
}

///|
test "backquoted substitutions propagate nested diagnostics to outer report" {
  let report = parse_report(
    (
      #|echo `ElseIf foo`
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report_has_code_on_line(report, 1131, 1))
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::BackQuoted(inner) => {
      let (_, nested) = first_simple(inner)
      assert_eq(nested.words[0].source, "ElseIf")
      assert_eq(nested.words[1].source, "foo")
    }
    _ => fail("expected backquoted substitution")
  }
}

///|
test "backquoted substitutions inherit parse options for nested source resolution" {
  let options = @parser.ParseOptions::new(
    false,
    false,
    false,
    true,
    Some("scripts/main.sh"),
    ["scripts/lib"],
    [
      (
        "scripts/lib/helpers.sh",
        (
          #|echo hi
          #|
        ),
      ),
    ],
  )
  let report = parse_report_with_options(
    (
      #|echo `source helpers.sh`
      #|
    ),
    options,
  )
  let script = report_script(report)
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::BackQuoted(inner) =>
      match first_command(inner).kind {
        @parser.CommandKind::Source(source) => {
          match source.resolved_path {
            Some(path) => assert_eq(path, "scripts/lib/helpers.sh")
            None => fail("expected nested source path to resolve")
          }
          assert_true(source.included is Some(_))
        }
        _ => fail("expected nested source command")
      }
    _ => fail("expected backquoted substitution")
  }
}

///|
test "other nested script substitutions inherit parse options for source resolution" {
  let options = @parser.ParseOptions::new(
    false,
    false,
    false,
    true,
    Some("scripts/main.sh"),
    ["scripts/lib"],
    [
      (
        "scripts/lib/helpers.sh",
        (
          #|echo hi
          #|
        ),
      ),
    ],
  )
  let report = parse_report_with_options(
    (
      #|echo $(source helpers.sh) <(source helpers.sh) ${ source helpers.sh; }
      #|
    ),
    options,
  )
  let script = report_script(report)
  let (_, simple) = first_simple(script)

  match simple.words[1].parts[0] {
    @parser.WordPart::CommandSubstitution(inner) =>
      match first_command(inner).kind {
        @parser.CommandKind::Source(source) => {
          match source.resolved_path {
            Some(path) => assert_eq(path, "scripts/lib/helpers.sh")
            None => fail("expected command substitution source to resolve")
          }
          assert_true(source.included is Some(_))
        }
        _ => fail("expected source command in command substitution")
      }
    _ => fail("expected command substitution")
  }

  match simple.words[2].parts[0] {
    @parser.WordPart::ProcessSubstitution(kind, inner) => {
      assert_eq(kind, "<")
      match first_command(inner).kind {
        @parser.CommandKind::Source(source) => {
          match source.resolved_path {
            Some(path) => assert_eq(path, "scripts/lib/helpers.sh")
            None => fail("expected process substitution source to resolve")
          }
          assert_true(source.included is Some(_))
        }
        _ => fail("expected source command in process substitution")
      }
    }
    _ => fail("expected process substitution")
  }

  match simple.words[3].parts[0] {
    @parser.WordPart::BraceCommandSubstitution(false, inner) =>
      match first_command(inner).kind {
        @parser.CommandKind::Source(source) => {
          match source.resolved_path {
            Some(path) => assert_eq(path, "scripts/lib/helpers.sh")
            None =>
              fail("expected brace command substitution source to resolve")
          }
          assert_true(source.included is Some(_))
        }
        _ => fail("expected source command in brace command substitution")
      }
    _ => fail("expected brace command substitution")
  }
}

///|
test "acute-accent command substitutions emit shellcheck-style diagnostics" {
  let report = parse_report(
    (
      #|echo ´printf x´
      #|
    ),
  )
  let script = report_script(report)
  assert_true(report_has_code(report, 1077))
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::BackQuoted(inner) => {
      let (_, nested) = first_simple(inner)
      assert_eq(nested.words[0].source, "printf")
      assert_eq(nested.words[1].source, "x")
    }
    _ => fail("expected acute-accent command substitution to recover")
  }
}

///|
test "double-quoted backquoted substitutions unescape escaped quotes" {
  let script = parse_ok(
    (
      #|echo "`printf \"x\"`"
      #|
    ),
  )
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::DoubleQuoted(parts) =>
      match parts[0] {
        @parser.WordPart::BackQuoted(inner) => {
          let (_, nested) = first_simple(inner)
          assert_eq(nested.words[0].source, "printf")
          assert_eq(nested.words[1].source, "\"x\"")
        }
        _ => fail("expected backquoted substitution inside double quotes")
      }
    _ => fail("expected double-quoted word")
  }
}
