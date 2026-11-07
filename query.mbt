///|
pub struct ArchiveInfo {
  resolution : Int64
  capacity : Int32
  retained : Int32
  oldest : Int64?
  newest : Int64?
  pending_known : Int32
} derive(Debug, Eq)

///|
/// Coverage metadata distinguishes expired history from retained unknown values.
pub fn Store::info(
  self : Store,
  archive_index : Int32,
) -> ArchiveInfo raise ArchiveError {
  if archive_index < 0 || archive_index >= self.archives.length() {
    raise InvalidConfig("invalid archive index")
  }
  let a = self.archives[archive_index]
  let n = a.data.length()
  {
    resolution: a.spec.factor.to_int64() * self.step.to_int64(),
    capacity: a.spec.rows,
    retained: n,
    oldest: if n == 0 {
      None
    } else {
      Some(a.data[a.head].timestamp)
    },
    newest: if n == 0 {
      None
    } else {
      Some(a.data[(a.head + n - 1) % n].timestamp)
    },
    pending_known: a.count,
  }
}

///| Explicit 32-bit counter conversion. A decrease is unknown unless wrap is enabled.

///|
/// The caller must distinguish a reset from a wrap; this function cannot infer it.
pub fn counter32_rate(
  previous : UInt32,
  current : UInt32,
  elapsed_seconds : Int32,
  wrap~ : Bool = false,
) -> Double? raise ArchiveError {
  if elapsed_seconds <= 0 {
    raise InvalidSample("elapsed seconds must be positive")
  }
  if current >= previous {
    Some(
      (current.to_int64() - previous.to_int64()).to_double() /
      elapsed_seconds.to_double(),
    )
  } else if wrap {
    Some(
      (4294967296L - previous.to_int64() + current.to_int64()).to_double() /
      elapsed_seconds.to_double(),
    )
  } else {
    None
  }
}
