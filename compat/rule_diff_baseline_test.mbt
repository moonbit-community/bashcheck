///|
test "phase 2 entry semantics align for SC2148" {
  assert_diagnostics_match(
    "SC2148",
    (
      #|echo hello
      #|
    ),
    [
      shellcheck_error(
        2148, 1, 1, "Tips depend on target shell and yours is unknown. Add a shebang or a 'shell' directive.",
      ),
    ],
    spec=@checker.CheckSpec::default(),
  )

  assert_diagnostics_match(
    "SC2148 filename suffix suppresses unknown shell for bash",
    (
      #|echo hello
      #|
    ),
    [],
    spec=@checker.CheckSpec::default().with_filename(Some("script.bash")),
  )

  assert_diagnostics_match(
    "SC2148 envrc still warns while keeping bash semantics",
    (
      #|echo hello
      #|
    ),
    [
      shellcheck_error(
        2148, 1, 1, "Tips depend on target shell and yours is unknown. Add a shebang or a 'shell' directive.",
      ),
    ],
    spec=@checker.CheckSpec::default().with_filename(Some(".envrc")),
  )
}

///|
test "phase 3 analytics alignment closes SC2000 and SC2087 gaps" {
  assert_diagnostics_match(
    "SC2000",
    (
      #|# shellcheck disable=SC2154
      #|echo "$foo" | wc -c
      #|
    ),
    [shellcheck_style(2000, 2, 1, "See if you can use ${#variable} instead.")],
  )

  assert_diagnostics_match(
    "SC2087",
    (
      #|ssh host <<EOF2
      #|echo $HOME
      #|EOF2
      #|
    ),
    [
      shellcheck_warning(
        2087, 1, 12, "Quote 'EOF2' to make here document expansions happen on the server side rather than on the client.",
      ),
    ],
  )
}

///|
test "phase 4 command alignment closes command-specialized gaps" {
  assert_diagnostics_match(
    "SC2174/SC2029/SC2114/SC2318",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2154,SC2086,SC2034,SC2329
      #|mkdir -p -m 0755 a/b
      #|ssh host "echo $PS1"
      #|rm -rf /home
      #|q() { local x=1 y=$x; }
      #|
    ),
    [
      shellcheck_warning(
        2174, 3, 10, "When used with -p, -m only applies to the deepest directory.",
      ),
      shellcheck_info(
        2029, 4, 16, "Note that, unescaped, this expands on the client side.",
      ),
      shellcheck_warning(2114, 5, 8, "Warning: deletes a system directory."),
      shellcheck_warning(
        2318, 6, 13, "This assignment is used again in this 'local', but won't have taken effect. Use two 'local's.",
      ),
    ],
  )

  assert_diagnostics_match(
    "SC2176",
    (
      #|#!/bin/sh
      #|time -p foo | bar
      #|
    ),
    [
      shellcheck_warning(
        2176, 2, 1, "'time' is undefined for pipelines. time single stage or bash -c instead.",
      ),
    ],
    spec=@checker.CheckSpec::default().with_shell_override(
      Some(@semantics.ShellDialect::Sh),
    ),
  )

  assert_diagnostics_match(
    "SC2168",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034
      #|local foo=3
      #|
    ),
    [shellcheck_error(2168, 3, 1, "'local' is only valid in functions.")],
  )
}
