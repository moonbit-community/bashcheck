///|
test "compat regression covers phase b char class and comparison analytics diagnostics" {
  assert_compat_case(
    "phase-b-char-class-and-comparison-analytics",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2035,SC2203,SC2215
      #|ls *[:digit:].jpg
      #|ls [10-15]
      #|if -z n ]]; then true; fi
      #|[[ *.png == [a-z] ]]
      #|
    ),
    [
      compat_warning(
        2101, 3, 5, 14, "Named class needs outer [], e.g. [[:digit:]].",
      ),
      compat_info(
        2102, 4, 4, 11, "Ranges can only match single chars (mentioned due to duplicates).",
      ),
      compat_warning(
        2171, 5, 9, 11, "Found trailing ]] outside test. Add missing [[ or quote if intentional.",
      ),
      compat_warning(
        2193, 6, 10, 12, "The arguments to this comparison can never be equal. Make sure your syntax is correct.",
      ),
    ],
  )
}

///|
test "compat regression covers phase b loop keyword scope analytics diagnostics" {
  assert_compat_case(
    "phase-b-loop-keyword-scope-analytics",
    (
      #|#!/bin/bash
      #|# shellcheck disable=SC2034,SC2043
      #|continue 2
      #|foo() { break; }
      #|if true; then continue; fi
      #|for f in a; do ( break; ); done
      #|while true; do true | { break; }; done
      #|
    ),
    [
      compat_error(2105, 3, 1, 11, "continue is only valid in loops."),
      compat_error(2104, 4, 9, 14, "In functions, use return instead of break."),
      compat_error(2105, 5, 15, 23, "continue is only valid in loops."),
      compat_warning(
        2106, 6, 18, 23, "This only exits the subshell caused by the (..) group.",
      ),
      compat_warning(
        2106, 7, 25, 30, "This only exits the subshell caused by the pipeline.",
      ),
    ],
  )
}
