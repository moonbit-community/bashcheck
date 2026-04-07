///|
/// Shell dialects recognized by the checker.
#warnings("-deprecated_syntax")
pub(all) enum ShellDialect {
  Sh
  Bash
  Dash
  Ksh
  BusyboxSh
} derive(Eq, Show, Debug)

///|
/// Whether a script is analyzed as an executed file or as a sourced file.
#warnings("-deprecated_syntax")
pub(all) enum ExecutionMode {
  Executed
  Sourced
} derive(Eq, Show, Debug)

///|
priv struct ShellResolution {
  dialect : ShellDialect
  suppresses_unknown_warning : Bool
}

///|
priv struct FilenameShellHint {
  dialect : ShellDialect
  suppresses_unknown_warning : Bool
}

///|
/// Determines the effective shell dialect from overrides, annotations,
/// shebangs, and filename hints.
pub fn determine_shell(
  script : @parser.Script,
  shell_override? : ShellDialect,
  filename? : String,
) -> ShellDialect {
  determine_shell_with_fallback(script, shell_override, filename, None)
}

///|
/// Determines the effective shell dialect with an optional explicit fallback.
pub fn determine_shell_with_fallback(
  script : @parser.Script,
  shell_override : ShellDialect?,
  filename : String?,
  fallback_shell : ShellDialect?,
) -> ShellDialect {
  resolve_shell(script, shell_override, filename, fallback_shell).dialect
}

///|
/// Reports whether shell resolution is explicit enough to suppress the
/// "unknown shell" warning.
pub fn suppresses_unknown_shell_warning(
  script : @parser.Script,
  shell_override : ShellDialect?,
  filename : String?,
  fallback_shell : ShellDialect?,
) -> Bool {
  resolve_shell(script, shell_override, filename, fallback_shell).suppresses_unknown_warning
}

///|
/// Infers a shell dialect from a shebang line.
pub fn shell_from_shebang(line : String) -> ShellDialect? {
  shell_from_executable_name(executable_from_shebang(line))
}

