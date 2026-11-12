///|
fn main {
  try {
    let methods : Array[@rra.Consolidation] = [Average, Minimum, Maximum, Last]
    let names = ["AVERAGE", "MIN", "MAX", "LAST"]
    for index = 0; index < 4; index = index + 1 {
      let db = @rra.Store::new(60, [
        @rra.Spec::new(3, 8, methods[index], min_known=2),
      ])
      for tick = 1; tick <= 12; tick = tick + 1 {
        db.update(
          1800000000L + tick.to_int64() * 60L,
          if tick == 4 || tick == 10 || tick == 11 {
            None
          } else {
            Some(tick.to_double())
          },
        )
      }
      for point in db.fetch(0, 1800000000L, 1800000720L) {
        let value = match point.value {
          Some(v) => v.to_string()
          None => "U"
        }
        println("\{names[index]},\{point.timestamp},\{value}")
      }
    }
  } catch {
    error => {
      println(@debug.to_string(error))
      panic()
    }
  }
}
