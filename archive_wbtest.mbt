///|
test "aggregation and independent levels" {
  let db = Store::new(60, [
    Spec::new(1, 2, Last),
    Spec::new(3, 3, Average),
    Spec::new(3, 3, Minimum),
    Spec::new(3, 3, Maximum),
  ])
  db.update(60L, Some(2.0))
  db.update(120L, Some(8.0))
  db.update(180L, Some(5.0))
  assert_eq(db.fetch(0, 0L, 180L).map(p => p.value), [Some(8.0), Some(5.0)])
  assert_eq(db.fetch(1, 0L, 180L)[0].value, Some(5.0))
  assert_eq(db.fetch(2, 0L, 180L)[0].value, Some(2.0))
  assert_eq(db.fetch(3, 0L, 180L)[0].value, Some(8.0))
}

///|
test "missing slots do not become zero" {
  let db = Store::new(1, [
    Spec::new(3, 4, Average, min_known=2),
    Spec::new(3, 4, Last),
  ])
  db.update(1L, Some(6.0))
  db.update(3L, None)
  assert_eq(db.fetch(0, 0L, 3L)[0].value, None)
  assert_eq(db.fetch(1, 0L, 3L)[0].value, Some(6.0))
  db.update(4L, Some(0.0))
  db.update(6L, Some(4.0))
  assert_eq(db.fetch(0, 3L, 6L)[0].value, Some(2.0))
}

///|
test "huge gap has bounded work and retention" {
  let db = Store::new(1, [Spec::new(1, 4, Average), Spec::new(60, 3, Maximum)])
  db.update(1L, Some(1.0))
  db.update(9000000000000000L, Some(2.0))
  assert_eq(db.retained(), 7)
  let points = db.fetch(0, 0L, db.latest())
  assert_eq(points[0].timestamp, 8999999999999997L)
  assert_eq(points[0].value, None)
  assert_eq(points[3].value, Some(2.0))
}

