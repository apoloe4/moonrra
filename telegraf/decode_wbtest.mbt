///|
test "identity survives tag reordering and preserves punctuation and field separation" {
  let first = decode(
    (
      #|{"name":"m","tags":{"b":"x,y","a":"="},"fields":{"g":0,"f":3,"note":"ok"},"timestamp":12}
    ),
  )
  let second = decode(
    (
      #|{"name":"m","tags":{"a":"=","b":"x,y"},"fields":{"f":4},"timestamp":13}
    ),
  )
  assert_eq(first.length(), 2)
  assert_eq(first[0].key, second[0].key)
  assert_true(first[0].key != first[1].key)
  assert_eq(first[1].value, 0.0)
}

///|
test "reject malformed shape, ambiguous keys and fractional time" {
  for
    s in [
      (
        #|{"name":"m","fields":{"a":1},"tags":{},"timestamp":1.5}
      ),
      (
        #|{"name":"m","fields":{"a":1,"a":2},"tags":{},"timestamp":3}
      ),
      (
        #|{"name":"m","fields":{"a":1},"tags":{"host":4},"timestamp":3}
      ),
      (
        #|{"metrics":[]}
      ),
      (
        #|{"name":"m","fields":{"msg":"ok"},"tags":{},"timestamp":3}
      ),
    ] {
    let failed = try {
      ignore(decode(s))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}
