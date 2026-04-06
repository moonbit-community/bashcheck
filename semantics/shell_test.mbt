///|
fn[A] shell_fail(message : String) -> A {
  println(message)
  panic()
}

///|
fn parse_shell_ok(source : String) -> @parser.Script {
  match @parser.parse_script(source) {
    Ok(script) => script
    Err(error) => shell_fail(error.to_string())
  }
}

///|
fn parse_shell_with_options(
  source : String,
  options : @parser.ParseOptions,
) -> @parser.Script {
  let report = @parser.parse_script_with_options(source, options)
  match report.script {
    Some(script) => script
    None => shell_fail("expected script")
  }
}

///|
test "shell dialect selection respects override annotation shebang and filename" {
  let annotated = parse_shell_ok(
    (
      #|#!/bin/sh
      #|# shellcheck shell=ksh
      #|true
      #|
    ),
  )
  assert_eq(@semantics.determine_shell(annotated), @semantics.ShellDialect::Ksh)
  assert_eq(
    @semantics.determine_shell(
      annotated,
      shell_override=@semantics.ShellDialect::Dash,
    ),
    @semantics.ShellDialect::Dash,
  )

  let plain = parse_shell_ok(
    (
      #|true
      #|
    ),
  )
  assert_eq(
    @semantics.determine_shell(plain, filename="hooks/pre-commit.envrc"),
    @semantics.ShellDialect::Bash,
  )
  assert_eq(@semantics.determine_shell(plain), @semantics.ShellDialect::Bash)
}

///|
test "unknown-shell warning suppression follows shellcheck entry semantics" {
  let plain = parse_shell_ok(
    (
      #|true
      #|
    ),
  )
  let annotated = parse_shell_ok(
    (
      #|# shellcheck shell=dash
      #|true
      #|
    ),
  )

  assert_true(
    !@semantics.suppresses_unknown_shell_warning(plain, None, None, None),
  )
  assert_true(
    @semantics.suppresses_unknown_shell_warning(
      plain,
      Some(@semantics.ShellDialect::Ksh),
      None,
      None,
    ),
  )
  assert_true(
    @semantics.suppresses_unknown_shell_warning(annotated, None, None, None),
  )
  assert_true(
    @semantics.suppresses_unknown_shell_warning(
      plain,
      None,
      Some("script.bash"),
      None,
    ),
  )
  assert_true(
    !@semantics.suppresses_unknown_shell_warning(
      plain,
      None,
      Some(".envrc"),
      None,
    ),
  )
  assert_eq(
    @semantics.determine_shell_with_fallback(plain, None, Some(".envrc"), None),
    @semantics.ShellDialect::Bash,
  )
  assert_eq(
    @semantics.determine_shell_with_fallback(
      plain,
      None,
      None,
      Some(@semantics.ShellDialect::Ksh),
    ),
    @semantics.ShellDialect::Ksh,
  )
  assert_true(
    @semantics.suppresses_unknown_shell_warning(
      plain,
      None,
      None,
      Some(@semantics.ShellDialect::Ksh),
    ),
  )
}

///|
test "shell dialect helpers parse shebangs annotations and filenames" {
  assert_eq(
    @semantics.shell_from_shebang("#!/usr/bin/env -S X=FOO bash -eu"),
    Some(@semantics.ShellDialect::Bash),
  )
  assert_eq(
    @semantics.shell_from_shebang("#!/usr/bin/env -S 'bash -eu'"),
    Some(@semantics.ShellDialect::Bash),
  )
  assert_eq(
    @semantics.shell_from_shebang(
      "#!/usr/bin/env --split-string='X=FOO bash -eu'",
    ),
    Some(@semantics.ShellDialect::Bash),
  )
  assert_eq(
    @semantics.shell_from_shebang("#!/usr/bin/env --split-string= dash -x"),
    Some(@semantics.ShellDialect::Dash),
  )
  assert_eq(
    @semantics.shell_from_shebang(
      "#!/usr/bin/env --split-string= X=FOO bash -eu",
    ),
    Some(@semantics.ShellDialect::Bash),
  )
  assert_eq(
    @semantics.shell_from_shebang("#!/bin/busybox ash"),
    Some(@semantics.ShellDialect::BusyboxSh),
  )
  assert_eq(@semantics.shell_from_shebang("#!/bin/unknownsh"), None)

  let annotated = parse_shell_ok(
    (
      #|# shellcheck shell="busybox ash"
      #|true
      #|
    ),
  )
  assert_eq(
    @semantics.shell_from_annotation(annotated.annotations),
    Some(@semantics.ShellDialect::BusyboxSh),
  )

  assert_eq(
    @semantics.shell_from_filename("script.ksh"),
    Some(@semantics.ShellDialect::Ksh),
  )
  assert_eq(
    @semantics.shell_from_filename("test.bash"),
    Some(@semantics.ShellDialect::Bash),
  )
  assert_eq(
    @semantics.shell_from_filename("test.bats"),
    Some(@semantics.ShellDialect::Bash),
  )
  assert_eq(
    @semantics.shell_from_filename("test.dash"),
    Some(@semantics.ShellDialect::Dash),
  )
  assert_eq(@semantics.shell_from_filename("test.sh"), None)
}

