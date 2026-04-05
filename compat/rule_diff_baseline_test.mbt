///|
test "phase 2 entry semantics align for SC2148" {
  assert_diagnostics_match(
    "SC2148",
    "echo hello\n",
    [
      shellcheck_error(
        2148, 1, 1, "Tips depend on target shell and yours is unknown. Add a shebang or a 'shell' directive.",
      ),
    ],
    spec=@checker.CheckSpec::default(),
  )

  assert_diagnostics_match(
    "SC2148 filename suffix suppresses unknown shell for bash",
    "echo hello\n",
    [],
    spec=@checker.CheckSpec::default().with_filename(Some("script.bash")),
  )

  assert_diagnostics_match(
    "SC2148 envrc still warns while keeping bash semantics",
    "echo hello\n",
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
    "# shellcheck disable=SC2154\necho \"$foo\" | wc -c\n",
    [shellcheck_style(2000, 2, 1, "See if you can use ${#variable} instead.")],
  )

  assert_diagnostics_match("SC2087", "ssh host <<EOF2\necho $HOME\nEOF2\n", [
    shellcheck_warning(
      2087, 1, 12, "Quote 'EOF2' to make here document expansions happen on the server side rather than on the client.",
    ),
  ])
}

///|
test "phase 4 command alignment closes command-specialized gaps" {
  assert_diagnostics_match(
    "SC2174/SC2029/SC2114/SC2318",
    "#!/bin/bash\n# shellcheck disable=SC2154,SC2086,SC2034,SC2329\nmkdir -p -m 0755 a/b\nssh host \"echo $PS1\"\nrm -rf /home\nq() { local x=1 y=$x; }\n",
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
    "#!/bin/sh\ntime -p foo | bar\n",
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
    "#!/bin/bash\n# shellcheck disable=SC2034\nlocal foo=3\n",
    [shellcheck_error(2168, 3, 1, "'local' is only valid in functions.")],
  )
}
