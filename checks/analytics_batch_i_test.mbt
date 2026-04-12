///|
test "analytics batch i flags concatenated array expansions" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|echo "foo$@"
      #|echo ${arr[@]}lol
      #|echo $a$@
      #|echo "$@"
      #|echo "${arr[@]}"
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2145), 3)
  assert_true(!has_code(diagnostics, 2295))
}

///|
test "analytics batch i flags unquoted parameter expansion patterns" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|echo ${var#$x}
      #|echo "${var#$x}"
      #|echo "${var#foo$x}"
      #|echo "${var[#$x]}"
      #|echo "${var%"$x"}"
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2295), 3)
  assert_true(!has_code(diagnostics, 2145))
}
