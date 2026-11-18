///|
/// Counts distinguish retained missing values from history that is not available.
#derive(Debug, Eq)
pub struct CohortPoint {
  end : Int64
  reporting : Int32
  missing : Int32
  unavailable : Int32
  mean : Double?
}

///| Compare an explicit roster of like-unit series, including never-seen keys.

///|
/// A mean is reported only when at least min_reporting members have values.
pub fn Collector::cohort(
  self : Collector,
  keys : Array[String],
  archive : Int32,
  start : Int64,
  end : Int64,
  min_reporting~ : Int32,
) -> Array[CohortPoint] raise ArchiveError {
  if keys.is_empty() ||
    keys.length() > 4096 ||
    min_reporting < 1 ||
    min_reporting > keys.length() ||
    archive < 0 ||
    archive >= self.specs.length() ||
    start < 0L ||
    end < start ||
    end > 9000000000000000L {
    raise InvalidConfig("invalid roster, quorum, archive or time range")
  }
  let resolution = self.specs[archive].factor.to_int64() * self.step.to_int64()
  let first = start / resolution + 1L
  let count = end / resolution - start / resolution
  if count > 4096L || count * keys.length().to_int64() > 1000000L {
    raise InvalidConfig("cohort query exceeds cell limit")
  }
  let n = count.to_int()
  let known = Array::make(n, 0)
  let missing = Array::make(n, 0)
  let means = Array::make(n, 0.0)
  let seen : Map[String, Bool] = Map([])
  for k in keys {
    if k.is_empty() || k.length() > 2048 || seen.contains(k) {
      raise InvalidConfig("invalid or duplicate roster key")
    }
    seen[k] = true
    if self.tracks.get(k) is Some(s) {
      for p in s.archive.fetch(archive, start, end) {
        let i = (p.timestamp / resolution - first).to_int()
        match p.value {
          None => missing[i] += 1
          Some(v) => {
            let prev = known[i].to_double()
            known[i] += 1
            means[i] = means[i] * (prev / known[i].to_double()) +
              v / known[i].to_double()
          }
        }
      }
    }
  }
  Array::makei(n, i => {
    end: (first + i.to_int64()) * resolution,
    reporting: known[i],
    missing: missing[i],
    unavailable: keys.length() - known[i] - missing[i],
    mean: if known[i] >= min_reporting {
      Some(means[i])
    } else {
      None
    },
  })
}
