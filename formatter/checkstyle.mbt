///|
/// Renders diagnostics using the Checkstyle XML schema.
///
/// Each checked file becomes one `<file>` element containing zero or more
/// `<error>` elements so existing CI tooling can ingest the report directly.
fn render_checkstyle(results : Array[@checker.CheckResult]) -> String {
  let lines : Array[String] = [
    "<?xml version='1.0' encoding='UTF-8'?>", "<checkstyle version='4.3'>",
  ]
  for result in results {
    lines.push(render_checkstyle_file(result))
  }
  lines.push("</checkstyle>")
  lines.join("\n")
}

///|
/// Renders one `<file>` block for Checkstyle output.
fn render_checkstyle_file(result : @checker.CheckResult) -> String {
  let lines : Array[String] = ["<file name='\{xml_escape(result.filename)}'>"]
  for diagnostic in result.diagnostics {
    lines.push(
      "<error line='\{diagnostic.span.start.line}' column='\{diagnostic.span.start.column}' severity='\{checkstyle_severity(diagnostic)}' message='\{xml_escape(diagnostic.message)}' source='ShellCheck.\{code_text(diagnostic)}' />",
    )
  }
  lines.push("</file>")
  lines.join("\n")
}

///|
/// Escapes XML special characters inside attribute values.
fn xml_escape(text : String) -> String {
  let builder = StringBuilder::new()
  for ch in text {
    match ch {
      '&' => builder.write_string("&amp;")
      '<' => builder.write_string("&lt;")
      '>' => builder.write_string("&gt;")
      '"' => builder.write_string("&quot;")
      '\'' => builder.write_string("&apos;")
      _ => builder.write_string(ch.to_string())
    }
  }
  builder.to_string()
}

///|
/// Maps checker severities to the smaller set of Checkstyle severity strings.
fn checkstyle_severity(diagnostic : @checker.PositionedDiagnostic) -> String {
  match diagnostic.severity {
    @checker.DiagnosticSeverity::Error => "error"
    @checker.DiagnosticSeverity::Warning => "warning"
    _ => "info"
  }
}
