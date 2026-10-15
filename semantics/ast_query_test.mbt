///|
fn[A] query_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn parse_query_ok(source : String) -> @parser.Script {
  match test_parse_script(source) {
    Ok(script) => script
    Err(error) => query_fail(Show::to_string(error))
  }
}

///|
fn parse_query_report_ok(source : String) -> @parser.Script {
  let report = @parser.parse_script_report(source)
  if report.script is Some(script) {
    script
  } else {
    query_fail("expected script")
  }
}

///|
fn first_item(script : @parser.Script) -> @parser.ListItem {
  guard script.items.length() > 0 else { query_fail("expected list item") }
  script.items[0]
}

///|
fn first_command(script : @parser.Script) -> @parser.Command {
  let item = first_item(script)
  item.and_or.head.segments[0].command
}

///|
fn simple_of(command : @parser.Command) -> @parser.SimpleCommand {
  match command.kind {
    Simple(simple) => simple
    _ => query_fail("expected simple command")
  }
}

///|
test "command queries resolve wrappers and source commands" {
  let wrapped = parse_query_ok(
    (
      #|command -- printf '%s' "$x" >out
      #|
    ),
  )
  let wrapped_command = first_command(wrapped)
  @test.assert_eq(@semantics.command_name(wrapped_command), Some("command"))
  @test.assert_eq(
    @semantics.effective_command_name(wrapped_command),
    Some("printf"),
  )

  let words = @semantics.command_words(wrapped_command)
  @test.assert_eq(words.length(), 5)
  @test.assert_eq(words[0].source, "command")
  @test.assert_eq(words[1].source, "--")
  @test.assert_eq(words[2].source, "printf")
  @test.assert_eq(words[3].source, "'%s'")
  @test.assert_eq(words[4].source, "\"$x\"")

  let args = @semantics.command_arguments(wrapped_command)
  @test.assert_eq(args.length(), 4)
  @test.assert_eq(args[0].source, "--")
  @test.assert_eq(args[1].source, "printf")
  @test.assert_eq(args[2].source, "'%s'")
  @test.assert_eq(args[3].source, "\"$x\"")

  let effective_words = @semantics.effective_command_words(wrapped_command)
  @test.assert_eq(effective_words.length(), 3)
  @test.assert_eq(effective_words[0].source, "printf")
  @test.assert_eq(effective_words[1].source, "'%s'")
  @test.assert_eq(effective_words[2].source, "\"$x\"")

  let effective_args = @semantics.effective_command_arguments(wrapped_command)
  @test.assert_eq(effective_args.length(), 2)
  @test.assert_eq(effective_args[0].source, "'%s'")
  @test.assert_eq(effective_args[1].source, "\"$x\"")

  @test.assert_eq(@semantics.oversimplify_command(wrapped_command), [
    "command", "--", "printf", "%s", "${VAR}",
  ])

  let introspection = parse_query_ok(
    (
      #|command -v printf
      #|
    ),
  )
  let introspection_command = first_command(introspection)
  @test.assert_eq(
    @semantics.command_name(introspection_command),
    Some("command"),
  )
  @test.assert_eq(
    @semantics.effective_command_name(introspection_command),
    Some("command"),
  )
  @test.assert_eq(
    @semantics.effective_command_words(introspection_command).length(),
    3,
  )

  let quoted_introspection = parse_query_ok(
    (
      #|command "-v" printf
      #|
    ),
  )
  let quoted_introspection_command = first_command(quoted_introspection)
  @test.assert_eq(
    @semantics.command_name(quoted_introspection_command),
    Some("command"),
  )
  @test.assert_eq(
    @semantics.effective_command_name(quoted_introspection_command),
    Some("command"),
  )
  @test.assert_eq(
    @semantics.effective_command_words(quoted_introspection_command).length(),
    3,
  )

  let quoted_end_of_options = parse_query_ok(
    (
      #|command "--" printf '%s'
      #|
    ),
  )
  let quoted_end_of_options_command = first_command(quoted_end_of_options)
  @test.assert_eq(
    @semantics.effective_command_name(quoted_end_of_options_command),
    Some("command"),
  )

  let quoted_pass_through = parse_query_ok(
    (
      #|command '-p' printf
      #|
    ),
  )
  let quoted_pass_through_command = first_command(quoted_pass_through)
  @test.assert_eq(
    @semantics.effective_command_name(quoted_pass_through_command),
    Some("command"),
  )

  let quoted_exec = parse_query_ok(
    (
      #|exec "-c" sh -c true
      #|
    ),
  )
  let quoted_exec_command = first_command(quoted_exec)
  @test.assert_eq(@semantics.command_name(quoted_exec_command), Some("exec"))
  @test.assert_eq(
    @semantics.effective_command_name(quoted_exec_command),
    Some("sh"),
  )
  let quoted_exec_words = @semantics.effective_command_words(
    quoted_exec_command,
  )
  @test.assert_eq(quoted_exec_words.length(), 3)
  @test.assert_eq(quoted_exec_words[0].source, "sh")
  @test.assert_eq(quoted_exec_words[1].source, "-c")
  @test.assert_eq(quoted_exec_words[2].source, "true")

  let sourced = parse_query_ok(
    (
      #|. lib.sh "$x"
      #|
    ),
  )
  let source_command = first_command(sourced)
  @test.assert_eq(@semantics.command_name(source_command), Some("."))
  @test.assert_eq(@semantics.effective_command_name(source_command), Some("."))
  let source_words = @semantics.command_words(source_command)
  @test.assert_eq(source_words.length(), 2)
  @test.assert_eq(source_words[0].source, "lib.sh")
  @test.assert_eq(source_words[1].source, "\"$x\"")
  let source_args = @semantics.command_arguments(source_command)
  @test.assert_eq(source_args.length(), 2)
  @test.assert_eq(source_args[0].source, "lib.sh")
  @test.assert_eq(source_args[1].source, "\"$x\"")
  @test.assert_eq(@semantics.oversimplify_command(source_command), [
    ".", "lib.sh", "${VAR}",
  ])

  let source_keyword = first_command(
    parse_query_ok(
      (
        #|source lib.sh
        #|
      ),
    ),
  )
  @test.assert_eq(@semantics.command_name(source_keyword), Some("source"))
  @test.assert_eq(
    @semantics.effective_command_name(source_keyword),
    Some("source"),
  )
}

