///| Version 1: little-endian 64-bit fields, IEEE doubles, and FNV-1a checksum.

///|
/// This checksum detects accidental corruption; it is not authentication.
fn checksum(bytes : Bytes, end : Int32) -> UInt32 {
  let mut h = 2166136261U
  for i = 0; i < end; i = i + 1 {
    h = (h ^ bytes[i].to_uint()) * 16777619U
  }
  h
}

///|
pub fn Store::snapshot(self : Store) -> Bytes {
  let b = @buffer.Buffer()
  b.write_int64_le(0x4152524DL)
  b.write_int64_le(1L)
  b.write_int64_le(self.step.to_int64())
  b.write_int64_le(self.latest)
  b.write_int64_le(self.archives.length().to_int64())
  for a in self.archives {
    b.write_int64_le(a.spec.factor.to_int64())
    b.write_int64_le(a.spec.rows.to_int64())
    b.write_int64_le(
      match a.spec.aggregation {
        Average => 0L
        Minimum => 1L
        Maximum => 2L
        Last => 3L
      },
    )
    b.write_int64_le(a.spec.min_known.to_int64())
    b.write_int64_le(a.bucket)
    b.write_int64_le(a.count.to_int64())
    b.write_double_le(a.mean)
    b.write_double_le(a.low)
    b.write_double_le(a.high)
    b.write_double_le(a.last)
    b.write_int64_le(a.data.length().to_int64())
    for i = 0; i < a.data.length(); i = i + 1 {
      let p = a.data[(a.head + i) % a.data.length()]
      b.write_int64_le(p.timestamp)
      match p.value {
        None => {
          b.write_int64_le(0L)
          b.write_double_le(0.0)
        }
        Some(v) => {
          b.write_int64_le(1L)
          b.write_double_le(v)
        }
      }
    }
  }
  let body = b.to_bytes()
  b.write_int64_le(checksum(body, body.length()).to_int64())
  b.to_bytes()
}

///|
priv struct Reader {
  data : Bytes
  mut pos : Int32
}

///|
fn Reader::word(self : Reader) -> Int64 raise ArchiveError {
  if self.pos > self.data.length() - 8 {
    raise InvalidSnapshot("truncated word")
  }
  let mut n = 0L
  for i = 0; i < 8; i = i + 1 {
    n = n | (self.data[self.pos + i].to_int64() << (i * 8))
  }
  self.pos += 8
  n
}

///|
fn Reader::bounded(
  self : Reader,
  low : Int32,
  high : Int32,
) -> Int32 raise ArchiveError {
  let n = self.word()
  if n < low.to_int64() || n > high.to_int64() {
    raise InvalidSnapshot("integer out of bounds")
  }
  n.to_int()
}

///|
fn Reader::number(self : Reader) -> Double raise ArchiveError {
  let n = self.word().reinterpret_as_double()
  if !finite(n) {
    raise InvalidSnapshot("non-finite number")
  }
  n
}

///|
/// Decoding is bounded to one million retained points and 32 archives.
pub fn Store::restore(bytes : Bytes) -> Store raise ArchiveError {
  if bytes.length() < 48 || bytes.length() > 24004000 {
    raise InvalidSnapshot("snapshot size out of bounds")
  }
  let trailer = { data: bytes, pos: bytes.length() - 8, }
  if trailer.word() != checksum(bytes, bytes.length() - 8).to_int64() {
    raise InvalidSnapshot("checksum mismatch")
  }
  let r = { data: bytes, pos: 0, }
  if r.word() != 0x4152524DL || r.word() != 1L {
    raise InvalidSnapshot("unsupported format/version")
  }
  let step = r.bounded(1, 86400)
  let latest = r.word()
  if latest < 0L || latest > 9000000000000000L || latest % step.to_int64() != 0L {
    raise InvalidSnapshot("invalid latest timestamp")
  }
  let size = r.bounded(1, 32)

  let archives = []
  let mut capacity = 0
  for index = 0; index < size; index = index + 1 {
    let factor = r.bounded(1, 1000000)
    let rows = r.bounded(1, 1000000)
    capacity += rows
    if capacity > 1000000 {
      raise InvalidSnapshot("capacity limit")
    }
    let aggregation = match r.bounded(0, 3) {
      0 => Average
      1 => Minimum
      2 => Maximum
      _ => Last
    }
    let min_known = r.bounded(1, factor)
    let spec = Spec::new(factor, rows, aggregation, min_known~)

    let a = empty_archive(spec)
    a.bucket = r.word()
    let tick = latest / step.to_int64()
    if a.bucket != tick / factor.to_int64() {
      raise InvalidSnapshot("invalid pending bucket")
    }
    a.count = r.bounded(0, (tick % factor.to_int64()).to_int())
    a.mean = r.number()
    a.low = r.number()
    a.high = r.number()
    a.last = r.number()
    if a.count == 0 {
      if a.mean != 0.0 || a.low != 0.0 || a.high != 0.0 || a.last != 0.0 {
        raise InvalidSnapshot("invalid empty accumulator")
      }
    } else if a.low > a.high || a.last < a.low || a.last > a.high {
      raise InvalidSnapshot("invalid accumulator bounds")
    }
    if a.count == 1 && (a.mean != a.last || a.low != a.last || a.high != a.last) {
      raise InvalidSnapshot("inconsistent single-sample accumulator")
    }
    let n = r.bounded(0, rows)
    if n.to_int64() > a.bucket {
      raise InvalidSnapshot("too many historical buckets")
    }
    for i = 0; i < n; i = i + 1 {
      let timestamp = r.word()
      let expected = (a.bucket - n.to_int64() + i.to_int64() + 1L) *
        factor.to_int64() *
        step.to_int64()
      if timestamp != expected || timestamp > latest {
        raise InvalidSnapshot("invalid bucket timestamp")
      }
      let tag = r.bounded(0, 1)
      let v = r.number()
      if tag == 0 && v != 0.0 {
        raise InvalidSnapshot("noncanonical missing value")
      }
      a.data.push({ timestamp, value: if tag == 0 { None } else { Some(v) }, })
    }
    archives.push(a)
  }
  if r.pos != bytes.length() - 8 {
    raise InvalidSnapshot("trailing data")
  }
  { step, latest, archives, }
}