///|
test "shell option queries detect set and shopt toggles" {
  let enabled = parse_shell_ok(
    (
      #|#!/usr/bin/env bash -e
      #|set -eo pipefail
      #|shopt -s lastpipe inherit_errexit execfail
      #|
    ),
  )
  assert_true(@semantics.has_set_e(enabled))
  assert_true(@semantics.has_pipefail(enabled))
  assert_true(@semantics.has_lastpipe(enabled, @semantics.ShellDialect::Bash))
  assert_true(
    @semantics.has_inherit_errexit(enabled, @semantics.ShellDialect::Bash),
  )
  assert_true(@semantics.has_execfail(enabled, @semantics.ShellDialect::Bash))

  let disabled = parse_shell_ok(
    (
      #|set +e
      #|set -o nounset
      #|shopt -u lastpipe execfail inherit_errexit
      #|
    ),
  )
  assert_true(!@semantics.has_set_e(disabled))
  assert_true(!@semantics.has_pipefail(disabled))
  assert_true(!@semantics.has_lastpipe(disabled, @semantics.ShellDialect::Bash))
  assert_true(
    !@semantics.has_inherit_errexit(disabled, @semantics.ShellDialect::Bash),
  )
  assert_true(!@semantics.has_execfail(disabled, @semantics.ShellDialect::Bash))

  let reordered = parse_shell_ok(
    (
      #|set -oe pipefail
      #|
    ),
  )
  assert_true(@semantics.has_set_e(reordered))
  assert_true(@semantics.has_pipefail(reordered))
}

///|
test "shell option queries detect set -e through env split-string shebangs" {
  let split_string = parse_shell_ok(
    (
      #|#!/usr/bin/env -S 'X=FOO bash -e'
      #|true
      #|
    ),
  )
  assert_true(@semantics.has_set_e(split_string))

  let split_equals = parse_shell_ok(
    (
      #|#!/usr/bin/env --split-string='X=FOO bash -e'
      #|true
      #|
    ),
  )
  assert_true(@semantics.has_set_e(split_equals))

  let split_equals_empty = parse_shell_ok(
    (
      #|#!/usr/bin/env --split-string= X=FOO bash -e
      #|true
      #|
    ),
  )
  assert_true(@semantics.has_set_e(split_equals_empty))

  let no_flag = parse_shell_ok(
    (
      #|#!/usr/bin/env -S 'X=FOO bash -u'
      #|true
      #|
    ),
  )
  assert_true(!@semantics.has_set_e(no_flag))
}

///|
test "shebang option queries stop at shell end-of-options and operands" {
  let end_of_options = parse_shell_ok(
    (
      #|#!/usr/bin/env -S bash -- -e
      #|true
      #|
    ),
  )
  assert_true(!@semantics.has_set_e(end_of_options))

  let shell_operand = parse_shell_ok(
    (
      #|#!/usr/bin/env -S bash script.sh -e
      #|true
      #|
    ),
  )
  assert_true(!@semantics.has_set_e(shell_operand))

  let command_string = parse_shell_ok(
    (
      #|#!/usr/bin/env -S bash -c true -e
      #|
    ),
  )
  assert_true(!@semantics.has_set_e(command_string))
}

///|
test "shell option queries detect shebang long options for set and shopt" {
  let script = parse_shell_ok(
    (
      #|#!/usr/bin/env -S bash -o pipefail -O lastpipe -O inherit_errexit -O execfail
      #|true
      #|
    ),
  )
  assert_true(@semantics.has_pipefail(script))
  assert_true(@semantics.has_lastpipe(script, @semantics.ShellDialect::Bash))
  assert_true(
    @semantics.has_inherit_errexit(script, @semantics.ShellDialect::Bash),
  )
  assert_true(@semantics.has_execfail(script, @semantics.ShellDialect::Bash))
}

///|
test "shell option queries treat quoted builtin flags as real options" {
  let script = parse_shell_ok(
    (
      #|set "-e"
      #|set "-o" pipefail
      #|shopt "-s" lastpipe inherit_errexit execfail
      #|
    ),
  )
  assert_true(@semantics.has_set_e(script))
  assert_true(@semantics.has_pipefail(script))
  assert_true(@semantics.has_lastpipe(script, @semantics.ShellDialect::Bash))
  assert_true(
    @semantics.has_inherit_errexit(script, @semantics.ShellDialect::Bash),
  )
  assert_true(@semantics.has_execfail(script, @semantics.ShellDialect::Bash))
}

