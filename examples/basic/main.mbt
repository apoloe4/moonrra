///|
fn run() -> Unit raise {
  let db = @rra.Store::new(60, [
    @rra.Spec::new(1, 1440, Last),
    @rra.Spec::new(60, 720, Average, min_known=30),
  ])
  for minute = 1; minute <= 120; minute = minute + 1 {
    db.update(minute.to_int64() * 60L, Some((100 + minute % 20).to_double()))
  }
  let restored = @rra.Store::restore(db.snapshot())
  assert_eq(restored.fetch(1, 0L, 7200L), db.fetch(1, 0L, 7200L))
  println("小时平均值: \{@debug.to_string(restored.fetch(1, 0L, 7200L))}")
  println(
    "已保留记录: \{restored.retained()}, 快照字节: \{db.snapshot().length()}",
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
