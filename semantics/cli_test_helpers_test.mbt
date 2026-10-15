///|
fn test_parse_script(source : String) -> Result[@parser.Script, String] {
  let report = @parser.parse_script_report(source)
  for diagnostic in report.diagnostics {
    if diagnostic.severity is Error {
      return Err(
        "\{diagnostic.span.start.line}:\{diagnostic.span.start.column}: \{diagnostic.message}",
      )
    }
  }
  match report.script {
    Some(script) => Ok(script)
    None => Err("parse failed")
  }
}

///|
fn test_determine_shell(
  script : @parser.Script,
  shell_override? : @semantics.ShellDialect,
  filename? : String,
) -> @semantics.ShellDialect {
  @semantics.determine_shell(script, shell_override, filename)
}

///|
fn test_effective_span(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
) -> @parser.Span? {
  match @semantics.span_of(indexed, id) {
    Some(span) => Some(span)
    None => @semantics.enclosing_span_of(indexed, id)
  }
}

///|
fn test_containing_word(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
) -> @parser.Word? {
  match @semantics.node_ref_of(indexed, id) {
    Some(Word(word)) => Some(word)
    _ =>
      match @semantics.parent_of(indexed, id) {
        Some(parent) => test_containing_word(indexed, parent)
        None => None
      }
  }
}

///|
fn test_containing_command(
  indexed : @semantics.IndexedScript,
  id : @semantics.NodeId,
) -> @parser.Command? {
  match @semantics.node_ref_of(indexed, id) {
    Some(Command(command)) => Some(command)
    _ =>
      match @semantics.parent_of(indexed, id) {
        Some(parent) => test_containing_command(indexed, parent)
        None => None
      }
  }
}