///|
test "command basename queries keep direct and builtin names distinct" {
  let direct = first_command(
    parse_query_ok(
      (
        #|/usr/bin/find . -type f
        #|
      ),
    ),
  )
  @test.assert_eq(@semantics.command_name(direct), Some("/usr/bin/find"))
  @test.assert_eq(@semantics.command_basename(direct), Some("find"))
  assert_true(@semantics.builtin_command_name(direct) is None)

  let builtin = first_command(
    parse_query_ok(
      (
        #|builtin read foo
        #|
      ),
    ),
  )
  @test.assert_eq(@semantics.command_name(builtin), Some("builtin"))
  @test.assert_eq(@semantics.command_basename(builtin), Some("builtin"))
  @test.assert_eq(@semantics.builtin_command_name(builtin), Some("read"))

  let wrapped = first_command(
    parse_query_ok(
      (
        #|command read foo
        #|
      ),
    ),
  )
  assert_true(@semantics.builtin_command_name(wrapped) is None)
}

///|
test "word queries detect literals flags constants globs and dollar strings" {
  let script = parse_query_ok(
    (
      #|echo foo -n$bar "-q" abc*.sh "*.sh" ~user foo[x${bar}y] $'a\n'
      #|
    ),
  )
  let simple = simple_of(first_command(script))

  @test.assert_eq(@semantics.literal_text(simple.words[1]), Some("foo"))
  @test.assert_eq(@semantics.leading_unquoted_text(simple.words[2]), Some("-n"))
  assert_true(@semantics.is_unquoted_flag(simple.words[2]))
  assert_true(!@semantics.is_unquoted_flag(simple.words[3]))
  assert_true(@semantics.is_constant_word(simple.words[1]))
  assert_true(!@semantics.is_constant_word(simple.words[6]))
  assert_true(@semantics.is_glob_word(simple.words[4]))
  assert_true(!@semantics.is_glob_word(simple.words[5]))
  assert_true(@semantics.is_glob_word(simple.words[7]))
  @test.assert_eq(
    @semantics.literal_text(simple.words[8]),
    Some(
      (
        #|a
        #|
      ),
    ),
  )
}

///|
test "special parameters stay visible in oversimplified commands" {
  let script = parse_query_ok(
    (
      #|echo "$@" $? $1 "$USER"
      #|
    ),
  )
  let command = first_command(script)
  @test.assert_eq(@semantics.oversimplify_command(command), [
    "echo", "@", "?", "1", "${VAR}",
  ])
}

///|
test "literal text preserves special parameters and positional recovery" {
  let script = parse_query_report_ok(
    (
      #|echo $? $1 $10 "$?" "$10"
      #|
    ),
  )
  let simple = simple_of(first_command(script))

  @test.assert_eq(@semantics.literal_text(simple.words[1]), Some("?"))
  @test.assert_eq(@semantics.literal_text(simple.words[2]), Some("1"))
  @test.assert_eq(@semantics.literal_text(simple.words[3]), Some("10"))
  @test.assert_eq(@semantics.literal_text(simple.words[4]), Some("?"))
  @test.assert_eq(@semantics.literal_text(simple.words[5]), Some("10"))
}
