///|
test "fleet quorum distinguishes measured zero, dropout, expiry and absent host" {
  let c = Collector::new(10, [Spec::new(1, 2, Last)], lateness=0, max_series=3)
  for t in [10L, 20L, 30L] {
    ignore(c.observe("a", t, 0.0))
  }
  ignore(c.observe("b", 10L, 40.0))
  ignore(c.observe("b", 30L, 20.0))
  let rows = c.cohort(["a", "b", "never"], 0, 2L, 42L, min_reporting=2)
  assert_eq(rows.map(r => (r.reporting, r.missing, r.unavailable)), [
    (0, 0, 3),
    (1, 1, 1),
    (2, 0, 1),
    (0, 0, 3),
  ])
  assert_eq(rows.map(r => r.mean), [None, None, Some(10.0), None])
  let failed = try {
    ignore(c.cohort(["a", "a"], 0, 0L, 10L, min_reporting=2))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  let huge = try {
    ignore(c.cohort(["a"], 0, 0L, 9000000000000000L, min_reporting=1))
    false
  } catch {
    _ => true
  }
  assert_true(huge)
}
