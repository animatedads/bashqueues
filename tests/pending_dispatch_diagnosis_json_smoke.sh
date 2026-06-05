#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh
mkdir -p "$QUEUEBASH_ROOT/classes"
cat > "$QUEUEBASH_ROOT/classes/BLOCKED_PREFLIGHT.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_PREFLIGHT_CMD=false
CLASS
queue submit blocked-json --class BLOCKED_PREFLIGHT -- echo no-run >/dev/null
out="$(queue status blocked-json --json)"
OUT_JSON="$out" python3 - <<'PY'
import json, os
obj=json.loads(os.environ['OUT_JSON'])
diag=obj.get('dispatch_diagnosis')
assert obj['state']=='pending', obj
assert diag and diag['schema']=='queuebash.dispatch_diagnosis.v1', obj
assert diag['pending'] is True, diag
assert diag['status']=='blocked', diag
assert diag['class']=='BLOCKED_PREFLIGHT', diag
assert diag['class_resource']['available'] is False, diag
assert int(diag['class_resource']['rc']) != 0, diag
assert 'cmd_failed' in diag['class_resource']['output'], diag
assert diag['system_modified'] is False, diag
PY
# JSON diagnosis must not turn a pending preflight block into a running/failed job.
state="$(queue status blocked-json --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["state"])')"
[[ "$state" == "pending" ]]
echo "pending_dispatch_diagnosis_json_smoke: ok"
