///|
fn run() -> Unit raise {
  let db = @rra.Store::new(60, [@rra.Spec::new(5, 288, Average, min_known=3)])
  db.update(60L, Some(20.0))
  db.update(120L, Some(22.0))
  db.update(300L, None)
  assert_eq(db.fetch(0, 0L, 300L)[0].value, None)
  db.update(360L, Some(21.0))
  let restored = @rra.Store::restore(db.snapshot())
  restored.update(420L, Some(22.0))
  restored.update(600L, Some(23.0))
  assert_eq(restored.fetch(0, 300L, 600L)[0].value, Some(22.0))
  println(
    "缺测与恢复结果: \{@debug.to_string(restored.fetch(0, 0L, 600L))}",
  )
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
