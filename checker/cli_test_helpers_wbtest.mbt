///|
fn test_check_script(
  source : String,
  spec~ : CheckSpec = CheckSpec::default(),
) -> CheckResult {
  check_prepared_script(source, prepare_script(source, spec~), spec~)
}
