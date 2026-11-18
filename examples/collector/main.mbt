///|
/// Replay a closed Telegraf spool file. Print finalized gauge buckets as NDJSON.
async fn main {
  let args = @env.args()
  guard args.length() == 2 else {
    fail("usage: collector <closed-ndjson-file>")
  }
  let file = @fs.open(args[1], mode=ReadOnly)
  defer file.close()
  let n = file.size()
  guard n >= 0L && n <= 4194304L else {
    fail("input exceeds 4 MiB batch limit")
  }
  let text = @utf8.decode(file.read_exactly_at(n.to_int(), position=0L))
  for record in @telegraf.replay(text) {
    println(record)
  }
}
