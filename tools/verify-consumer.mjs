// Verifies the registry artifact in a fresh module, without local source imports.
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
const directory = process.argv[2];
if (!directory || fs.existsSync(directory)) throw new Error('Pass a new, nonexistent directory');
fs.mkdirSync(directory, {recursive: true});
fs.writeFileSync(path.join(directory, 'moon.mod'), 'name = "apoloe4/moonrra-consumer-check"\nimport { "apoloe4/moonrra@0.1.0" }\n');
fs.writeFileSync(path.join(directory, 'moon.pkg'), 'pkgtype(kind: "executable")\nimport { "apoloe4/moonrra" @rra }\n');
fs.writeFileSync(path.join(directory, 'main.mbt'), `fn main {
  try {
    let db = @rra.Store::new(60, [@rra.Spec::new(2, 3, Average, min_known=2)])
    db.update(60L, Some(10.0))
    let restored = @rra.Store::restore(db.snapshot())
    restored.update(120L, Some(20.0))
    assert_eq(restored.fetch(0, 0L, 120L)[0].value, Some(15.0))
    assert_eq(restored.info(0).oldest, Some(120L))
    println("Mooncakes consumer: snapshot continuation and aggregation verified")
  } catch { e => abort(e.to_string()) }
}
`);
for (const args of [['update'], ['check', '--deny-warn'], ['build', '--deny-warn', '--target', 'js'], ['run', '.', '--target', 'js']]) {
  const result = spawnSync('moon', args, {cwd: directory, env: process.env, stdio: 'inherit'});
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
