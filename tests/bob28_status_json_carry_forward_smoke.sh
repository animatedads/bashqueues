#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root"
source ./queuebash.sh >/dev/null 2>&1

rc=0
out="$(queue status --json 2>/tmp/bob28_status_missing.$$)" || rc=$?
[[ "$rc" -eq 2 ]] || { echo "FAIL: status --json missing target rc=$rc" >&2; exit 1; }
python3 - <<'PY' <<<"$out"
import json,sys
obj=json.load(sys.stdin)
assert obj['schema']=='queuebash.error.v1', obj
assert obj['code']=='status_missing_target', obj
PY

out="$(queue status --json --help)"
python3 - <<'PY' <<<"$out"
import json,sys
obj=json.load(sys.stdin)
assert obj['schema']=='queuebash.status_help.v1', obj
assert obj['command']=='status', obj
PY

rc=0
out="$(queue status --json NO_SUCH_JOB 2>/tmp/bob28_status_notfound.$$)" || rc=$?
[[ "$rc" -eq 1 ]] || { echo "FAIL: status --json not found rc=$rc" >&2; exit 1; }
python3 - <<'PY' <<<"$out"
import json,sys
obj=json.load(sys.stdin)
assert obj['schema']=='queuebash.error.v1', obj
assert obj['code']=='status_target_not_found', obj
PY

rc=0
out="$(queue status --json NO_SUCH_JOB --tail nope 2>/tmp/bob28_status_tail.$$)" || rc=$?
[[ "$rc" -eq 2 ]] || { echo "FAIL: status --json bad tail rc=$rc" >&2; exit 1; }
python3 - <<'PY' <<<"$out"
import json,sys
obj=json.load(sys.stdin)
assert obj['schema']=='queuebash.error.v1', obj
assert obj['code']=='status_tail_not_numeric', obj
PY

echo "bob28 status JSON carry-forward smoke checks: OK"
