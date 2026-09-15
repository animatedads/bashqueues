#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
HOME="$TMP_HOME" QUEUEBASH_ROOT="$TMP_HOME/.queuebash" QUEUEBASH_ALLOW_NONINTERACTIVE=1 bash -lc "cd '$ROOT' && source ./queuebash.sh && queue platform doctor --json" >"$TMP_HOME/doctor.json"
python3 - "$TMP_HOME/doctor.json" <<'PY'
import json, sys
p=sys.argv[1]
data=json.load(open(p))
assert data['schema']=='queuebash.platform_doctor.v1'
assert data['status'] in ('ok','warn','fail')
assert data['platform_id']
assert data['queue_root']
assert data['policy_ref']=='policies.d/platform/windows-runtime-parity.json'
assert isinstance(data['findings'], list) and data['findings']
for f in data['findings']:
    assert f['severity'] in ('ok','warn','fail')
    assert f['code']
    assert f['message']
PY

echo 'PASS windows platform doctor surface smoke'
