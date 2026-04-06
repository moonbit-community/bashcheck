///|
test "shellcheck gap coverage single and double quoted samples" {
  assert_word_ok("prop_readSingleQuoted", "'foo bar'")
  assert_word_warning("prop_readSingleQuoted2", "'foo bar\\'")
  assert_word_warning("prop_readSingleQuoted4", "'it's")
  assert_word_ok("prop_readSingleQuoted7", "'foo“bar'")
  assert_word_warning("prop_readSingleQuoted8", "'foo‘bar'")

  assert_ok("prop_readDoubleQuoted2", "echo \"$'\"")
  assert_ok("prop_readDoubleQuoted3", "echo \"‘hello’\"")
  assert_warning(
    "prop_readDoubleQuoted4",
    (
      #|"foo
      #|bar"foo
    ),
  )
  assert_ok(
    "prop_readDoubleQuoted5",
    (
      #|lol "foo
      #|bar" etc
    ),
  )
  assert_ok("prop_readDoubleQuoted6", "echo \"${ ls; }\"")
  assert_ok("prop_readDoubleQuoted7", "echo \"${ ls;}bar\"")
  assert_warning("prop_readDoubleQuoted8", "echo \"“hello”\"")
  assert_ok("prop_readDoubleQuoted10", "echo \"foo\\\\n\"")
}

///|
test "shellcheck gap coverage backquoted samples" {
  assert_ok(
    "prop_readBackTicked4",
    (
      #|`echo foo
      #|echo bar`
    ),
  )
  assert_ok("prop_readBackTicked5", "echo `foo`bar")
  assert_warning(
    "prop_readBackTicked6",
    (
      #|echo `foo
      #|echo `bar
    ),
  )
  assert_ok("prop_readBackTicked7", "`#inline comment`")
  assert_ok(
    "prop_readBackTicked8",
    (
      #|echo `#comment` \
      #|bar baz
    ),
  )
}

///|
test "shellcheck gap coverage simple command samples" {
  assert_ok("prop_readSimpleCommand5", "time if true; then echo foo; fi")
  assert_ok("prop_readSimpleCommand6", "time -p ( ls -l; )")
  assert_ok("prop_readSimpleCommand7", "\\ls")
  assert_ok("prop_readSimpleCommand7b", "\\:")
  assert_warning("prop_readSimpleCommand8", "// Lol")
  assert_warning("prop_readSimpleCommand9", "/* Lolbert */")
  assert_warning("prop_readSimpleCommand10", "/**** Lolbert */")
  assert_ok("prop_readSimpleCommand11", "/\\* foo")
  assert_warning("prop_readSimpleCommand12", "elsif foo")
  assert_warning("prop_readSimpleCommand13", "ElseIf foo")
  assert_warning("prop_readSimpleCommand14", "elseif[$i==2]")
  assert_warning("prop_readSimpleCommand15", "trap 'foo\"bar' INT")
}

///|
test "shellcheck gap coverage assignment samples" {
  assert_ok("prop_readAssignmentWord7", "a[3$n'']=42")
  assert_ok("prop_readAssignmentWord8", "a[4''$(cat foo)]=42")
  assert_ok("prop_readAssignmentWord11", "foo=([a]=b [c] [d]= [e f )")
  assert_ok("prop_readAssignmentWord12", "a[b <<= 3 + c]='thing'")
  assert_ok("prop_readAssignmentWord13", "var=( (1 2) (3 4) )")
  assert_ok("prop_readAssignmentWord14", "var=( 1 [2]=(3 4) )")
  assert_ok("prop_readAssignmentWord15", "var=(1 [2]=(3 4))")
}

