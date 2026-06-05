#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT="$(mktemp -d)"
trap 'rm -rf "$QUEUEBASH_ROOT"' EXIT
source ./queuebash.sh
queue submit migrate-schema-v42 --class DB_MIGRATION -- bash -lc 'echo migrate-v42' >/tmp/postclaim-submit.out
queue run >/tmp/postclaim-run.out 2>/tmp/postclaim-run.err || true
queue stats --json >/tmp/postclaim-stats.json
python3 - <<'PY'
import json, pathlib, sys
stats=json.load(open('/tmp/postclaim-stats.json'))
assert stats['states']['running']==0, stats
assert stats['states']['pending']==0, stats
assert stats['states']['interrupted']==1, stats
PY
job_count=$(find "$QUEUEBASH_ROOT" -name '*.job' | wc -l | tr -d ' ')
[[ "$job_count" == "1" ]] || { find "$QUEUEBASH_ROOT" -name '*.job' -print >&2; exit 1; }
job="$(find "$QUEUEBASH_ROOT" -name '*.job' -print)"
grep -q '^POSTCLAIM_PREFLIGHT_BLOCKED=1' "$job"
! grep -q '^RUN_STARTED_AT=' "$job"
queue explain "$(basename "$job" .job)" --json > /tmp/postclaim-explain.json
python3 - <<'PY'
import json
rec=json.load(open('/tmp/postclaim-explain.json'))
assert rec['state']=='interrupted', rec
assert rec['times']['run_started_at']=='', rec
assert rec['pids']['systemd_unit']=='', rec
PY
queue health --json | python3 -m json.tool >/dev/null
echo 'PASS postclaim_preflight_block_state_smoke'
