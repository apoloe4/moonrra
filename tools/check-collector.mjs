import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const [mode, path, source] = process.argv.slice(2);
const read = path => readFileSync(path,'utf8').trim().split(/\r?\n/).map(line => JSON.parse(line));
const rows = read(path), stats = rows.pop();
if (mode === 'fixture') {
  assert.deepEqual(stats, {series_count:2, too_late:1, series_limit:0, ignored:0});
  assert.deepEqual(rows.map(r => [r.series, r.end, r.value]), [
    ...[[10,14],[20,19],[30,null],[40,null],[50,23]].map(([t,v]) => [['room','temperature',[['host','east']]],t,v]),
    [['room','temperature',[['host','west']]],10,0],
  ]);
} else if (mode === 'live') {
  const [m, ...extra] = read(source);
  assert.equal(extra.length,0); assert.equal(m.name,'mem');
  assert.deepEqual(Object.keys(m.fields).sort(), ['available','used_percent']);
  assert.deepEqual(stats,{series_count:2,too_late:0,series_limit:0,ignored:0});
  assert.deepEqual(rows.map(r => [r.series,r.end,r.value]), Object.keys(m.fields).sort().map(k => [
    [m.name,k,Object.entries(m.tags).sort(([a],[b]) => a < b ? -1 : a > b ? 1 : 0)],
    Math.ceil(m.timestamp/10)*10, m.fields[k],
  ]));
} else { throw Error('expected fixture or live'); }
console.log(`${mode}: verified ${rows.length} buckets against input`);
