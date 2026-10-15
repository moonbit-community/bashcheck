///|
/// Internal structured parse failures.
///
/// The structured variants preserve the source position and enough context to
/// render ShellCheck-style error messages.
priv suberror ParseError {
  UnexpectedEnd(pos~ : Position, context~ : String)
  UnexpectedToken(pos~ : Position, found~ : String, expected~ : String)
  Message(pos~ : Position, message~ : String)
}
