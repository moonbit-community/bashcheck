///|
test "shell knowledge tables expose shellcheck test operators and sample words" {
  let sample_words = @semantics.sample_words()

  assert_true(sample_words.contains("alpha"))
  assert_true(sample_words.contains("zulu"))
}
