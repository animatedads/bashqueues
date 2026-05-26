#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source "$ROOT/queuebash.sh"
mkdir -p "$QUEUEBASH_ROOT/failed"
cat > "$QUEUEBASH_ROOT/failed/fake_failed.job" <<'JOB'
JOB_ID=fake_failed
JOB_NAME=archived-failed
JOB_CLASS=DEFAULT
PRIORITY=10
SUBMITTED_AT='2026-05-26T10:00:00+01:00'
COMMAND=( bash -c 'exit 7' )
EXIT_CODE=7
JOB
queue clear failed >/tmp/clear.out
[[ -f "$QUEUEBASH_ROOT/clearance/failed/fake_failed.job" ]] || { echo '[FAIL] failed job not archived' >&2; exit 1; }
# audit must show archive source, useful timestamp, class fallback, and name.
out="$(queue audit cleared)"
printf '%s\n' "$out" | grep -q 'fake_failed' || { echo '[FAIL] archived job missing from audit' >&2; printf '%s\n' "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'archive' || { echo '[FAIL] audit does not show archive source' >&2; printf '%s\n' "$out" >&2; exit 1; }
printf '%s\n' "$out" | grep -q 'DEFAULT' || { echo '[FAIL] audit class fallback missing' >&2; printf '%s\n' "$out" >&2; exit 1; }
if printf '%s\n' "$out" | grep -q ' 0000 '; then
  echo '[FAIL] audit still shows 0000 timestamp' >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
explain="$(queue explain fake_failed)"
printf '%s\n' "$explain" | grep -q 'QUEUEBASH EXPLAIN: fake_failed' || { echo '[FAIL] explain did not find archived job' >&2; printf '%s\n' "$explain" >&2; exit 1; }
printf '%s\n' "$explain" | grep -q 'Clearance archive' || { echo '[FAIL] explain lacks clearance archive section' >&2; printf '%s\n' "$explain" >&2; exit 1; }
printf '%s\n' "$explain" | grep -q 'job file:' || { echo '[FAIL] explain lacks job file path' >&2; printf '%s\n' "$explain" >&2; exit 1; }
json="$(queue audit cleared --json)"
python3 - "$json" <<'PY'
import json, sys
j=json.loads(sys.argv[1])
assert j['count'] == 1, j
r=j['cleared'][0]
assert r['qid'] == 'fake_failed', r
assert r['clear_source'] == 'archive', r
assert r['state'] == 'failed', r
assert r['class'] == 'DEFAULT', r
assert r['archived_at'], r
assert r['execution_cleared'] is False, r
PY
echo '[PASS] explain archive/audit display smoke checks pass'