///|
test "invalid updates are atomic" {
  let db = Store::new(60, [Spec::new(1, 4, Last)])
  db.update(60L, Some(1.0))
  let before = db.snapshot()
  for t in [0L, 60L, 59L, 121L, 9000000000000060L] {
    let failed = try {
      db.update(t, Some(9.0))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    assert_eq(db.snapshot(), before)
  }
  let failed = try {
    db.update(120L, Some(0.0 / 0.0))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(db.snapshot(), before)
}

///|
test "snapshot preserves partial aggregation and independent ownership" {
  let db = Store::new(1, [Spec::new(3, 2, Average, min_known=2)])
  db.update(1L, Some(2.0))
  let restored = Store::restore(db.snapshot())
  db.update(3L, Some(8.0))
  restored.update(3L, Some(8.0))
  assert_eq(restored.snapshot(), db.snapshot())
  restored.update(6L, Some(10.0))
  assert_eq(db.latest(), 3L)
}

///|
test "empty and wrapped snapshots are canonical" {
  let db = Store::new(1, [Spec::new(2, 3, Last)])
  assert_eq(Store::restore(db.snapshot()).snapshot(), db.snapshot())
  for t = 1; t <= 20; t = t + 1 {
    db.update(t.to_int64(), Some(t.to_double()))
  }
  assert_eq(Store::restore(db.snapshot()).snapshot(), db.snapshot())
}

///|
test "every truncated snapshot is rejected" {
  let db = Store::new(1, [Spec::new(1, 4, Last)])
  db.update(1L, Some(3.0))
  let bytes = db.snapshot()
  for n = 0; n < bytes.length(); n = n + 1 {
    let cut = Bytes::makei(n, i => bytes[i])

    assert_true(
      try {
        ignore(Store::restore(cut))
        false
      } catch {
        _ => true
      },
    )
  }
  for i = 0; i < bytes.length(); i = i + 1 {
    let damaged = Bytes::makei(bytes.length(), j => {
      if j == i {
        (bytes[j].to_int() ^ 1).to_byte()
      } else {
        bytes[j]
      }
    })

    assert_true(
      try {
        ignore(Store::restore(damaged))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "batch oracle agrees with streaming archives over gaps and wraps" {
  for factor in [1, 2, 7, 19] {
    for aggregation in [Average, Minimum, Maximum, Last] {
      let db = Store::new(1, [
        Spec::new(factor, 5, aggregation, min_known=factor / 2 + 1),
      ])
      let raw : Array[Double?] = []
      for t = 1; t <= 400; t = t + 1 {
        let value = if t % 7 == 0 || t % 11 == 0 {
          None
        } else {
          Some((t % 23 - 11).to_double())
        }
        raw.push(value)
        // Even-numbered missing ticks are skipped, exercising automatic gaps.
        if value != None || t % 2 != 0 || t == 400 {
          db.update(t.to_int64(), value)
        }
        if t % factor == 0 && db.latest() == t.to_int64() {
          let values : Array[Double] = []
          for k = t - factor; k < t; k = k + 1 {
            if raw[k] is Some(v) {
              values.push(v)
            }
          }
          let actual = db.fetch(0, (t - factor).to_int64(), t.to_int64())[0].value
          if values.length() < factor / 2 + 1 {
            assert_eq(actual, None)
          } else {
            let mut sum = 0.0
            let mut low = values[0]
            let mut high = values[0]
            for v in values {
              sum += v
              if v < low {
                low = v
              }
              if v > high {
                high = v
              }
            }
            let expected = match aggregation {
              Average => sum / values.length().to_double()
              Minimum => low
              Maximum => high
              Last => values[values.length() - 1]
            }
            match actual {
              Some(v) => assert_true((v - expected).abs() < 0.000000001)
              None => fail("unexpected missing bucket")
            }
          }
        }
        assert_true(db.retained() <= 5)
        if t % 37 == 0 {
          assert_eq(Store::restore(db.snapshot()).snapshot(), db.snapshot())
        }
      }
    }
  }
}

///|
test "counter reset and explicit wrap" {
  assert_eq(counter32_rate(100U, 160U, 60), Some(1.0))
  assert_eq(counter32_rate(100U, 10U, 60), None)
  assert_eq(counter32_rate(4294967290U, 4U, 2, wrap=true), Some(5.0))
  assert_true(
    try {
      ignore(counter32_rate(1U, 2U, 0))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "coverage and interval endpoints" {
  let db = Store::new(60, [Spec::new(1, 2, Last)])
  assert_eq(db.info(0).oldest, None)
  for t in [60L, 120L, 180L] {
    db.update(t, Some(1.0))
  }
  assert_eq(db.info(0).oldest, Some(120L))
  assert_eq(db.info(0).newest, Some(180L))
  assert_eq(db.fetch(0, 120L, 180L).length(), 1)
  assert_eq(db.fetch(0, 180L, 180L).length(), 0)
}

///|
test "configuration and range errors" {
  for factor in [0, -1, 1000001] {
    assert_true(
      try {
        ignore(Spec::new(factor, 1, Last))
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      ignore(Spec::new(2, 1, Last, min_known=3))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(Store::new(0, []))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(
        Store::new(1, [Spec::new(1, 1000000, Last), Spec::new(1, 1, Last)]),
      )
      false
    } catch {
      _ => true
    },
  )
  let db = Store::new(1, [Spec::new(1, 1, Last)])
  assert_true(
    try {
      ignore(db.fetch(-1, 0L, 1L))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(db.fetch(0, 2L, 1L))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "large finite values do not overflow average" {
  let db = Store::new(1, [Spec::new(2, 2, Average)])
  db.update(1L, Some(1.7e308))
  db.update(2L, Some(1.7e308))
  assert_eq(db.fetch(0, 0L, 2L)[0].value, Some(1.7e308))
}

///|
test "forged semantic fields fail even with recomputed checksum" {
  let db = Store::new(1, [Spec::new(2, 3, Last)])
  db.update(1L, Some(2.0))
  let bytes = db.snapshot()
  for offset in [0, 8, 16, 24, 32, 40, 48, 56, 64, 72, 80, 120] {
    let body = Bytes::makei(bytes.length() - 8, i => {
      if i >= offset && i < offset + 8 {
        255
      } else {
        bytes[i]
      }
    })
    let b = @buffer.Buffer()
    b.write_bytes(body)
    b.write_int64_le(checksum(body, body.length()).to_int64())
    assert_true(
      try {
        ignore(Store::restore(b.to_bytes()))
        false
      } catch {
        _ => true
      },
    )
  }
}
