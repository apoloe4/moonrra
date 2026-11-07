///|
fn run() -> Unit raise {
  let db = @rra.Store::new(60, [
    @rra.Spec::new(1, 60, Last),
    @rra.Spec::new(2, 30, Maximum),
  ])
  db.update(60L, @rra.counter32_rate(1000U, 7000U, 60))
  db.update(120L, @rra.counter32_rate(7000U, 19000U, 60))
  db.update(180L, @rra.counter32_rate(19000U, 100U, 60))
  assert_eq(db.fetch(0, 120L, 180L)[0].value, None)
  assert_eq(db.fetch(1, 0L, 120L)[0].value, Some(200.0))
  println("流量峰值 bytes/s: \{@debug.to_string(db.fetch(1, 0L, 180L))}")
}

///|
fn main {
  run() catch {
    error => {
      println(error)
      panic()
    }
  }
}
