#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp -d "${TMPDIR:-/tmp}/class-fingerprint.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

bin/queue-class-infer.py fingerprint --json -- ffmpeg -i input001.mp4 -vf scale=1920:1080 output001.mp4 > "$tmp/a.json"
bin/queue-class-infer.py fingerprint --json -- ffmpeg -i input999.mp4 -vf scale=1280:720 output999.mp4 > "$tmp/b.json"
/usr/bin/python3 - "$tmp/a.json" "$tmp/b.json" <<'PY'
import json, sys
A=json.load(open(sys.argv[1])); B=json.load(open(sys.argv[2]))
assert A['schema']=='queuebash.class_inference.fingerprint.v1'
assert A['argv0']=='ffmpeg'
assert A['command_raw_hash'] != B['command_raw_hash']
assert A['command_shape_hash'] == B['command_shape_hash'], (A['arg_shape'], B['arg_shape'])
assert '<path.mp4>' in A['arg_shape']
assert '<range>' in A['arg_shape']
print('PASS class fingerprint json')
PY

echo 'PASS class_fingerprint_static'
