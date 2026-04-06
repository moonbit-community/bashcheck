///|
fn[A] query_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn parse_query_ok(source : String) -> @parser.Script {
  match @parser.parse_script(source) {
    Ok(script) => script
    Err(error) => query_fail(error.to_string())
  }
}

///|
fn parse_query_with_options(
  source : String,
  options : @parser.ParseOptions,
) -> @parser.Script {
  let report = @parser.parse_script_with_options(source, options)
  match report.script {
    Some(script) => script
    None => query_fail("expected script")
  }
}

///|
fn parse_query_report_ok(source : String) -> @parser.Script {
  let report = @parser.parse_script_report(source)
  match report.script {
    Some(script) => script
    None => query_fail("expected script")
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
    @parser.CommandKind::Simple(simple) => simple
    _ => query_fail("expected simple command")
  }
}

///|
fn source_of(command : @parser.Command) -> @parser.SourceCommand {
  match command.kind {
    @parser.CommandKind::Source(source) => source
    _ => query_fail("expected source command")
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
  assert_eq(@semantics.command_name(wrapped_command), Some("command"))
  assert_eq(@semantics.effective_command_name(wrapped_command), Some("printf"))

  let words = @semantics.command_words(wrapped_command)
  assert_eq(words.length(), 5)
  assert_eq(words[0].source, "command")
  assert_eq(words[1].source, "--")
  assert_eq(words[2].source, "printf")
  assert_eq(words[3].source, "'%s'")
  assert_eq(words[4].source, "\"$x\"")

  let args = @semantics.command_arguments(wrapped_command)
  assert_eq(args.length(), 4)
  assert_eq(args[0].source, "--")
  assert_eq(args[1].source, "printf")
  assert_eq(args[2].source, "'%s'")
  assert_eq(args[3].source, "\"$x\"")

  let effective_words = @semantics.effective_command_words(wrapped_command)
  assert_eq(effective_words.length(), 3)
  assert_eq(effective_words[0].source, "printf")
  assert_eq(effective_words[1].source, "'%s'")
  assert_eq(effective_words[2].source, "\"$x\"")

  let effective_args = @semantics.effective_command_arguments(wrapped_command)
  assert_eq(effective_args.length(), 2)
  assert_eq(effective_args[0].source, "'%s'")
  assert_eq(effective_args[1].source, "\"$x\"")

  assert_eq(@semantics.oversimplify_command(wrapped_command), [
    "command", "--", "printf", "%s", "${VAR}",
  ])
  assert_eq(@semantics.all_redirections(wrapped_command).length(), 1)

  let introspection = parse_query_ok(
    (
      #|command -v printf
      #|
    ),
  )
  let introspection_command = first_command(introspection)
  assert_eq(@semantics.command_name(introspection_command), Some("command"))
  assert_eq(
    @semantics.effective_command_name(introspection_command),
    Some("command"),
  )
  assert_eq(
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
  assert_eq(
    @semantics.command_name(quoted_introspection_command),
    Some("command"),
  )
  assert_eq(
    @semantics.effective_command_name(quoted_introspection_command),
    Some("command"),
  )
  assert_eq(
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
  assert_eq(
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
  assert_eq(
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
  assert_eq(@semantics.command_name(quoted_exec_command), Some("exec"))
  assert_eq(@semantics.effective_command_name(quoted_exec_command), Some("sh"))
  let quoted_exec_words = @semantics.effective_command_words(
    quoted_exec_command,
  )
  assert_eq(quoted_exec_words.length(), 3)
  assert_eq(quoted_exec_words[0].source, "sh")
  assert_eq(quoted_exec_words[1].source, "-c")
  assert_eq(quoted_exec_words[2].source, "true")

  let sourced = parse_query_ok(
    (
      #|. lib.sh "$x"
      #|
    ),
  )
  let source_command = first_command(sourced)
  assert_eq(@semantics.command_name(source_command), Some("."))
  assert_eq(@semantics.effective_command_name(source_command), Some("."))
  let source_words = @semantics.command_words(source_command)
  assert_eq(source_words.length(), 2)
  assert_eq(source_words[0].source, "lib.sh")
  assert_eq(source_words[1].source, "\"$x\"")
  let source_args = @semantics.command_arguments(source_command)
  assert_eq(source_args.length(), 2)
  assert_eq(source_args[0].source, "lib.sh")
  assert_eq(source_args[1].source, "\"$x\"")
  assert_eq(@semantics.oversimplify_command(source_command), [
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
  assert_eq(@semantics.command_name(source_keyword), Some("source"))
  assert_eq(@semantics.effective_command_name(source_keyword), Some("source"))
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
  assert_eq(@semantics.command_name(direct), Some("/usr/bin/find"))
  assert_eq(@semantics.command_basename(direct), Some("find"))
  assert_true(@semantics.builtin_command_name(direct) is None)

  let builtin = first_command(
    parse_query_ok(
      (
        #|builtin read foo
        #|
      ),
    ),
  )
  assert_eq(@semantics.command_name(builtin), Some("builtin"))
  assert_eq(@semantics.command_basename(builtin), Some("builtin"))
  assert_eq(@semantics.builtin_command_name(builtin), Some("read"))

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

  assert_eq(@semantics.literal_text(simple.words[1]), Some("foo"))
  assert_eq(@semantics.leading_unquoted_text(simple.words[2]), Some("-n"))
  assert_true(@semantics.is_unquoted_flag(simple.words[2]))
  assert_true(!@semantics.is_unquoted_flag(simple.words[3]))
  assert_true(@semantics.is_constant_word(simple.words[1]))
  assert_true(!@semantics.is_constant_word(simple.words[6]))
  assert_true(@semantics.is_glob_word(simple.words[4]))
  assert_true(!@semantics.is_glob_word(simple.words[5]))
  assert_true(@semantics.is_glob_word(simple.words[7]))
  assert_eq(
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
  assert_eq(@semantics.oversimplify_command(command), [
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

  assert_eq(@semantics.literal_text(simple.words[1]), Some("?"))
  assert_eq(@semantics.literal_text(simple.words[2]), Some("1"))
  assert_eq(@semantics.literal_text(simple.words[3]), Some("10"))
  assert_eq(@semantics.literal_text(simple.words[4]), Some("?"))
  assert_eq(@semantics.literal_text(simple.words[5]), Some("10"))
}

///|
test "walkers stay within the current script and can inspect includes separately" {
  let options = @parser.ParseOptions::new(
    true,
    false,
    false,
    true,
    Some("/tmp/main.sh"),
    [],
    [
      (
        "lib.sh",
        (
          #|echo "$(printf %s inner)" >out
          #|
        ),
      ),
    ],
  )
  let script = parse_query_with_options(
    (
      #|. lib.sh
      #|
    ),
    options,
  )
  let root_item = first_item(script)
  let root_command = first_command(script)
  let source = source_of(root_command)

  let mut script_count = 0
  @semantics.walk_script(script, fn(_) { script_count += 1 })
  assert_eq(script_count, 1)

  let mut item_count = 0
  @semantics.walk_list_item(root_item, fn(_) { item_count += 1 })
  assert_eq(item_count, 1)

  let mut root_command_count = 0
  @semantics.walk_command(root_command, fn(_) { root_command_count += 1 })
  assert_eq(root_command_count, 1)

  let root_redirects = @semantics.all_redirections(root_command)
  assert_eq(root_redirects.length(), 0)

  let included = match source.included {
    Some(script) => script
    None => query_fail("expected included script")
  }
  let mut included_script_count = 0
  @semantics.walk_script(included, fn(_) { included_script_count += 1 })
  assert_eq(included_script_count, 2)

  let echo_command = first_command(included)
  let names : Array[String] = []
  @semantics.walk_command(echo_command, fn(command) {
    match @semantics.command_name(command) {
      Some(name) => names.push(name)
      None => ()
    }
  })
  assert_eq(names, ["echo", "printf"])

  let redirects = @semantics.all_redirections(echo_command)
  assert_eq(redirects.length(), 1)

  let echo_simple = simple_of(echo_command)
  let nested_word = echo_simple.words[1]

  let mut word_count = 0
  @semantics.walk_word(nested_word, fn(_) { word_count += 1 })
  assert_eq(word_count, 4)

  let mut part_count = 0
  @semantics.walk_word_part(nested_word.parts[0], fn(_) { part_count += 1 })
  assert_eq(part_count, 5)

  let mut redirection_count = 0
  @semantics.walk_redirection(redirects[0], fn(_) { redirection_count += 1 })
  assert_eq(redirection_count, 1)
}

///|
fn first_if_body_item(script : @parser.Script) -> @parser.ListItem {
  match first_command(script).kind {
    @parser.CommandKind::If(clause) =>
      match clause.arms.get(0) {
        Some(arm) => first_item(arm.body)
        None => query_fail("expected if arm")
      }
    _ => query_fail("expected if command")
  }
}

///|
test "directive extraction stays local to the current script or list item" {
  let script = parse_query_ok(
    (
      #|# shellcheck disable=SC1000 enable=root-check
      #|if true; then
      #|# shellcheck disable=SC2000 enable=inner-check
      #|echo hi
      #|fi
      #|
    ),
  )
  assert_eq(@semantics.extract_disable_directives(script), ["SC1000"])
  assert_eq(@semantics.extract_enable_directives(script), ["root-check"])

  let inner_item = first_if_body_item(script)
  assert_eq(@semantics.list_item_disable_directives(inner_item), ["SC2000"])
  assert_eq(@semantics.list_item_enable_directives(inner_item), ["inner-check"])
}
