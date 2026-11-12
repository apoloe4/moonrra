///|
async test "save load continue replace and reject failures" {
  let dir = @fs.tmpdir(prefix="moonrra-test-")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/samples.rra"
  let store = @rra.Store::new(1, [@rra.Spec::new(2, 3, Average)])
  store.update(1L, Some(10.0))
  save(store, path)
  let restored = load(path)
  restored.update(2L, Some(20.0))
  save(restored, path)
  assert_eq(load(path).fetch(0, 0L, 2L)[0].value, Some(15.0))
  assert_true(
    try {
      ignore(load(path, max_bytes=48))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(load(dir + "/missing"))
      false
    } catch {
      _ => true
    },
  )
  @fs.write_file(path + ".tmp", "owned by another writer")
  assert_true(
    try {
      save(store, path)
      false
    } catch {
      _ => true
    },
  )
  assert_eq(load(path).latest(), 2L)
  assert_eq(@fs.read_file(path + ".tmp").text(), "owned by another writer")
  @fs.remove(path + ".tmp")
  @fs.write_file(path, "bad snapshot")
  assert_true(
    try {
      ignore(load(path))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      save(store, dir + "/absent/sample")
      false
    } catch {
      _ => true
    },
  )
}
