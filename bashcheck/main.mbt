///|
/// CLI entry point.
///
/// The executable keeps `main` intentionally thin: it normalizes argv,
/// delegates all parsing and checking to library code, then converts the final
/// `CliOutcome` into stdout output plus a process exit code.
async fn main {
  let args = @env.args()
  let user_args : Array[String] = []
  let mut i = 1
  while i < args.length() {
    // `@env.args()` includes argv[0], but the CLI parser expects only
    // user-provided flags and filenames.
    user_args.push(args[i])
    i += 1
  }
  let outcome = match parse_cli_args(user_args) {
    Ok(config) =>
      // Successful parsing only produces a normalized config; all IO and
      // checking happens in the higher-level driver so the parser stays pure.
      @driver.run_cli(
        config.action,
        config.files,
        config.spec,
        config.format,
        config.format_options,
      )
    Err(error) =>
      // Usage and support errors are reported through the same `CliOutcome`
      // shape as normal runs so `main` only needs one rendering path.
      @driver.CliOutcome::new(error.message, cli_exit_code(error.kind))
  }
  if outcome.output != "" {
    println(outcome.output)
  }
  if outcome.exit_code != 0 {
    // Returning normally would report success, so non-zero outcomes must exit
    // explicitly after rendering their message.
    exit_process(outcome.exit_code)
  }
}
