#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT" /tmp/postclaim-waiting-*.json /tmp/postclaim-waiting-*.out /tmp/postclaim-waiting-*.err' EXIT
source ./queuebash.sh
mkdir -p "$QUEUEBASH_ROOT/classes"
cat > "$QUEUEBASH_ROOT/classes/WAITING_TEST.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_PREFLIGHT_CMD=false
CLASS
queue submit waiting-preflight --class WAITING_TEST -- bash -lc 'echo should-run-after-release' >/tmp/postclaim-waiting-submit.out
queue run >/tmp/postclaim-waiting-run.out 2>/tmp/postclaim-waiting-run.err || true
queue stats --json >/tmp/postclaim-waiting-stats.json
python3 - <<'PY'
import json
stats=json.load(open('/tmp/postclaim-waiting-stats.json'))
assert stats['states']['running']==0, stats
assert stats['states']['pending']==0, stats
assert stats['states']['waiting']==1, stats
assert stats['states']['interrupted']==0, stats
PY
job_count=$(find "$QUEUEBASH_ROOT" -name '*.job' | wc -l | tr -d ' ')
[[ "$job_count" == "1" ]] || { find "$QUEUEBASH_ROOT" -name '*.job' -print >&2; exit 1; }
job="$(find "$QUEUEBASH_ROOT/waiting" -name '*.job' -print)"
grep -q '^WAIT_REASON=' "$job"
grep -q '^WAIT_LAST_PREFLIGHT=' "$job"
grep -q '^RUNNER_USED=' "$job"
! grep -q '^RUN_STARTED_AT=' "$job"
queue explain "$(basename "$job" .job)" --json > /tmp/postclaim-waiting-explain.json
python3 - <<'PY'
import json
rec=json.load(open('/tmp/postclaim-waiting-explain.json'))
assert rec['state']=='waiting', rec
assert rec['times']['run_started_at']=='', rec
PY
cat > "$QUEUEBASH_ROOT/classes/WAITING_TEST.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_PREFLIGHT_CMD=true
CLASS
queue sentinel --once >/tmp/postclaim-waiting-sentinel.out 2>/tmp/postclaim-waiting-sentinel.err || true
queue stats --json >/tmp/postclaim-waiting-after-sentinel.json
python3 - <<'PY'
import json
stats=json.load(open('/tmp/postclaim-waiting-after-sentinel.json'))
assert stats['states']['waiting']==0, stats
assert stats['states']['pending']==1, stats
PY
queue run >/tmp/postclaim-waiting-run2.out 2>/tmp/postclaim-waiting-run2.err
queue stats --json >/tmp/postclaim-waiting-final.json
python3 - <<'PY'
import json
stats=json.load(open('/tmp/postclaim-waiting-final.json'))
assert stats['states']['waiting']==0, stats
assert stats['states']['pending']==0, stats
assert stats['states']['done']==1, stats
PY
echo 'PASS postclaim_preflight_waiting_state_smoke'
