///|
test "shell knowledge tables expose variable categories" {
  let internal = @semantics.internal_variable_names()
  let spaced = @semantics.variable_names_without_spaces()
  let special = @semantics.special_variable_names()
  let unbraced = @semantics.unbraced_variable_names()
  let arrays = @semantics.array_variable_names()

  assert_true(internal.contains("PWD"))
  assert_true(internal.contains("BASH_REMATCH"))
  assert_true(internal.contains(".sh.version"))
  assert_true(internal.contains("stderr_lines"))
  assert_true(@semantics.is_internal_variable("PIPESTATUS"))

  assert_eq(@semantics.special_integer_variable_names(), ["$", "?", "!", "#"])
  assert_true(@semantics.is_special_integer_variable("?"))

  assert_true(spaced.contains("RANDOM"))
  assert_true(@semantics.is_variable_without_spaces("FLAGS_TRUE"))
  assert_true(@semantics.is_special_variable_without_spaces("$"))

  assert_true(special.contains("@"))
  assert_true(@semantics.is_special_variable("*"))

  assert_true(unbraced.contains("9"))
  assert_true(@semantics.is_unbraced_variable("0"))

  assert_true(arrays.contains("PIPESTATUS"))
  assert_true(@semantics.is_array_variable("COMPREPLY"))
  assert_true(!@semantics.is_array_variable("PWD"))
}

///|
test "shell knowledge tables expose command metadata" {
  let common = @semantics.common_command_names()
  let non_reading = @semantics.non_reading_command_names()
  let declaring = @semantics.declaring_command_names()

  assert_true(common.contains("pwd"))
  assert_true(common.contains("zcat"))
  assert_true(@semantics.is_common_command("readonly"))

  assert_true(non_reading.contains("printf"))
  assert_true(@semantics.is_non_reading_command("trap"))
  assert_true(!@semantics.is_non_reading_command("grep"))

  assert_true(declaring.contains("readonly"))
  assert_true(@semantics.is_declaring_command("let"))

  assert_eq(@semantics.read_option_spec(), "sred:u:n:N:i:p:a:t:")
  assert_true(@semantics.read_flag_takes_argument('d'))
  assert_true(@semantics.read_flag_takes_argument('t'))
  assert_true(!@semantics.read_flag_takes_argument('r'))

  assert_eq(@semantics.mapfile_option_spec(), "d:n:O:s:u:C:c:t")
  assert_true(@semantics.mapfile_flag_takes_argument('C'))
  assert_true(!@semantics.mapfile_flag_takes_argument('t'))
}

///|
test "shell knowledge tables expose shellcheck test operators and sample words" {
  let sample_words = @semantics.sample_words()

  assert_true(sample_words.contains("alpha"))
  assert_true(sample_words.contains("zulu"))

  assert_true(@semantics.is_binary_test_operator("=="))
  assert_true(@semantics.is_binary_test_operator("\\<="))
  assert_true(!@semantics.is_binary_test_operator("-v"))

  assert_true(@semantics.is_arithmetic_binary_test_operator("-eq"))
  assert_true(!@semantics.is_arithmetic_binary_test_operator("=~"))

  assert_true(@semantics.is_unary_test_operator("-v"))
  assert_true(@semantics.is_unary_test_operator("-R"))
  assert_true(!@semantics.is_unary_test_operator("-eq"))
}
