///|
test "window admits reordered ticks, freezes boundaries and handles replay" {
  let c = Collector::new(10, [Spec::new(1, 8, Last)], lateness=20, max_series=2)
  assert_eq(c.observe("a", 27L, 1.0), Buffered)
  assert_eq(c.observe("a", 8L, 8.0), Buffered)
  assert_eq(c.observe("a", 9L, 9.0), Replaced)
  assert_eq(c.observe("a", 9L, 99.0), Duplicate)
  assert_eq(c.observe("a", 7L, 7.0), Superseded)
  assert_eq(c.fetch("a", 0, 0L, 30L).length(), 0)
  assert_eq(c.observe("a", 30L, 3.0), Replaced)
  assert_eq(c.observe("a", 10L, 1.0), TooLate)
  assert_eq(c.fetch("a", 0, 0L, 30L).map(p => p.value), [Some(9.0)])
  c.flush()
  c.flush()
  assert_eq(c.fetch("a", 0, 0L, 30L).map(p => p.value), [
    Some(9.0),
    None,
    Some(3.0),
  ])
}

///|
test "independent series, explicit idle advancement, capacity without eviction" {
  let c = Collector::new(10, [Spec::new(1, 8, Last)], lateness=0, max_series=2)
  ignore(c.observe("remote", 200L, 2.0))
  assert_eq(c.observe("local", 3L, 0.0), Buffered)
  assert_eq(c.observe("third", 1L, 0.0), SeriesLimit)
  c.advance("local", 39L)
  assert_eq(c.fetch("local", 0, 0L, 40L).map(p => p.value), [
    Some(0.0),
    None,
    None,
  ])
  assert_eq(c.observe("local", 30L, 2.0), TooLate)
  assert_eq(c.observe("local", 31L, 2.0), Buffered)
  assert_eq(c.series(), ["local", "remote"])
}

///|
test "large gaps and invalid observations do not consume unbounded slots" {
  let c = Collector::new(7, [Spec::new(1, 4, Last)], lateness=14, max_series=1)
  for bad in [0L, 9000000000000000L] {
    let failed = try {
      ignore(c.observe("bad", bad, 0.0))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  for i = 1; i < 500; i = i + 1 {
    ignore(c.observe("ok", i.to_int64(), i.to_double()))
    assert_true(c.tracks["ok"].pending.length() <= 3)
  }
  c.advance("ok", 7000000000000L)
  assert_eq(c.fetch("ok", 0, 0L, 7000000000000L).map(p => p.value), [
    None,
    None,
    None,
    None,
  ])
}
