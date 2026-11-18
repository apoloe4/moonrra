///|
/// The only host binding: read a finite, already closed spool file (Node 22.13+).
extern "js" fn read_batch(path : String) -> String =
  #| (path) => {
  #|   const fs = process.getBuiltinModule('node:fs'), fd = fs.openSync(path, 'r');
  #|   try {
  #|     const st = fs.fstatSync(fd);
  #|     if (!st.isFile() || st.size > 4194304) throw Error('expected a regular file <= 4 MiB');
  #|     const buf = Buffer.alloc(st.size);
  #|     for (let i = 0; i < buf.length;) {
  #|       const n = fs.readSync(fd, buf, i, buf.length-i, i);
  #|       if (!n) throw Error('file truncated while reading');
  #|       i += n;
  #|     }
  #|     return new TextDecoder('utf-8', {fatal:true}).decode(buf);
  #|   } finally { fs.closeSync(fd); }
  #| }

///|
fn main raise {
  let args = @env.args()
  guard args.length() == 3 else {
    fail("usage: collector_node <closed-ndjson-file>")
  }
  for record in @telegraf.replay(read_batch(args[2])) {
    println(record)
  }
}
