#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/qroot"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source "$ROOT/queuebash.sh"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

mkdir -p "$QUEUEBASH_ROOT/done" "$QUEUEBASH_ROOT/logs"
cat > "$QUEUEBASH_ROOT/done/cleared_done.job" <<'JOB'
JOB_ID=cleared_done
JOB_NAME=cleared-done
PRIORITY=10
CLASS=DEFAULT
SUBMITTED_AT=2026-05-26T16:00:00+01:00
RUN_STARTED_AT=2026-05-26T16:00:01+01:00
FINISHED_AT=2026-05-26T16:00:02+01:00
EXIT_CODE=0
COMMAND=( echo cleared-done )
JOB_CLEARED=1
JOB_CLEARED_AT=2026-05-26T16:00:01+01:00
JOB_CLEARED_BY=worker-1
JOB_CLEARED_CLASS=DEFAULT
JOB_CLEARED_POLICY_STATEMENT=default
JOB_CLEARED_STAGE=execution_policy,class_assets,mandatory_policy_assets,dynamic_preflight,global_claims
JOB
printf 'log\n' > "$QUEUEBASH_ROOT/logs/cleared_done.log"

before="$(queue audit cleared --json)"
python3 - "$before" <<'PY' || fail "expected one live cleared done job before clear"
import json, sys
j=json.loads(sys.argv[1])
assert j["count"] == 1, j
assert j["cleared"][0]["qid"] == "cleared_done", j
assert j["cleared"][0]["state"] == "done", j
PY

out="$(queue clear done)"
printf '%s\n' "$out"
grep -q 'archived 1 record' <<<"$out" || fail "clear done should report archived record count"
[[ ! -e "$QUEUEBASH_ROOT/done/cleared_done.job" ]] || fail "done job should move out of live done state"
[[ -e "$QUEUEBASH_ROOT/clearance/done/cleared_done.job" ]] || fail "done job should be archived under clearance/done"
grep -q 'QUEUE_CLEARED_ARCHIVED=1' "$QUEUEBASH_ROOT/clearance/done/cleared_done.job" || fail "archive marker missing"

after="$(queue audit cleared --json)"
python3 - "$after" <<'PY' || fail "expected archived cleared done job after clear"
import json, sys
j=json.loads(sys.argv[1])
assert j["count"] == 1, j
row=j["cleared"][0]
assert row["qid"] == "cleared_done", row
assert row["state"] == "done", row
assert "/clearance/done/" in row["job_file"], row
PY

echo "[PASS] clear archive/audit smoke checks pass"
