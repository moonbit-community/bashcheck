///|
fn append_analytics_batch_n_descriptions(
  descriptions : Array[CheckDescription],
) -> Unit {
  for description in analytics_batch_n_descriptions() {
    descriptions.push(description)
  }
}

///|
fn analytics_batch_n_descriptions() -> Array[CheckDescription] {
  [
    {
      code: 2314,
      severity: CheckSeverity::Error,
      category: "analytics",
      summary: "Bats ! commands do not fail the test unless they are wrapped with run.",
    },
    {
      code: 2315,
      severity: CheckSeverity::Style,
      category: "analytics",
      summary: "Bats ! conditions will stop failing once they are no longer the last command.",
    },
  ]
}

///|
fn run_analytics_batch_n_checks(
  script : @parser.Script,
  shell : @semantics.ShellDialect,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  ignore(shell)
  check_bats_test_does_not_use_negation(script, diagnostics)
}

///|
fn check_bats_test_does_not_use_negation(
  script : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  visit_script_commands(script, fn(command) {
    match command.kind {
      @parser.CommandKind::BatsTest({ body, .. }) =>
        check_bats_test_body_for_negation(body, diagnostics)
      _ => ()
    }
  })
}

///|
fn check_bats_test_body_for_negation(
  body : @parser.Script,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  let mut i = 0
  while i < body.items.length() {
    let item = body.items[i]
    if item.and_or.tail.length() == 0 && item.and_or.head.segments.length() > 0 {
      let first_segment = item.and_or.head.segments[0]
      if first_segment.bangs % 2 != 0 {
        check_bats_test_negated_pipeline(
          first_segment,
          first_segment.command.kind is @parser.CommandKind::Condition(_),
          i + 1 == body.items.length(),
          diagnostics,
        )
      }
    }
    i += 1
  }
}

///|
fn check_bats_test_negated_pipeline(
  segment : @parser.PipelineSegment,
  is_condition : Bool,
  is_last : Bool,
  diagnostics : Array[CheckDiagnostic],
) -> Unit {
  if is_condition {
    if is_last {
      push_diagnostic(
        diagnostics,
        span_prefix(segment.span, 1),
        CheckSeverity::Style,
        2315,
        "In Bats, ! will not fail the test if it is not the last command anymore. Fold the `!` into the conditional!",
      )
    } else {
      push_diagnostic(
        diagnostics,
        span_prefix(segment.span, 1),
        CheckSeverity::Error,
        2315,
        "In Bats, ! does not cause a test failure. Fold the `!` into the conditional!",
      )
    }
    return
  }
  if is_last {
    push_diagnostic_with_fix(
      diagnostics,
      span_prefix(segment.span, 1),
      CheckSeverity::Style,
      2314,
      "In Bats, ! will not fail the test if it is not the last command anymore. Use `run ! ` (on Bats >= 1.5.0) instead.",
      bats_run_fix(segment),
    )
  } else {
    push_diagnostic_with_fix(
      diagnostics,
      span_prefix(segment.span, 1),
      CheckSeverity::Error,
      2314,
      "In Bats, ! does not cause a test failure. Use 'run ! ' (on Bats >= 1.5.0) instead.",
      bats_run_fix(segment),
    )
  }
}

///|
fn bats_run_fix(segment : @parser.PipelineSegment) -> @fixer.Fix {
  @fixer.Fix::from_replacements([
    @fixer.Replacement::new(
      "",
      segment.span.start,
      segment.span.start,
      "run ",
      7,
      @fixer.InsertionPoint::after(),
    ),
  ])
}
