///|
test "analytics batch u flags pipeline pitfalls and line-based loop substitutions" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|ps aux | grep foo
      #|ls | grep foo
      #|ls | xargs rm
      #|ls | sort
      #|for f in $(cat foo); do printf '%s\n' "$f"; done
      #|find . | xargs rm
      #|grep foo file | wc -l
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2009), 1)
  assert_eq(count_code(diagnostics, 2010), 1)
  assert_eq(count_code(diagnostics, 2011), 1)
  assert_eq(count_code(diagnostics, 2012), 1)
  assert_eq(count_code(diagnostics, 2013), 1)
  assert_eq(count_code(diagnostics, 2038), 1)
  assert_eq(count_code(diagnostics, 2126), 1)
}

///|
test "analytics batch u flags find -exec pre-expansion and missing terminators" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|find . -exec echo $(date) \;
      #|find . -exec rm *.jpg \;
      #|find . -name '*.php' -exec rm {};
      #|
    ),
  )

  assert_eq(count_code(diagnostics, 2014), 2)
  assert_eq(count_code(diagnostics, 2067), 1)
}

///|
test "analytics batch u avoids known pipeline and find -exec false positives" {
  let diagnostics = check_source(
    (
      #|#!/bin/bash
      #|ps -p 123 | grep foo
      #|ls -N | sort
      #|find . -print0 | xargs -0 rm
      #|grep -o foo file | wc -l
      #|for f in $(printf '%s' foo); do printf '%s\n' "$f"; done
      #|find . -exec echo "$(date)" \;
      #|find . -exec echo {} \;
      #|
    ),
  )

  assert_true(!has_code(diagnostics, 2009))
  assert_true(!has_code(diagnostics, 2012))
  assert_true(!has_code(diagnostics, 2013))
  assert_true(!has_code(diagnostics, 2014))
  assert_true(!has_code(diagnostics, 2038))
  assert_true(!has_code(diagnostics, 2067))
  assert_true(!has_code(diagnostics, 2126))
}
