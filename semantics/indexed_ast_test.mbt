///|
fn[A] fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn parse_ok(source : String) -> @parser.Script {
  match @parser.parse_script(source) {
    Ok(script) => script
    Err(error) => fail(error.to_string())
  }
}

///|
fn parse_with_options(
  source : String,
  options : @parser.ParseOptions,
) -> @parser.Script {
  let report = @parser.parse_script_with_options(source, options)
  match report.script {
    Some(script) => script
    None => fail("expected script")
  }
}

///|
fn all_node_ids(indexed : @semantics.IndexedScript) -> Array[@semantics.NodeId] {
  let ids : Array[@semantics.NodeId] = [@semantics.root_id(indexed)]
  for id in @semantics.find_descendants(indexed, @semantics.root_id(indexed)) {
    ids.push(id)
  }
  ids
}

///|
fn find_first_command(indexed : @semantics.IndexedScript) -> @semantics.NodeId {
  for id in all_node_ids(indexed) {
    match @semantics.node_ref_of(indexed, id) {
      Some(@semantics.NodeRef::Command(_)) => return id
      _ => ()
    }
  }
  fail("missing command node")
}

///|
fn find_first_word(indexed : @semantics.IndexedScript) -> @semantics.NodeId {
  for id in all_node_ids(indexed) {
    match @semantics.node_ref_of(indexed, id) {
      Some(@semantics.NodeRef::Word(_)) => return id
      _ => ()
    }
  }
  fail("missing word node")
}

///|
fn find_parameter_part(indexed : @semantics.IndexedScript) -> @semantics.NodeId {
  for id in all_node_ids(indexed) {
    match @semantics.node_ref_of(indexed, id) {
      Some(@semantics.NodeRef::WordPart(@parser.WordPart::Parameter(name))) =>
        if name == "USER" {
          return id
        }
      _ => ()
    }
  }
  fail("missing parameter word part")
}

///|
fn find_source_command(indexed : @semantics.IndexedScript) -> @semantics.NodeId {
  for id in all_node_ids(indexed) {
    match @semantics.node_ref_of(indexed, id) {
      Some(@semantics.NodeRef::SourceCommand(_)) => return id
      _ => ()
    }
  }
  fail("missing source command")
}

///|
fn find_word_with_source(
  indexed : @semantics.IndexedScript,
  source : String,
) -> @semantics.NodeId {
  for id in all_node_ids(indexed) {
    match @semantics.node_ref_of(indexed, id) {
      Some(@semantics.NodeRef::Word(word)) =>
        if word.source == source {
          return id
        }
      _ => ()
    }
  }
  fail("missing word node")
}

///|
fn first_indexed_command(script : @parser.Script) -> @parser.Command {
  script.items[0].and_or.head.segments[0].command
}

///|
test "indexed ast tracks parent chains and nearest word/command" {
  let script = parse_ok(
    (
      #|foo() { echo "hi $USER" >out; }
      #|
    ),
  )
  let indexed = @semantics.build_index(script)
  let root = @semantics.root_id(indexed)
  assert_eq(root.to_int(), 0)
  assert_true(@semantics.parent_of(indexed, root) is None)
  assert_true(@semantics.node_count(indexed) > 0)

  let parameter = find_parameter_part(indexed)
  let ancestors = @semantics.find_ancestors(indexed, parameter)
  assert_true(ancestors.length() > 0)

  let word = match @semantics.word_of(indexed, parameter) {
    Some(word) => word
    None => fail("expected containing word")
  }
  assert_eq(word.source, "\"hi $USER\"")

  let command = match @semantics.command_of(indexed, parameter) {
    Some(command) => command
    None => fail("expected containing command")
  }
  match command.kind {
    @parser.CommandKind::Simple(simple) => {
      assert_eq(simple.words.length(), 2)
      assert_eq(simple.words[0].source, "echo")
    }
    _ => fail("expected simple command")
  }

  let descendants = @semantics.find_descendants(indexed, root)
  assert_eq(descendants.length() + 1, @semantics.node_count(indexed))
}

