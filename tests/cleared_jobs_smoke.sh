#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT_DIR"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
cleanup(){ rm -rf "$QUEUEBASH_ROOT"; }
trap cleanup EXIT

source ./queuebash.sh
queue submit cleared_smoke -- bash -lc 'echo cleared-ok' >/dev/null
queue run >/dev/null

text_out="$(queue cleared)"
grep -q 'cleared_smoke' <<< "$text_out"
grep -q 'cleared=1' <<< "$text_out"

json_out="$(queue cleared --json)"
python3 - <<'PY' <<< "$json_out"
import json, sys
obj=json.load(sys.stdin)
assert obj['count'] == 1, obj
job=obj['cleared'][0]
assert job['name'] == 'cleared_smoke', job
assert job['state'] == 'done', job
assert job['cleared_at'], job
assert 'execution_policy' in job['stage'], job
assert 'mandatory_policy_assets' in job['stage'], job
PY

qid="$(basename "$(ls "$QUEUEBASH_ROOT/done"/*.job)" .job)"
status_json="$(queue status "$qid" --json --tail 0)"
python3 - <<'PY' <<< "$status_json"
import json, sys
obj=json.load(sys.stdin)
assert obj['clearance']['cleared'] == '1', obj['clearance']
assert obj['clearance']['cleared_at'], obj['clearance']
PY

audit_json="$(queue audit cleared --json)"
python3 - <<'PY' <<< "$audit_json"
import json, sys
obj=json.load(sys.stdin)
assert obj['count'] == 1, obj
PY

echo '[PASS] queue cleared lists dispatch-cleared jobs in text/json/status/audit forms'
