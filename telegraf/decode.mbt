///|
pub struct Sample {
  key : String
  time : Int64
  value : Double
}

///| Decode one Telegraf JSON metric (timestamp_units = 1s). Identity is the

///|
/// JSON tuple [measurement, field, sorted tag pairs], not a delimited path.
pub fn decode(line : StringView) -> Array[Sample] raise {
  guard line.length() <= 65536 else {
    raise @rra.InvalidSample("oversized metric")
  }
  let metric = @json.parse(line, reject_duplicate_keys=true)
  guard metric is Object(m) &&
    m.get("name") is Some(String(name)) &&
    name.length() > 0 &&
    m.get("tags") is Some(Object(tags)) &&
    m.get("fields") is Some(Object(fields)) &&
    m.get("timestamp") is Some(Number(t, ..)) else {
    raise @rra.InvalidSample("expected name, tags, fields, and timestamp")
  }
  guard t > 0.0 &&
    t <= 9000000000000000.0 &&
    t.to_int64().to_double() == t &&
    tags.length() <= 32 &&
    fields.length() <= 64 else {
    raise @rra.InvalidSample("invalid timestamp or metric dimensions")
  }
  let names = tags.keys().collect()
  names.sort()
  let pairs : Array[Json] = []
  for k in names {
    guard tags.get(k) is Some(String(v)) else {
      raise @rra.InvalidSample("non-string tag")
    }
    pairs.push(Json::array([Json::string(k), Json::string(v)]))
  }
  let result = []
  let keys = fields.keys().collect()
  keys.sort()
  for k in keys {
    if fields.get(k) is Some(Number(v, ..)) {
      let id : Json = Json::array([
        Json::string(name),
        Json::string(k),
        Json::array(pairs),
      ])
      let key = id.stringify()
      guard key.length() <= 2048 && !v.is_inf() && !v.is_nan() else {
        raise @rra.InvalidSample("invalid gauge or identity")
      }
      result.push({ key, time: t.to_int64(), value: v, })
    }
  }
  guard !result.is_empty() else {
    raise @rra.InvalidSample("no numeric fields")
  }
  result
}