///|
test "brace expansions and array indexes stay balanced across nested shell syntax" {
  let brace_script = parse_ok(
    (
      #|echo {foo,"}"}
      #|
    ),
  )
  let (_, brace_simple) = first_simple(brace_script)
  match brace_simple.words[1].parts[0] {
    @parser.WordPart::BraceExpansion(expansion) => {
      assert_eq(expansion.raw, "{foo,\"}\"}")
      assert_eq(expansion.elements.length(), 2)
      assert_eq(expansion.elements[0].source, "foo")
      assert_eq(expansion.elements[1].source, "\"}\"")
    }
    _ => fail("expected brace expansion containing quoted closing brace")
  }

  let brace_subst = parse_ok(
    (
      #|echo {foo,$(printf %s })}
      #|
    ),
  )
  let (_, brace_subst_simple) = first_simple(brace_subst)
  match brace_subst_simple.words[1].parts[0] {
    @parser.WordPart::BraceExpansion(expansion) => {
      assert_eq(expansion.raw, "{foo,$(printf %s })}")
      assert_eq(expansion.elements.length(), 2)
      assert_eq(expansion.elements[1].source, "$(printf %s })")
    }
    _ => fail("expected brace expansion containing command substitution")
  }

  let index_script = parse_ok(
    (
      #|a[$(printf %s ])]=42
      #|
    ),
  )
  let (_, index_simple) = first_simple(index_script)
  assert_eq(index_simple.assignments.length(), 1)
  assert_eq(index_simple.assignments[0].indexes.length(), 1)
  assert_eq(index_raw(index_simple.assignments[0].indexes[0]), "$(printf %s ])")
  assert_eq(assignment_word(index_simple.assignments[0].value).source, "42")

  let parameter_index_script = parse_ok(
    (
      #|echo ${arr[$(printf %s ])]}
      #|
    ),
  )
  let (_, parameter_index_simple) = first_simple(parameter_index_script)
  match braced_parameter(parameter_index_simple.words[1].parts[0]).index {
    Some(index) => assert_eq(index_raw(index), "$(printf %s ])")
    None => fail("expected parameter expansion index")
  }
}

///|
test "command substitutions stay balanced across nested parameter expansions" {
  let script = parse_ok(
    (
      #|echo $(printf %s ${x//)/_}) <(printf %s ${x//)/_})
      #|
    ),
  )
  let (_, simple) = first_simple(script)

  match simple.words[1].parts[0] {
    @parser.WordPart::CommandSubstitution(inner) => {
      let (_, nested) = first_simple(inner)
      assert_eq(nested.words.length(), 3)
      assert_eq(nested.words[0].source, "printf")
      assert_eq(nested.words[1].source, "%s")
      assert_eq(nested.words[2].source, "${x//)/_}")
    }
    _ => fail("expected command substitution with nested parameter expansion")
  }

  match simple.words[2].parts[0] {
    @parser.WordPart::ProcessSubstitution(kind, inner) => {
      assert_eq(kind, "<")
      let (_, nested) = first_simple(inner)
      assert_eq(nested.words[2].source, "${x//)/_}")
    }
    _ => fail("expected process substitution with nested parameter expansion")
  }
}

///|
test "parameter expansions preserve nested command substitutions with closing parens" {
  let script = parse_ok(
    (
      #|echo ${foo:=$(printf %s ${x//)/_})}
      #|
    ),
  )
  let (_, simple) = first_simple(script)
  let expansion = braced_parameter(simple.words[1].parts[0])
  assert_eq(expansion.raw, "foo:=$(printf %s ${x//)/_})")
  match expansion.operator {
    Some(@parser.ParameterOperator::AssignDefault(text)) =>
      assert_eq(text, "$(printf %s ${x//)/_})")
    _ =>
      fail("expected assign-default operator with nested command substitution")
  }
}

///|
test "arithmetic expansions preserve nested command substitutions with closing parens" {
  let script = parse_ok(
    (
      #|echo $(( $(printf %s ${x//)/_}) + 1 ))
      #|
    ),
  )
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::ArithmeticExpansion(expr) =>
      assert_eq(arithmetic_raw(expr), " $(printf %s ${x//)/_}) + 1 ")
    _ => fail("expected arithmetic expansion")
  }
}

