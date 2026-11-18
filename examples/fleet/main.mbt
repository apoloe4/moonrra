///|
/// Two sensors are required for a site mean. The third is registered in the roster but never reports.
fn main raise {
  let c = @rra.Collector::new(
    10,
    [@rra.Spec::new(1, 6, Last)],
    lateness=20,
    max_series=3,
  )
  ignore(c.observe("east", 17L, 24.0))
  ignore(c.observe("east", 8L, 20.0))
  ignore(c.observe("west", 9L, 22.0))
  c.advance("west", 20L)
  c.flush()
  for p in c.cohort(["east", "west", "north"], 0, 0L, 20L, min_reporting=2) {
    let average = match p.mean {
      Some(v) => v.to_string()
      None => "unknown"
    }
    println(
      "end=\{p.end} reporting=\{p.reporting} missing=\{p.missing} unavailable=\{p.unavailable} mean=\{average}",
    )
  }
}
