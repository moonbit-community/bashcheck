///|
test "command batch d flags echo escape sequences but respects echo -e" {
  let diagnostics = check_source(
    (
      #|echo "\\n"
      #|echo '\n'
      #|echo $'\n'
      #|echo -e "\\n"
      #|echo "\""
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2028), 3)
  assert_eq(
    first_code(diagnostics, 2028).message,
    "echo may not expand escape sequences. Use printf.",
  )
}

///|
test "command batch d flags declaration assignments that mask return values" {
  let diagnostics = check_source(
    (
      #|f() {
      #|  local x=$(false)
      #|  export y=$(false)
      #|  readonly z=$(false)
      #|  declare a=$(false)
      #|  typeset b=$(false)
      #|  local plain=1
      #|  local ref="$HOME"
      #|}
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2155), 5)
  assert_eq(
    first_code(diagnostics, 2155).message,
    "Declare and assign separately to avoid masking return values.",
  )
}

///|
test "command batch d flags trap signal numbers and untrappable signals" {
  let diagnostics = check_source(
    (
      #|trap foo 16 63
      #|trap foo KILL STOP 9
      #|trap foo INT TERM 15
      #|trap - 16
      #|trap -- 'echo hi' 16
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2172), 2)
  assert_eq(count_code(diagnostics, 2173), 3)
  assert_eq(
    first_code(diagnostics, 2172).message,
    "Trapping signals by number is not well defined. Prefer signal names.",
  )
  assert_eq(
    first_code(diagnostics, 2173).message,
    "SIGKILL/SIGSTOP can not be trapped.",
  )
}