///|
test "parameter operators ignore nested separator characters" {
  let script = parse_ok(
    (
      #|echo ${var:${foo:-1}:2} ${var:$(printf %s :):1} ${var/${foo:-/}/x} ${var/$(printf %s /)/$(printf %s /)}
      #|
    ),
  )
  let (_, simple) = first_simple(script)

  let nested_slice = braced_parameter(simple.words[1].parts[0])
  match nested_slice.operator {
    Some(@parser.ParameterOperator::Slice(offset, Some(length))) => {
      assert_eq(offset, "${foo:-1}")
      assert_eq(length, "2")
    }
    _ => fail("expected slice operator with nested parameter expansion")
  }

  let command_slice = braced_parameter(simple.words[2].parts[0])
  match command_slice.operator {
    Some(@parser.ParameterOperator::Slice(offset, Some(length))) => {
      assert_eq(offset, "$(printf %s :)")
      assert_eq(length, "1")
    }
    _ => fail("expected slice operator with nested command substitution")
  }

  let nested_replace = braced_parameter(simple.words[3].parts[0])
  match nested_replace.operator {
    Some(@parser.ParameterOperator::Replace(mode, pattern, replacement)) => {
      match mode {
        @parser.ParameterReplaceMode::First => ()
        _ => fail("expected first replacement mode")
      }
      assert_eq(pattern, "${foo:-/}")
      match replacement {
        Some(text) => assert_eq(text, "x")
        None => fail("expected replacement text")
      }
    }
    _ => fail("expected replace operator with nested parameter expansion")
  }

  let command_replace = braced_parameter(simple.words[4].parts[0])
  match command_replace.operator {
    Some(@parser.ParameterOperator::Replace(mode, pattern, replacement)) => {
      match mode {
        @parser.ParameterReplaceMode::First => ()
        _ => fail("expected first replacement mode")
      }
      assert_eq(pattern, "$(printf %s /)")
      match replacement {
        Some(text) => assert_eq(text, "$(printf %s /)")
        None => fail("expected replacement command substitution")
      }
    }
    _ => fail("expected replace operator with nested command substitutions")
  }
}

///|
test "legacy dollar bracket arithmetic ignores closing brackets inside nested shell syntax" {
  let script = parse_ok(
    (
      #|echo $[$(printf %s ]) + ${arr[$(printf %s ])]} + 1]
      #|
    ),
  )
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::DollarBracket(expr) =>
      assert_eq(
        arithmetic_raw(expr),
        "$(printf %s ]) + ${arr[$(printf %s ])]} + 1",
      )
    _ => fail("expected dollar bracket arithmetic expansion")
  }
}

///|
test "modern arithmetic expansions ignore closing brackets inside nested shell syntax" {
  let script = parse_ok(
    (
      #|echo $(( arr[$(printf %s ])] + ${arr[$(printf %s ])]} + 1 ))
      #|
    ),
  )
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::ArithmeticExpansion(expr) =>
      assert_eq(
        arithmetic_raw(expr),
        " arr[$(printf %s ])] + ${arr[$(printf %s ])]} + 1 ",
      )
    _ => fail("expected arithmetic expansion")
  }
}

///|
test "array literals and associative indices preserve nested shell syntax" {
  let script = parse_ok(
    (
      #|map=(["a ] b"]=x [$(printf %s ])]=y [${arr[$(printf %s ])]}]=(foo "bar]" $(printf %s ])))
      #|
    ),
  )
  let (_, simple) = first_simple(script)
  assert_eq(simple.assignments.length(), 1)
  match simple.assignments[0].value {
    @parser.AssignmentValue::ArrayLiteral(elements) => {
      assert_eq(elements.length(), 3)

      assert_eq(index_raw(elements[0].indexes[0]), "\"a ] b\"")
      assert_eq(assignment_word(elements[0].value).source, "x")

      assert_eq(index_raw(elements[1].indexes[0]), "$(printf %s ])")
      assert_eq(assignment_word(elements[1].value).source, "y")

      assert_eq(index_raw(elements[2].indexes[0]), "${arr[$(printf %s ])]}")
      match elements[2].value {
        @parser.AssignmentValue::ArrayLiteral(nested) => {
          assert_eq(nested.length(), 3)
          assert_eq(assignment_word(nested[0].value).source, "foo")
          assert_eq(assignment_word(nested[1].value).source, "\"bar]\"")
          assert_eq(assignment_word(nested[2].value).source, "$(printf %s ])")
        }
        _ => fail("expected nested array literal value")
      }
    }
    _ => fail("expected structured associative array literal")
  }
}

