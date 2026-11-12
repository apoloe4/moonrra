///| Save through an exclusively created sibling staging file, then rename.

///| Single writer per path. A leftover .tmp is an error, never silently overwritten.

///|
/// File data is synced; directory metadata durability is not guaranteed.
pub async fn save(store : @rra.Store, path : String) -> Unit {
  let bytes = store.snapshot()
  let staging = path + ".tmp"
  let file = @fs.open(staging, mode=WriteOnly, create_mode=CreateNew)
  defer file.close()
  errdefer @fs.remove(staging, allow_missing=true)
  file.write(bytes)
  file.sync()
  file.close()
  @fs.rename(staging, path, replace=true)
}

///|
/// Read a bounded snapshot through one file descriptor and validate before returning.
pub async fn load(path : String, max_bytes~ : Int32 = 24004000) -> @rra.Store {
  if max_bytes < 48 || max_bytes > 24004000 {
    raise @rra.InvalidSnapshot("invalid file byte limit")
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  if size < 48L || size > max_bytes.to_int64() {
    raise @rra.InvalidSnapshot("snapshot file exceeds configured bounds")
  }
  let bytes = file.read_exactly_at(size.to_int(), position=0L)
  if file.size() != size {
    raise @rra.InvalidSnapshot("file changed while reading")
  }
  @rra.Store::restore(bytes)
}
