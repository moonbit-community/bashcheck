///|
/// Value-taking options shared by argparse and ShellCheck syntax normalization.
/// Each entry contains the long name, optional short alias, and help text.
pub fn cli_value_options() -> Array[(String, Char?, String)] {
  [
    (
      "format",
      Some('f'),
      "Output format (checkstyle, diff, gcc, json, json1, quiet, tty)",
    ),
    ("shell", Some('s'), "Specify dialect (sh, bash, dash, ksh, busybox)"),
    (
      "severity",
      Some('S'),
      "Minimum severity of errors to consider (error, warning, info, style)",
    ),
    (
      "include",
      Some('i'),
      "Consider only given types of warnings (comma-separated codes)",
    ),
    ("exclude", Some('e'), "Exclude types of warnings (comma-separated codes)"),
    ("enable", Some('o'), "List of optional checks to enable (or 'all')"),
    (
      "source-path",
      Some('P'),
      "Specify path when looking for sourced files (\"SCRIPTDIR\" for script's dir)",
    ),
    (
      "rcfile",
      None,
      "Prefer the specified configuration file over searching for one",
    ),
    (
      "color",
      Some('C'),
      "Use color (auto, always, never); bare -C/--color means always",
    ),
    (
      "wiki-link-count",
      Some('W'),
      "The number of wiki links to show, when applicable (default 3)",
    ),
    (
      "extended-analysis",
      None,
      "Perform dataflow analysis (true/false, default true)",
    ),
  ]
}

///|
/// The command schema is the single source for argument parsing and help.
pub fn cli_command() -> @argparse.Command {
  @argparse.Command(
    "bashcheck",
    // Meta actions remain ordinary flags so parsing stays pure and the driver
    // controls output, exit codes, and first-action precedence.
    disable_help_flag=true,
    disable_version_flag=true,
    flags=[
      @argparse.FlagArg(
        "check-sourced",
        short='a',
        about="Include warnings from sourced files",
      ),
      @argparse.FlagArg(
        "external-sources",
        short='x',
        about="Allow 'source' outside of FILES",
      ),
      @argparse.FlagArg("norc", about="Don't look for .shellcheckrc files"),
      @argparse.FlagArg(
        "list-optional",
        about="List checks disabled by default",
      ),
      @argparse.FlagArg("version", short='V', about="Print version information"),
      @argparse.FlagArg("help", about="Show this usage summary and exit"),
    ],
    // Append preserves every occurrence for validation and accumulation, and
    // lets the first explicit format win across long and short aliases.
    options=cli_value_options().map(option => {
      let (name, short, about) = option
      match short {
        Some(short) =>
          @argparse.OptionArg(
            name,
            short~,
            about~,
            action=Append,
            allow_hyphen_values=true,
          )
        None =>
          @argparse.OptionArg(
            name,
            about~,
            action=Append,
            allow_hyphen_values=true,
          )
      }
    }),
    positionals=[
      @argparse.PositionArg(
        "files",
        about="Shell scripts to check ('-' for stdin; default: stdin)",
        num_args=@argparse.ValueRange(lower=0),
      ),
    ],
  )
}
