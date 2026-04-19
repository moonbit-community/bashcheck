///|
test "compat regression covers condition operand expansion diagnostics" {
  assert_compat_case(
    "condition-operands-bash",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2068,SC2154,SC2157
      #|[ -f *.mp3 ]
      #|[[ -n ${arr[@]} ]]
      #|[ -n ${arr[@]} ]
      #|[ -n {a,b} ]
      #|[[ -n {a,b} ]]
      #|[ *.mp3 ]
      #|[[ *.mp3 ]]
      #|[ 6 -eq 2*3 ]
      #|[ -v *.mp3 ]
      #|
    ),
    [
      compat_error(
        2144, 3, 6, 11, "-f doesn't work with globs. Use a for loop.",
      ),
      compat_error(
        2199, 4, 7, 16, "Arrays implicitly concatenate in [[ ]]. Use a loop (or explicit * instead of @).",
      ),
      compat_warning(
        2198, 5, 6, 15, "Arrays don't work as operands in [ ]. Use a loop (or concatenate with * instead of @).",
      ),
      compat_error(
        2070, 6, 6, 11, "-n doesn't work with unquoted arguments. Quote or use [[ ]].",
      ),
      compat_warning(
        2200, 6, 6, 11, "Brace expansions don't work as operands in [ ]. Use a loop.",
      ),
      compat_error(
        2201, 7, 7, 12, "Brace expansion doesn't happen in [[ ]]. Use a loop.",
      ),
      compat_warning(
        2202, 8, 3, 8, "Globs don't work as operands in [ ]. Use a loop.",
      ),
      compat_error(
        2203, 9, 4, 9, "Globs are ignored in [[ ]] except right of =/!=. Use a loop.",
      ),
      compat_error(
        2255, 10, 9, 12, "[ ] does not apply arithmetic evaluation. Evaluate with $((..)) for numbers, or use string comparator for strings.",
      ),
      compat_error(
        2208, 11, 6, 11, "Use [[ ]] or quote arguments to -v to avoid glob expansion.",
      ),
    ],
  )
}

///|
test "compat regression covers ksh unary glob operand diagnostics" {
  assert_compat_case(
    "condition-operands-ksh",
    (
      #|#!/bin/ksh
      #|[ -f *.mp3 ]
      #|
    ),
    [
      compat_warning(
        2245, 2, 6, 11, "-f only applies to the first expansion of this glob. Use a loop to check any/all.",
      ),
    ],
  )
}
