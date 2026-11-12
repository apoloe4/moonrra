///|
async fn main {
  let dir = @fs.tmpdir(prefix="moonrra-example-")
  defer @fs.rmdir(dir, recursive=true)
  let path = dir + "/metrics.rra"
  let db = @rra.Store::new(60, [@rra.Spec::new(2, 30, Average)])
  db.update(60L, Some(10.0))
  @storage.save(db, path)
  let reopened = @storage.load(path)
  reopened.update(120L, Some(20.0))
  @storage.save(reopened, path)
  assert_eq(@storage.load(path).fetch(0, 0L, 120L)[0].value, Some(15.0))
  println("Disk save, reopen, continue, replace: average=15; verified")
}
