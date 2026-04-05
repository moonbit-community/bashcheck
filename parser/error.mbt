///|
/// Parse failures returned by `parse_script`.
///
/// The structured variants preserve the source position and enough context to
/// render ShellCheck-style error messages.
pub suberror ParseError {
  UnexpectedEnd(pos~ : Position, context~ : String)
  UnexpectedToken(pos~ : Position, found~ : String, expected~ : String)
  Message(pos~ : Position, message~ : String)
} derive(Eq)

///|
fn parse_error_message(err : ParseError) -> String {
  match err {
    UnexpectedEnd(pos~, context~) =>
      "\{pos.line}:\{pos.column}: unexpected end while parsing \{context}"
    UnexpectedToken(pos~, found~, expected~) =>
      "\{pos.line}:\{pos.column}: expected \{expected}, found \{found}"
    Message(pos~, message~) => "\{pos.line}:\{pos.column}: \{message}"
  }
}

///|
/// Formats a parse error as user-facing text.
pub impl Show for ParseError with output(self, logger) {
  logger.write_string(parse_error_message(self))
}
