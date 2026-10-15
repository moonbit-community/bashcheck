///|
fn test_check_script(
  source : String,
  spec~ : @checker.CheckSpec = @checker.CheckSpec::default(),
) -> @checker.CheckResult {
  @checker.check_prepared_script(
    source,
    @checker.prepare_script(source, spec~),
    spec~,
  )
}