///|
test "indexed ast keeps sourced scripts out of the lexical tree" {
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
          #|echo inside
          #|
        ),
      ),
    ],
  )
  let script = parse_with_options(
    (
      #|. lib.sh
      #|
    ),
    options,
  )
  let indexed = @semantics.build_index(script)
  let source_command = find_source_command(indexed)

  let mut saw_included_descendant = false
  for child in @semantics.find_descendants(indexed, source_command) {
    match @semantics.node_ref_of(indexed, child) {
      Some(@semantics.NodeRef::Script(_)) => saw_included_descendant = true
      Some(@semantics.NodeRef::Command(command)) =>
        match command.kind {
          @parser.CommandKind::Simple(simple) =>
            if simple.words.length() > 0 && simple.words[0].source == "echo" {
              saw_included_descendant = true
            }
          _ => ()
        }
      _ => ()
    }
  }
  assert_true(!saw_included_descendant)

  let source = match first_indexed_command(script).kind {
    @parser.CommandKind::Source(source) => source
    _ => fail("expected source command")
  }
  let included = match source.included {
    Some(script) => script
    None => fail("expected included script")
  }
  let included_indexed = @semantics.build_index(included)
  let included_command = match
    @semantics.node_ref_of(
      included_indexed,
      find_first_command(included_indexed),
    ) {
    Some(@semantics.NodeRef::Command(command)) => command
    _ => fail("expected included command")
  }
  match included_command.kind {
    @parser.CommandKind::Simple(simple) => {
      assert_eq(simple.words.length(), 2)
      assert_eq(simple.words[0].source, "echo")
    }
    _ => fail("expected simple command")
  }
}

///|
test "indexed ast exposes direct spans for span-carrying nodes" {
  let script = parse_ok(
    (
      #|echo hi >out
      #|
    ),
  )
  let indexed = @semantics.build_index(script)

  let command = find_first_command(indexed)
  let word = find_first_word(indexed)
  match @semantics.span_of(indexed, @semantics.root_id(indexed)) {
    Some(span) => assert_true(span == script.span)
    None => fail("expected root span")
  }

  let command_span = match @semantics.span_of(indexed, command) {
    Some(span) => span
    None => fail("expected command span")
  }
  let word_span = match @semantics.span_of(indexed, word) {
    Some(span) => span
    None => fail("expected word span")
  }

  assert_eq(command_span.start.offset, 0)
  assert_eq(word_span.start.offset, 0)
}

///|
test "indexed ast effective spans fall back to enclosing spans" {
  let script = parse_ok(
    (
      #|echo "hi $USER"
      #|
    ),
  )
  let indexed = @semantics.build_index(script)
  let parameter = find_parameter_part(indexed)
  let containing_word = match @semantics.word_of(indexed, parameter) {
    Some(word) => word
    None => fail("expected containing word")
  }
  let effective_span = match @semantics.effective_span_of(indexed, parameter) {
    Some(span) => span
    None => fail("expected effective span")
  }

  assert_eq(effective_span.start.offset, containing_word.span.start.offset)
  assert_eq(effective_span.end.offset, containing_word.span.end.offset)
}

///|
test "indexed ast distinguishes exact spans from enclosing fallback spans" {
  let script = parse_ok(
    (
      #|echo "hi $USER"
      #|
    ),
  )
  let indexed = @semantics.build_index(script)
  let parameter = find_parameter_part(indexed)

  assert_true(@semantics.span_of(indexed, parameter) is None)

  let enclosing_span = match @semantics.enclosing_span_of(indexed, parameter) {
    Some(span) => span
    None => fail("expected enclosing span")
  }
  let containing_word = match @semantics.word_of(indexed, parameter) {
    Some(word) => word
    None => fail("expected containing word")
  }

  assert_eq(enclosing_span.start.offset, containing_word.span.start.offset)
  assert_eq(enclosing_span.end.offset, containing_word.span.end.offset)
}

///|
test "indexed ast hides synthetic spans for reparsed parameter operator words" {
  let default_script = parse_ok(
    (
      #|echo "${foo:-$bar}"
      #|
    ),
  )
  let default_indexed = @semantics.build_index(default_script)
  let default_inner_word = find_word_with_source(default_indexed, "$bar")

  assert_true(@semantics.span_of(default_indexed, default_inner_word) is None)
  let default_enclosing = match
    @semantics.enclosing_span_of(default_indexed, default_inner_word) {
    Some(span) => span
    None => fail("expected fallback span for reparsed default word")
  }
  let default_command = simple_of(first_indexed_command(default_script))
  assert_eq(
    default_enclosing.start.offset,
    default_command.words[1].span.start.offset,
  )
  assert_eq(
    default_enclosing.end.offset,
    default_command.words[1].span.end.offset,
  )

  let slice_script = parse_ok(
    (
      #|echo "${foo:$bar:1}"
      #|
    ),
  )
  let slice_indexed = @semantics.build_index(slice_script)
  let slice_inner_word = find_word_with_source(slice_indexed, "$bar")

  assert_true(@semantics.span_of(slice_indexed, slice_inner_word) is None)
  let slice_enclosing = match
    @semantics.enclosing_span_of(slice_indexed, slice_inner_word) {
    Some(span) => span
    None => fail("expected fallback span for reparsed slice word")
  }
  let slice_command = simple_of(first_indexed_command(slice_script))
  assert_eq(
    slice_enclosing.start.offset,
    slice_command.words[1].span.start.offset,
  )
  assert_eq(slice_enclosing.end.offset, slice_command.words[1].span.end.offset)
}
