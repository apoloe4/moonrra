///|
/// Result of admitting an observation to a series. Closed ticks never change.
#derive(Debug, Eq)
pub(all) enum Admission {
  Buffered
  Replaced
  Superseded
  Duplicate
  TooLate
  SeriesLimit
}

///|
priv struct Track {
  archive : Store
  pending : Map[Int64, (Int64, Double)]
  mut peak : Int64
  mut closed : Int64
}

///|
/// Bounded event-time router. Each series has its own watermark.
pub struct Collector {
  priv step : Int32
  priv lag : Int64
  priv limit : Int32
  priv specs : Array[Spec]
  priv tracks : Map[String, Track]
}

///|
pub fn Collector::new(
  step : Int32,
  specs : Array[Spec],
  lateness~ : Int32,
  max_series~ : Int32,
) -> Collector raise ArchiveError {
  ignore(Store::new(step, specs))
  if lateness < 0 ||
    lateness > step * 1024 ||
    max_series < 1 ||
    max_series > 4096 {
    raise InvalidConfig(
      "lateness must be 0..1024 steps; max_series must be 1..4096",
    )
  }
  {
    step,
    lag: lateness.to_int64(),
    limit: max_series,
    specs: specs.copy(),
    tracks: {},
  }
}

///|
fn Track::close_to(self : Track, end : Int64) -> Unit raise ArchiveError {
  if end <= self.closed {
    return
  }
  let ready = self.pending.keys().filter(fn(t) { t <= end }).collect()
  ready.sort()
  for t in ready {
    if self.pending.remove_and_get(t) is Some((_, value)) {
      self.archive.update(t, Some(value))
    }
  }
  if self.archive.latest() > 0L && end > self.archive.latest() {
    self.archive.update(end, None)
  }
  self.closed = end
}

///|
/// In (end-step,end], retain the latest event; for equal timestamps first wins.
pub fn Collector::observe(
  self : Collector,
  key : String,
  time : Int64,
  value : Double,
) -> Admission raise ArchiveError {
  let step = self.step.to_int64()
  if key.length() == 0 ||
    key.length() > 2048 ||
    time <= 0L ||
    time > 9000000000000000L ||
    !finite(value) {
    raise InvalidSample("invalid series key, event time, or value")
  }
  let bucket = ((time - 1L) / step + 1L) * step
  if bucket > 9000000000000000L {
    raise InvalidSample("bucket end out of range")
  }
  let track = match self.tracks.get(key) {
    Some(track) => track
    None => {
      if self.tracks.length() >= self.limit {
        return SeriesLimit
      }
      let track = {
        archive: Store::new(self.step, self.specs),
        pending: {},
        peak: 0L,
        closed: 0L,
      }
      self.tracks[key] = track
      track
    }
  }
  if bucket <= track.closed {
    return TooLate
  }
  let disposition = match track.pending.get(bucket) {
    Some((previous, _)) if time == previous => Duplicate
    Some((previous, _)) if time < previous => Superseded
    Some(_) => Replaced
    None => Buffered
  }
  if disposition == Buffered || disposition == Replaced {
    track.pending[bucket] = (time, value)
  }
  if time > track.peak {
    track.peak = time
  }
  track.close_to((track.peak - self.lag) / step * step)
  disposition
}

///|
/// Advance an idle series through all full ticks up to an external event-time cutoff.
pub fn Collector::advance(
  self : Collector,
  key : String,
  through : Int64,
) -> Unit raise ArchiveError {
  if through < 0L || through > 9000000000000000L {
    raise InvalidSample("invalid cutoff")
  }
  guard self.tracks.get(key) is Some(track) else {
    raise InvalidSample("unknown series")
  }
  let step = self.step.to_int64()
  track.close_to(through / step * step)
}

///|
/// Seal remaining observations at end of input, without adding a trailing gap.
pub fn Collector::flush(self : Collector) -> Unit raise ArchiveError {
  let step = self.step.to_int64()
  for _, track in self.tracks {
    track.close_to(((track.peak - 1L) / step + 1L) * step)
  }
}

///|
pub fn Collector::series(self : Collector) -> Array[String] {
  let keys = self.tracks.keys().collect()
  keys.sort()
  keys
}

///|
pub fn Collector::fetch(
  self : Collector,
  key : String,
  archive : Int32,
  start : Int64,
  end : Int64,
) -> Array[Point] raise ArchiveError {
  guard self.tracks.get(key) is Some(track) else {
    raise InvalidSample("unknown series")
  }
  track.archive.fetch(archive, start, end)
}