///|
test "shell option queries stop parsing after positional operands" {
  let script = parse_shell_ok(
    (
      #|set foo -e
      #|set foo -o pipefail
      #|shopt lastpipe -s inherit_errexit execfail
      #|
    ),
  )
  assert_true(!@semantics.has_set_e(script))
  assert_true(!@semantics.has_pipefail(script))
  assert_true(!@semantics.has_lastpipe(script, @semantics.ShellDialect::Bash))
  assert_true(
    !@semantics.has_inherit_errexit(script, @semantics.ShellDialect::Bash),
  )
  assert_true(!@semantics.has_execfail(script, @semantics.ShellDialect::Bash))
}

///|
test "shell option queries ignore deferred and isolated scopes" {
  let scoped = parse_shell_ok(
    (
      #|f() { set -e; set -o pipefail; shopt -s lastpipe inherit_errexit execfail; }
      #|(set -e; set -o pipefail; shopt -s lastpipe inherit_errexit execfail)
      #|printf '%s\n' "$(set -e; set -o pipefail; shopt -s lastpipe inherit_errexit execfail)"
      #|
    ),
  )
  assert_true(!@semantics.has_set_e(scoped))
  assert_true(!@semantics.has_pipefail(scoped))
  assert_true(!@semantics.has_lastpipe(scoped, @semantics.ShellDialect::Bash))
  assert_true(
    !@semantics.has_inherit_errexit(scoped, @semantics.ShellDialect::Bash),
  )
  assert_true(!@semantics.has_execfail(scoped, @semantics.ShellDialect::Bash))
}

///|
test "shell option queries keep current-shell compound commands" {
  let current_shell = parse_shell_ok(
    (
      #|{ set -e; set -o pipefail; shopt -s -- lastpipe inherit_errexit execfail; }
      #|
    ),
  )
  assert_true(@semantics.has_set_e(current_shell))
  assert_true(@semantics.has_pipefail(current_shell))
  assert_true(
    @semantics.has_lastpipe(current_shell, @semantics.ShellDialect::Bash),
  )
  assert_true(
    @semantics.has_inherit_errexit(current_shell, @semantics.ShellDialect::Bash),
  )
  assert_true(
    @semantics.has_execfail(current_shell, @semantics.ShellDialect::Bash),
  )
}

///|
test "shell option queries include sourced files in current-shell state" {
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
          #|set -e
          #|set -o pipefail
          #|shopt -s lastpipe inherit_errexit execfail
          #|
        ),
      ),
    ],
  )
  let script = parse_shell_with_options(
    (
      #|. lib.sh
      #|
    ),
    options,
  )
  assert_true(@semantics.has_set_e(script))
  assert_true(@semantics.has_pipefail(script))
  assert_true(@semantics.has_lastpipe(script, @semantics.ShellDialect::Bash))
  assert_true(
    @semantics.has_inherit_errexit(script, @semantics.ShellDialect::Bash),
  )
  assert_true(@semantics.has_execfail(script, @semantics.ShellDialect::Bash))
}

///|
test "shopt double dash stops option parsing before operands" {
  let script = parse_shell_ok(
    (
      #|shopt -- -s lastpipe
      #|
    ),
  )
  assert_true(!@semantics.has_lastpipe(script, @semantics.ShellDialect::Bash))
}

///|
test "shell option defaults follow shell dialect semantics" {
  let script = parse_shell_ok(
    (
      #|true
      #|
    ),
  )
  assert_true(!@semantics.has_lastpipe(script, @semantics.ShellDialect::Bash))
  assert_true(@semantics.has_lastpipe(script, @semantics.ShellDialect::Ksh))
  assert_true(
    @semantics.has_inherit_errexit(script, @semantics.ShellDialect::Sh),
  )
  assert_true(
    @semantics.has_inherit_errexit(script, @semantics.ShellDialect::Dash),
  )
  assert_true(
    @semantics.has_inherit_errexit(script, @semantics.ShellDialect::BusyboxSh),
  )
  assert_true(
    !@semantics.has_inherit_errexit(script, @semantics.ShellDialect::Ksh),
  )
  assert_true(!@semantics.has_execfail(script, @semantics.ShellDialect::Dash))
}

///|
test "execution mode defaults to executed and sourced when requested" {
  assert_eq(
    @semantics.effective_execution_mode(),
    @semantics.ExecutionMode::Executed,
  )
  assert_eq(
    @semantics.effective_execution_mode(sourced=true),
    @semantics.ExecutionMode::Sourced,
  )
  assert_eq(
    @semantics.effective_execution_mode(
      mode_override=@semantics.ExecutionMode::Executed,
      sourced=true,
    ),
    @semantics.ExecutionMode::Executed,
  )
}