///|
test "brace expansions and extglobs ignore separators inside backticks" {
  let brace_script = parse_ok(
    (
      #|echo {foo,`printf %s ,`,bar}
      #|
    ),
  )
  let (_, brace_simple) = first_simple(brace_script)
  match brace_simple.words[1].parts[0] {
    @parser.WordPart::BraceExpansion(expansion) => {
      assert_eq(expansion.elements.length(), 3)
      assert_eq(expansion.elements[0].source, "foo")
      assert_eq(expansion.elements[1].source, "`printf %s ,`")
      assert_eq(expansion.elements[2].source, "bar")
    }
    _ => fail("expected brace expansion with backquoted element")
  }

  let extglob_script = parse_ok(
    (
      #|echo @(foo|`printf %s '|'`|bar)
      #|
    ),
  )
  let (_, extglob_simple) = first_simple(extglob_script)
  match extglob_simple.words[1].parts[0] {
    @parser.WordPart::ExtGlob(pattern) => {
      assert_eq(pattern.alternatives.length(), 3)
      assert_eq(pattern.alternatives[0].source, "foo")
      assert_eq(pattern.alternatives[1].source, "`printf %s '|'`")
      assert_eq(pattern.alternatives[2].source, "bar")
    }
    _ => fail("expected extglob with backquoted alternative")
  }
}

///|
test "arithmetic for clauses ignore semicolons inside nested shell syntax" {
  let script = parse_ok(
    (
      #|for (( $(echo i=0; echo j=1); i<10; i++ )); do :; done
      #|
    ),
  )
  match first_command(script).kind {
    @parser.CommandKind::ForArithmetic(clause) => {
      assert_eq(arithmetic_raw(clause.init), "$(echo i=0; echo j=1)")
      assert_eq(arithmetic_raw(clause.condition), "i<10")
      assert_eq(arithmetic_raw(clause.step), "i++")
    }
    _ => fail("expected arithmetic for clause")
  }
}

///|
test "arithmetic for clauses ignore semicolons inside backticks" {
  let script = parse_ok(
    (
      #|for (( `echo i=0; echo j=1`; i<10; i++ )); do :; done
      #|
    ),
  )
  match first_command(script).kind {
    @parser.CommandKind::ForArithmetic(clause) => {
      assert_eq(arithmetic_raw(clause.init), "`echo i=0; echo j=1`")
      assert_eq(arithmetic_raw(clause.condition), "i<10")
      assert_eq(arithmetic_raw(clause.step), "i++")
    }
    _ => fail("expected arithmetic for clause with backticks")
  }
}

///|
test "arithmetic for clauses ignore semicolons inside parameter expansions" {
  let script = parse_ok(
    (
      #|for (( ${x//;/_}; i<10; i++ )); do :; done
      #|
    ),
  )
  match first_command(script).kind {
    @parser.CommandKind::ForArithmetic(clause) => {
      assert_eq(arithmetic_raw(clause.init), "${x//;/_}")
      assert_eq(arithmetic_raw(clause.condition), "i<10")
      assert_eq(arithmetic_raw(clause.step), "i++")
    }
    _ => fail("expected arithmetic for clause with parameter expansion")
  }
}

///|
test "arithmetic groups ignore closing parens inside nested shell syntax" {
  let script = parse_ok(
    (
      #|echo $(( (${x//)/_}) + (`printf %s ')'`) ))
      #|
    ),
  )
  let (_, simple) = first_simple(script)
  match simple.words[1].parts[0] {
    @parser.WordPart::ArithmeticExpansion(expr) => {
      match expr.tokens[0] {
        @parser.ArithmeticToken::Group(inner) =>
          assert_eq(arithmetic_raw(inner), "${x//)/_}")
        _ => fail("expected grouped parameter expansion")
      }
      match expr.tokens[1] {
        @parser.ArithmeticToken::Operator(op) => assert_eq(op, "+")
        _ => fail("expected plus operator")
      }
      match expr.tokens[2] {
        @parser.ArithmeticToken::Group(inner) =>
          assert_eq(arithmetic_raw(inner), "`printf %s ')'`")
        _ => fail("expected grouped backquoted command")
      }
    }
    _ => fail("expected arithmetic expansion")
  }
}

///|
test "case bodies ignore closing parens inside nested shell syntax" {
  let script = parse_ok(
    (
      #|case $x in
      #|foo)
      #|  echo ${x//)/_}
      #|  echo `printf %s ')'`
      #|  ;;
      #|esac
      #|
    ),
  )
  match first_command(script).kind {
    @parser.CommandKind::Case(clause) => {
      assert_eq(clause.items.length(), 1)
      assert_eq(clause.items[0].body.items.length(), 2)
    }
    _ => fail("expected case clause")
  }
}
