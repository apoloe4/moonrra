///|
/// Replay one closed batch: 10s step, 20s lateness, 128 series, 30 retained ticks.
pub fn replay(text : String) -> Array[String] raise {
  guard text.length() <= 4194304 else { fail("batch exceeds limit") }
  let db = @rra.Collector::new(
    10,
    [@rra.Spec::new(1, 30, Last)],
    lateness=20,
    max_series=128,
  )
  let mut lines = 0
  let mut late = 0
  let mut full = 0
  let mut ignored = 0
  for line in text.split("\n") {
    lines += 1
    if line.trim().is_empty() {
      continue
    }
    let samples = decode(line) catch { e => fail("line \{lines}: \{e}") }
    for s in samples {
      match db.observe(s.key, s.time, s.value) {
        TooLate => late += 1
        SeriesLimit => full += 1
        Superseded | Duplicate => ignored += 1
        Buffered | Replaced => ()
      }
    }
  }
  db.flush()
  let output : Array[String] = []
  for key in db.series() {
    for p in db.fetch(key, 0, 0L, 9000000000000000L) {
      let value = match p.value {
        Some(v) => v.to_string()
        None => "null"
      }
      output.push(
        "{\"series\":\{key},\"end\":\{p.timestamp},\"value\":\{value}}",
      )
    }
  }
  output.push(
    "{\"series_count\":\{db.series().length()},\"too_late\":\{late},\"series_limit\":\{full},\"ignored\":\{ignored}}",
  )
  output
}
