///|
fn run() -> Unit raise {
  let db = @rra.Store::new(1, [
    @rra.Spec::new(1, 1440, Last),
    @rra.Spec::new(60, 720, Average),
  ])
  for t = 1; t <= 50000; t = t + 1 {
    db.update(t.to_int64(), Some((t % 100).to_double()))
  }
  let plateau = db.snapshot().length()
  let start = @env.now()
  for t = 50001; t <= 1050000; t = t + 1 {
    db.update(t.to_int64(), Some((t % 100).to_double()))
  }
  let elapsed = @env.now() - start
  let bytes = db.snapshot()
  assert_eq(db.retained(), 2160)
  assert_eq(bytes.length(), plateau)
  assert_eq(@rra.Store::restore(bytes).snapshot(), bytes)
  println(
    "updates=1000000 elapsed_ms=\{elapsed} retained=\{db.retained()} snapshot_bytes=\{bytes.length()}",
  )
}

///|
fn main {
  run() catch {
    e => {
      println(e)
      panic()
    }
  }
}
