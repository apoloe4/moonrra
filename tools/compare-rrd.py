"""Compare the supported aligned GAUGE subset against the actual RRDtool CLI."""
import json, math, subprocess, tempfile
from pathlib import Path
BASE = 1800000000

def run(*args):
    return subprocess.check_output(args, text=True)

actual = {}
for line in run('moon', 'run', 'examples/reference', '--target', 'native').splitlines():
    method, timestamp, value = line.split(',')
    actual[method, int(timestamp)] = None if value == 'U' else float(value)

with tempfile.TemporaryDirectory(prefix='moonrra-rrd-') as directory:
    path = str(Path(directory) / 'reference.rrd')
    methods = ['AVERAGE', 'MIN', 'MAX', 'LAST']
    run('rrdtool', 'create', path, '--start', str(BASE), '--step', '60',
        'DS:metric:GAUGE:60:U:U', *[f'RRA:{m}:0.5:3:8' for m in methods])
    run('rrdtool', 'update', path, *[f'{BASE+t*60}:{"U" if t in (4,10,11) else t}' for t in range(1,13)])
    compared = 0
    for method in methods:
        for line in run('rrdtool', 'fetch', path, method, '--start', str(BASE),
                        '--end', str(BASE+720), '--resolution', '180').splitlines():
            if ':' not in line:
                continue
            stamp, raw = line.split(':', 1)
            timestamp = int(stamp.strip())
            if not BASE < timestamp <= BASE+720:
                continue
            expected = float(raw.strip())
            value = actual.pop((method, timestamp))
            if math.isnan(expected):
                assert value is None, (method, timestamp, expected, value)
            else:
                assert value is not None and math.isclose(value, expected, rel_tol=1e-12, abs_tol=1e-12), (method, timestamp, expected, value)
            compared += 1
    assert compared == 16 and not actual
    print(json.dumps({'rrdtool': run('rrdtool', '--version').splitlines()[0], 'compared_buckets': compared,
                      'aggregations': methods, 'missing_ticks': [4,10,11], 'result': 'pass'}))