///|
/// Infers a shell dialect from parsed `shell=` annotations.
pub fn shell_from_annotation(
  annotations : Array[@parser.Annotation],
) -> ShellDialect? {
  for annotation in annotations {
    match annotation {
      @parser.Annotation::Shell(shell) =>
        match shell_from_executable_name(trim_ascii_space(shell)) {
          Some(dialect) => return Some(dialect)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
/// Infers a shell dialect from a filename convention.
pub fn shell_from_filename(filename : String) -> ShellDialect? {
  match shell_hint_from_filename(filename) {
    Some(hint) => Some(hint.dialect)
    None => None
  }
}

///|
/// Reports whether the script enables `set -e` / `errexit`.
pub fn has_set_e(script : @parser.Script) -> Bool {
  if shebang_has_short_flag(script.shebang, 'e') {
    return true
  }
  script_has_current_shell_command(script, fn(command) {
    set_command_enables_option(command, Some('e'), "errexit")
  })
}

///|
/// Reports whether the script enables `pipefail`.
pub fn has_pipefail(script : @parser.Script) -> Bool {
  if shebang_enables_set_option(script.shebang, None, "pipefail") {
    return true
  }
  script_has_current_shell_command(script, fn(command) {
    set_command_enables_option(command, None, "pipefail")
  })
}

///|
/// Reports whether the current shell configuration enables `lastpipe`.
pub fn has_lastpipe(script : @parser.Script, dialect : ShellDialect) -> Bool {
  match dialect {
    ShellDialect::Bash =>
      shebang_enables_shopt_option(script.shebang, "lastpipe") ||
      shopt_command_enables_option(script, "lastpipe")
    ShellDialect::Ksh => true
    _ => false
  }
}

///|
/// Reports whether the current shell configuration enables `inherit_errexit`.
pub fn has_inherit_errexit(
  script : @parser.Script,
  dialect : ShellDialect,
) -> Bool {
  match dialect {
    ShellDialect::Bash =>
      shebang_enables_shopt_option(script.shebang, "inherit_errexit") ||
      shopt_command_enables_option(script, "inherit_errexit")
    ShellDialect::Dash | ShellDialect::BusyboxSh | ShellDialect::Sh => true
    ShellDialect::Ksh => false
  }
}

///|
/// Reports whether the current shell configuration enables `execfail`.
pub fn has_execfail(script : @parser.Script, dialect : ShellDialect) -> Bool {
  match dialect {
    ShellDialect::Bash =>
      shebang_enables_shopt_option(script.shebang, "execfail") ||
      shopt_command_enables_option(script, "execfail")
    _ => false
  }
}

///|
/// Chooses the effective execution mode from an override and a `sourced` flag.
pub fn effective_execution_mode(
  mode_override? : ExecutionMode,
  sourced? : Bool = false,
) -> ExecutionMode {
  match mode_override {
    Some(mode) => mode
    None =>
      if sourced {
        ExecutionMode::Sourced
      } else {
        ExecutionMode::Executed
      }
  }
}

///|
fn resolve_shell(
  script : @parser.Script,
  shell_override : ShellDialect?,
  filename : String?,
  fallback_shell : ShellDialect?,
) -> ShellResolution {
  match shell_override {
    Some(dialect) => { dialect, suppresses_unknown_warning: true }
    None =>
      match shell_from_annotation(script.annotations) {
        Some(dialect) => { dialect, suppresses_unknown_warning: true }
        None =>
          match script.shebang {
            Some(shebang) =>
              match shell_from_shebang(shebang) {
                Some(dialect) => { dialect, suppresses_unknown_warning: true }
                None => resolve_fallback_shell(filename, fallback_shell)
              }
            None => resolve_fallback_shell(filename, fallback_shell)
          }
      }
  }
}

///|
fn resolve_fallback_shell(
  filename : String?,
  fallback_shell : ShellDialect?,
) -> ShellResolution {
  match filename {
    Some(filename) =>
      match shell_hint_from_filename(filename) {
        Some(hint) =>
          {
            dialect: hint.dialect,
            suppresses_unknown_warning: hint.suppresses_unknown_warning,
          }
        None => default_shell_resolution(fallback_shell)
      }
    None => default_shell_resolution(fallback_shell)
  }
}

///|
fn default_shell_resolution(fallback_shell : ShellDialect?) -> ShellResolution {
  match fallback_shell {
    Some(dialect) => { dialect, suppresses_unknown_warning: true }
    None => { dialect: ShellDialect::Bash, suppresses_unknown_warning: false }
  }
}

///|
fn shell_hint_from_filename(filename : String) -> FilenameShellHint? {
  if filename.has_suffix(".ksh") {
    return Some({ dialect: ShellDialect::Ksh, suppresses_unknown_warning: true })
  }
  if filename.has_suffix(".bash") || filename.has_suffix(".bats") {
    return Some({
      dialect: ShellDialect::Bash,
      suppresses_unknown_warning: true,
    })
  }
  if filename.has_suffix(".dash") {
    return Some({
      dialect: ShellDialect::Dash,
      suppresses_unknown_warning: true,
    })
  }
  if filename.has_suffix(".envrc") {
    return Some({
      dialect: ShellDialect::Bash,
      suppresses_unknown_warning: false,
    })
  }
  None
}

///|
fn shell_from_executable_name(name : String) -> ShellDialect? {
  match name {
    "sh" => Some(ShellDialect::Sh)
    "bash" | "bats" => Some(ShellDialect::Bash)
    "busybox" | "busybox sh" | "busybox ash" => Some(ShellDialect::BusyboxSh)
    "dash" | "ash" => Some(ShellDialect::Dash)
    "ksh" | "ksh88" | "ksh93" | "oksh" => Some(ShellDialect::Ksh)
    _ => None
  }
}

///|
fn executable_from_shebang(line : String) -> String {
  let words = shebang_words(line)
  if words.length() == 0 {
    return ""
  }
  let first = basename(quote_removed_source(words[0]))
  if first == "busybox" {
    if words.length() < 2 {
      return first
    }
    let second = basename(quote_removed_source(words[1]))
    match second {
      "sh" => "busybox sh"
      "ash" => "busybox ash"
      _ => second
    }
  } else if first == "env" {
    env_shell_from_args(words, 1)
  } else {
    first
  }
}

///|
fn shebang_words(line : String) -> Array[String] {
  let command = if line.has_prefix("#!") {
    trim_ascii_space(line.view(start_offset=2).to_string())
  } else {
    trim_ascii_space(line)
  }
  split_shell_words(command)
}

///|
fn env_shell_from_args(args : Array[String], start : Int) -> String {
  let mut i = start
  while i < args.length() {
    let arg = quote_removed_source(args[i])
    if arg == "-S" || arg == "--split-string" {
      if i + 1 < args.length() {
        let split = split_string_args_with_tail(
          split_shell_words(quote_removed_source(args[i + 1])),
          args,
          i + 2,
        )
        let shell = env_shell_from_args(split, 0)
        if shell != "" {
          return shell
        }
        i += 2
        continue
      }
      i += 1
      continue
    }
    if arg.has_prefix("--split-string=") {
      let head = arg.view(start_offset="--split-string=".length()).to_string()
      let split = if head != "" {
        split_string_args_with_tail(split_shell_words(head), args, i + 1)
      } else if i + 1 < args.length() {
        split_string_args_with_tail(
          split_shell_words(quote_removed_source(args[i + 1])),
          args,
          i + 2,
        )
      } else {
        []
      }
      if split.length() > 0 {
        let shell = env_shell_from_args(split, 0)
        if shell != "" {
          return shell
        }
        if head == "" {
          i += 2
          continue
        }
      }
      i += 1
      continue
    }
    if arg.has_prefix("-") || arg.contains("=") {
      i += 1
      continue
    }
    return basename(arg)
  }
  ""
}

///|
fn shebang_has_short_flag(shebang : String?, flag : UInt16) -> Bool {
  match shebang {
    Some(line) => shebang_args_have_short_flag(shebang_words(line), flag)
    None => false
  }
}

///|
fn shebang_enables_set_option(
  shebang : String?,
  short_flag : UInt16?,
  long_option : String,
) -> Bool {
  match shebang {
    Some(line) =>
      shebang_args_enable_option(
        shebang_words(line),
        short_flag,
        long_option,
        None,
        false,
      )
    None => false
  }
}

///|
fn shebang_enables_shopt_option(shebang : String?, option : String) -> Bool {
  match shebang {
    Some(line) =>
      shebang_args_enable_option(
        shebang_words(line),
        None,
        "",
        Some(option),
        true,
      )
    None => false
  }
}

///|
fn shebang_args_have_short_flag(args : Array[String], flag : UInt16) -> Bool {
  shebang_args_enable_option(args, Some(flag), "", None, false)
}

///|
fn shebang_args_enable_option(
  args : Array[String],
  short_flag : UInt16?,
  long_option : String,
  shopt_option : String?,
  shopt_mode : Bool,
) -> Bool {
  if args.length() == 0 {
    return false
  }
  let first = basename(quote_removed_source(args[0]))
  if first == "env" {
    return env_args_enable_option(
      args, 1, short_flag, long_option, shopt_option, shopt_mode,
    )
  }
  if first == "busybox" {
    return shell_args_enable_option(
      args, 2, short_flag, long_option, shopt_option, shopt_mode,
    )
  }
  shell_args_enable_option(
    args, 1, short_flag, long_option, shopt_option, shopt_mode,
  )
}

///|
fn env_args_enable_option(
  args : Array[String],
  start : Int,
  short_flag : UInt16?,
  long_option : String,
  shopt_option : String?,
  shopt_mode : Bool,
) -> Bool {
  let mut i = start
  while i < args.length() {
    let arg = quote_removed_source(args[i])
    if arg == "-S" || arg == "--split-string" {
      if i + 1 < args.length() {
        let combined = split_string_args_with_tail(
          split_shell_words(quote_removed_source(args[i + 1])),
          args,
          i + 2,
        )
        if env_args_enable_option(
            combined, 0, short_flag, long_option, shopt_option, shopt_mode,
          ) {
          return true
        }
        return false
      }
      i += 1
      continue
    }
    if arg.has_prefix("--split-string=") {
      let head = arg.view(start_offset="--split-string=".length()).to_string()
      let combined = if head != "" {
        split_string_args_with_tail(split_shell_words(head), args, i + 1)
      } else if i + 1 < args.length() {
        split_string_args_with_tail(
          split_shell_words(quote_removed_source(args[i + 1])),
          args,
          i + 2,
        )
      } else {
        []
      }
      if combined.length() > 0 {
        if env_args_enable_option(
            combined, 0, short_flag, long_option, shopt_option, shopt_mode,
          ) {
          return true
        }
      }
      if head == "" && i + 1 < args.length() {
        return false
      }
      return false
    }
    if arg.has_prefix("-") || arg.contains("=") {
      i += 1
      continue
    }
    return shell_args_enable_option(
      args,
      i + 1,
      short_flag,
      long_option,
      shopt_option,
      shopt_mode,
    )
  }
  false
}

///|
fn split_string_args_with_tail(
  split : Array[String],
  args : Array[String],
  tail_start : Int,
) -> Array[String] {
  let combined : Array[String] = []
  for part in split {
    combined.push(part)
  }
  let mut i = tail_start
  while i < args.length() {
    combined.push(args[i])
    i += 1
  }
  combined
}

///|
fn shell_args_enable_option(
  args : Array[String],
  start : Int,
  short_flag : UInt16?,
  long_option : String,
  shopt_option : String?,
  shopt_mode : Bool,
) -> Bool {
  let mut i = start
  while i < args.length() {
    let arg = quote_removed_source(args[i])
    if arg == "--" || arg == "-" || !arg.has_prefix("-") {
      return false
    }
    if arg == "-c" {
      return false
    }
    if arg == "-o" {
      if !shopt_mode &&
        i + 1 < args.length() &&
        quote_removed_source(args[i + 1]) == long_option {
        return true
      }
      i += 2
      continue
    }
    if arg == "-O" {
      if shopt_mode {
        match shopt_option {
          Some(option) if i + 1 < args.length() &&
            quote_removed_source(args[i + 1]) == option => return true
          _ => ()
        }
      }
      i += 2
      continue
    }
    if arg.has_prefix("--") {
      i += 1
      continue
    }
    match short_flag {
      Some(flag) => if short_flag_in_cluster(arg, flag) { return true }
      None => ()
    }
    i += 1
  }
  false
}

///|
fn script_has_current_shell_command(
  script : @parser.Script,
  predicate : (@parser.Command) -> Bool,
) -> Bool {
  for item in script.items {
    if list_item_has_current_shell_command(item, predicate) {
      return true
    }
  }
  false
}

///|
fn list_item_has_current_shell_command(
  item : @parser.ListItem,
  predicate : (@parser.Command) -> Bool,
) -> Bool {
  and_or_list_has_current_shell_command(item.and_or, predicate)
}

///|
fn and_or_list_has_current_shell_command(
  list : @parser.AndOrList,
  predicate : (@parser.Command) -> Bool,
) -> Bool {
  if pipeline_has_current_shell_command(list.head, predicate) {
    return true
  }
  for pair in list.tail {
    let (_, pipeline) = pair
    if pipeline_has_current_shell_command(pipeline, predicate) {
      return true
    }
  }
  false
}

///|
fn pipeline_has_current_shell_command(
  pipeline : @parser.Pipeline,
  predicate : (@parser.Command) -> Bool,
) -> Bool {
  for segment in pipeline.segments {
    if command_has_current_shell_command(segment.command, predicate) {
      return true
    }
  }
  false
}

///|
fn command_has_current_shell_command(
  command : @parser.Command,
  predicate : (@parser.Command) -> Bool,
) -> Bool {
  if predicate(command) {
    return true
  }
  match command.kind {
    @parser.CommandKind::Simple(_)
    | @parser.CommandKind::Condition(_)
    | @parser.CommandKind::Arithmetic(_)
    | @parser.CommandKind::Function(_)
    | @parser.CommandKind::CoProc(_)
    | @parser.CommandKind::BatsTest(_) => false
    @parser.CommandKind::Source(source) =>
      // Sourced files run in the current shell, so their option changes apply.
      match source.included {
        Some(script) => script_has_current_shell_command(script, predicate)
        None => false
      }
    @parser.CommandKind::Time(clause) =>
      pipeline_has_current_shell_command(clause.body, predicate)
    @parser.CommandKind::Subshell(_) => false
    @parser.CommandKind::BraceGroup(script) =>
      script_has_current_shell_command(script, predicate)
    @parser.CommandKind::If(clause) => {
      for arm in clause.arms {
        if script_has_current_shell_command(arm.condition, predicate) ||
          script_has_current_shell_command(arm.body, predicate) {
          return true
        }
      }
      match clause.else_body {
        Some(script) => script_has_current_shell_command(script, predicate)
        None => false
      }
    }
    @parser.CommandKind::While(clause) | @parser.CommandKind::Until(clause) =>
      script_has_current_shell_command(clause.condition, predicate) ||
      script_has_current_shell_command(clause.body, predicate)
    @parser.CommandKind::ForIn(clause) =>
      script_has_current_shell_command(clause.body, predicate)
    @parser.CommandKind::ForArithmetic(clause) =>
      script_has_current_shell_command(clause.body, predicate)
    @parser.CommandKind::Select(clause) =>
      script_has_current_shell_command(clause.body, predicate)
    @parser.CommandKind::Case(clause) => {
      for item in clause.items {
        if script_has_current_shell_command(item.body, predicate) {
          return true
        }
      }
      false
    }
  }
}

///|
fn shopt_command_enables_option(
  script : @parser.Script,
  option : String,
) -> Bool {
  script_has_current_shell_command(script, fn(command) {
    shopt_simple_command_enables_option(command, option)
  })
}

///|
fn shopt_simple_command_enables_option(
  command : @parser.Command,
  option : String,
) -> Bool {
  guard command_name(command) == Some("shopt") else { return false }
  let words = command_arguments(command)
  let mut enabling = false
  let mut parsing_flags = true
  let mut i = 0
  while i < words.length() {
    let text = match literal_text(words[i]) {
      Some(text) => text
      None => {
        if parsing_flags {
          parsing_flags = false
        }
        i += 1
        continue
      }
    }
    if parsing_flags {
      if text == "--" {
        parsing_flags = false
        i += 1
        continue
      }
      if text.has_prefix("-") && !text.has_prefix("--") {
        if short_flag_in_cluster(text, 'u') {
          enabling = false
        }
        if short_flag_in_cluster(text, 's') {
          enabling = true
        }
        i += 1
        continue
      }
      parsing_flags = false
    }
    if enabling {
      if text == option {
        return true
      }
    }
    i += 1
  }
  false
}

///|
fn set_command_enables_option(
  command : @parser.Command,
  short_flag : UInt16?,
  long_option : String,
) -> Bool {
  guard command_name(command) == Some("set") else { return false }
  let words = command_arguments(command)
  let mut i = 0
  while i < words.length() {
    let text = match literal_text(words[i]) {
      Some(text) => text
      None => return false
    }
    if text == "--" || text == "-" || text == "+" {
      return false
    }
    let view = text.view()
    guard view.length() > 1 else { return false }
    let prefix = view[0]
    if (prefix != '-' && prefix != '+') ||
      (view.length() > 1 && view[1] == prefix) {
      return false
    }
    let enabling = prefix == '-'
    let mut consumes_long_option = false
    let mut j = 1
    while j < view.length() {
      let flag = view[j]
      if !is_set_short_option(flag) {
        return false
      }
      match short_flag {
        Some(target) if flag == target && enabling => return true
        _ => ()
      }
      if flag == 'o' {
        consumes_long_option = true
      }
      j += 1
    }
    if consumes_long_option {
      if i + 1 >= words.length() {
        return false
      }
      match literal_text(words[i + 1]) {
        Some(name) if name == long_option && enabling => return true
        Some(_) => ()
        None => return false
      }
      i += 2
      continue
    }
    i += 1
  }
  false
}

///|
fn short_flag_in_cluster(text : String, flag : UInt16) -> Bool {
  if !text.has_prefix("-") || text.has_prefix("--") {
    return false
  }
  let view = text[:]
  let mut i = 1
  while i < view.length() {
    if view[i] == flag {
      return true
    }
    i += 1
  }
  false
}

///|
fn is_set_short_option(flag : UInt16) -> Bool {
  match flag {
    'a'
    | 'b'
    | 'B'
    | 'C'
    | 'e'
    | 'E'
    | 'f'
    | 'h'
    | 'H'
    | 'k'
    | 'm'
    | 'n'
    | 'o'
    | 'p'
    | 'P'
    | 't'
    | 'T'
    | 'u'
    | 'v'
    | 'x' => true
    _ => false
  }
}

///|
fn trim_ascii_space(text : String) -> String {
  let view = text[:]
  let mut start = 0
  while start < view.length() &&
        (
          view[start] == ' ' ||
          view[start] == '\t' ||
          view[start] == '\r' ||
          view[start] == '\n'
        ) {
    start += 1
  }
  let mut end_ = view.length()
  while end_ > start &&
        (
          view[end_ - 1] == ' ' ||
          view[end_ - 1] == '\t' ||
          view[end_ - 1] == '\r' ||
          view[end_ - 1] == '\n'
        ) {
    end_ -= 1
  }
  text.view(start_offset=start, end_offset=end_).to_string()
}

///|
fn basename(text : String) -> String {
  let view = text[:]
  let mut start = 0
  let mut i = 0
  while i < view.length() {
    if view[i] == '/' {
      start = i + 1
    }
    i += 1
  }
  text.view(start_offset=start).to_string()
}

///|
fn split_shell_words(text : String) -> Array[String] {
  let values : Array[String] = []
  let current = StringBuilder::new()
  let view = text[:]
  let mut i = 0
  let mut quote : UInt16? = None
  while i < view.length() {
    let ch = view[i]
    match quote {
      Some(current_quote) => {
        current.write_char(ch.unsafe_to_char())
        if ch == '\\' && current_quote == '"' && i + 1 < view.length() {
          i += 1
          current.write_char(view[i].unsafe_to_char())
        } else if ch == current_quote {
          quote = None
        }
      }
      None =>
        if ch == ' ' || ch == '\t' {
          let item = current.to_string()
          if item != "" {
            values.push(item)
            current.reset()
          }
        } else {
          current.write_char(ch.unsafe_to_char())
          if ch == '\\' && i + 1 < view.length() {
            i += 1
            current.write_char(view[i].unsafe_to_char())
          } else if ch == '\'' || ch == '"' {
            quote = Some(ch)
          }
        }
    }
    i += 1
  }
  let tail = current.to_string()
  if tail != "" {
    values.push(tail)
  }
  values
}

///|
fn quote_removed_source(raw : String) -> String {
  let buf = StringBuilder::new()
  let view = raw[:]
  let mut i = 0
  let mut quote : UInt16? = None
  while i < view.length() {
    let ch = view[i]
    match quote {
      Some(current) => {
        if ch == current {
          quote = None
          i += 1
          continue
        }
        if current == '"' && ch == '\\' && i + 1 < view.length() {
          let next = view[i + 1]
          if next == '$' ||
            next == '"' ||
            next == '\\' ||
            next == '\n' ||
            next == '\r' {
            buf.write_char(next.unsafe_to_char())
            i += 2
            continue
          }
        }
        buf.write_char(ch.unsafe_to_char())
        i += 1
      }
      None => {
        if ch == '\'' || ch == '"' {
          quote = Some(ch)
          i += 1
          continue
        }
        if ch == '\\' {
          if i + 1 < view.length() {
            buf.write_char(view[i + 1].unsafe_to_char())
            i += 2
          } else {
            i += 1
          }
          continue
        }
        buf.write_char(ch.unsafe_to_char())
        i += 1
      }
    }
  }
  buf.to_string()
}
