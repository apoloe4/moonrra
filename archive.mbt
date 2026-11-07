///|
pub(all) suberror ArchiveError {
  InvalidConfig(String)
  InvalidSample(String)
  InvalidSnapshot(String)
} derive(Debug, Eq)

///|
pub(all) enum Consolidation {
  Average
  Minimum
  Maximum
  Last
} derive(Debug, Eq)

///|
pub struct Spec {
  priv factor : Int32
  priv rows : Int32
  priv aggregation : Consolidation
  priv min_known : Int32
} derive(Debug, Eq)

///|
/// An archive accepts a bucket only when at least min_known samples are known.
pub fn Spec::new(
  factor : Int32,
  rows : Int32,
  aggregation : Consolidation,
  min_known~ : Int32 = 1,
) -> Spec raise ArchiveError {
  if factor < 1 ||
    factor > 1000000 ||
    rows < 1 ||
    rows > 1000000 ||
    min_known < 1 ||
    min_known > factor {
    raise InvalidConfig(
      "factor/rows must be 1..1000000; min_known must be 1..factor",
    )
  }
  { factor, rows, aggregation, min_known, }
}

///|
pub struct Point {
  timestamp : Int64
  value : Double?
} derive(Debug, Eq)

///|
struct Archive {
  spec : Spec
  data : Array[Point]
  mut head : Int32
  mut bucket : Int64
  mut count : Int32
  mut mean : Double
  mut low : Double
  mut high : Double
  mut last : Double
}

///|
pub struct Store {
  priv step : Int32
  priv archives : Array[Archive]
  priv mut latest : Int64
}

///|
fn finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn empty_archive(spec : Spec) -> Archive {
  {
    spec,
    data: [],
    head: 0,
    bucket: 0L,
    count: 0,
    mean: 0.0,
    low: 0.0,
    high: 0.0,
    last: 0.0,
  }
}

///|
/// Timestamps are positive UTC seconds, aligned to step, at interval ends.
pub fn Store::new(
  step : Int32,
  specs : Array[Spec],
) -> Store raise ArchiveError {
  if step < 1 || step > 86400 || specs.is_empty() || specs.length() > 32 {
    raise InvalidConfig("step must be 1..86400; archive count 1..32")
  }
  let mut total = 0
  for spec in specs {
    total += spec.rows
  }
  if total > 1000000 {
    raise InvalidConfig("total capacity exceeds one million points")
  }
  { step, archives: specs.map(empty_archive), latest: 0L, }
}

///|
fn Archive::push(self : Archive, point : Point) -> Unit {
  if self.data.length() < self.spec.rows {
    self.data.push(point)
  } else {
    self.data[self.head] = point
    self.head = (self.head + 1) % self.spec.rows
  }
}

///|
fn Archive::finish(self : Archive, step : Int32) -> Unit {
  let value = if self.count < self.spec.min_known {
    None
  } else {
    Some(
      match self.spec.aggregation {
        Average => self.mean
        Minimum => self.low
        Maximum => self.high
        Last => self.last
      },
    )
  }
  self.push({
    timestamp: (self.bucket + 1L) *
    self.spec.factor.to_int64() *
    step.to_int64(),
    value,
  })
  self.count = 0
  self.mean = 0.0
  self.low = 0.0
  self.high = 0.0
  self.last = 0.0
  self.bucket += 1L
}

///|
/// Input validation happens before any state is changed. A missing tick is unknown.
pub fn Store::update(
  self : Store,
  timestamp : Int64,
  value : Double?,
) -> Unit raise ArchiveError {
  if timestamp <= self.latest ||
    timestamp > 9000000000000000L ||
    timestamp % self.step.to_int64() != 0L {
    raise InvalidSample(
      "timestamp must increase, align to step, and be at most 9e15 seconds",
    )
  }
  if value is Some(v) && !finite(v) {
    raise InvalidSample("value must be finite")
  }
  let tick = timestamp / self.step.to_int64()
  for archive in self.archives {
    let target = (tick - 1L) / archive.spec.factor.to_int64()
    if self.latest == 0L {
      archive.bucket = target
    }
    if target > archive.bucket {
      archive.finish(self.step)
      let gap = target - archive.bucket
      if gap >= archive.spec.rows.to_int64() {
        archive.data.clear()
        archive.head = 0
        archive.bucket = target - archive.spec.rows.to_int64()
      }
      while archive.bucket < target {
        archive.finish(self.step)
      }
    }
    if value is Some(v) {
      let n = archive.count.to_double()
      archive.mean = archive.mean * (n / (n + 1.0)) + v / (n + 1.0)
      if archive.count == 0 {
        archive.low = v
        archive.high = v
      } else {
        if v < archive.low {
          archive.low = v
        }
        if v > archive.high {
          archive.high = v
        }
      }
      archive.last = v
      archive.count += 1
    }
    if tick % archive.spec.factor.to_int64() == 0L {
      archive.finish(self.step)
    }
  }
  self.latest = timestamp
}

///| Returns completed retained buckets in (start, end], ordered by timestamp.

///|
/// Missing buckets have None; overwritten/outside-history buckets are absent.
pub fn Store::fetch(
  self : Store,
  archive_index : Int32,
  start : Int64,
  end : Int64,
) -> Array[Point] raise ArchiveError {
  if archive_index < 0 || archive_index >= self.archives.length() || start > end {
    raise InvalidConfig("invalid archive index or range")
  }
  let archive = self.archives[archive_index]
  let result = []
  for i = 0; i < archive.data.length(); i = i + 1 {
    let point = archive.data[(archive.head + i) % archive.data.length()]
    if point.timestamp > start && point.timestamp <= end {
      result.push(point)
    }
  }
  result
}

///|
pub fn Store::latest(self : Store) -> Int64 {
  self.latest
}

///|
pub fn Store::retained(self : Store) -> Int32 {
  let mut total = 0
  for a in self.archives {
    total += a.data.length()
  }
  total
}
