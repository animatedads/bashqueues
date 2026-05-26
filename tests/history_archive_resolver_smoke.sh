#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source "$ROOT/queuebash.sh"
queue list >/dev/null
mkdir -p "$QUEUEBASH_ROOT/clearance/failed"
cat > "$QUEUEBASH_ROOT/clearance/failed/archived_failed_001.job" <<'JOB'
JOB_ID=archived_failed_001
JOB_NAME=archived-history-test
PRIORITY=10
JOB_CLASS=DEFAULT
COMMAND=(bash -c 'echo archived')
SUBMITTED_AT='2026-05-26T17:00:00+01:00'
RUN_STARTED_AT='2026-05-26T17:00:01+01:00'
EXEC_FINISHED_AT='2026-05-26T17:00:02+01:00'
EXIT_CODE=7
QUEUE_CLEARED_ARCHIVED=1
QUEUE_CLEARED_ARCHIVED_AT='2026-05-26T17:01:00+01:00'
QUEUE_CLEARED_ARCHIVED_FROM=failed
JOB

out="$(queue history archived_failed_001)"
grep -q 'QUEUEBASH HISTORY: archived_failed_001' <<<"$out" || { echo "$out" >&2; exit 1; }
grep -Eq 'archived_failed_001[[:space:]]+failed' <<<"$out" || { echo "$out" >&2; exit 1; }
grep -q 'name=archived-history-test' <<<"$out" || { echo "$out" >&2; exit 1; }
grep -q 'exit=7' <<<"$out" || { echo "$out" >&2; exit 1; }

out_name="$(queue history archived-history-test)"
grep -q 'QUEUEBASH HISTORY: archived_failed_001' <<<"$out_name" || { echo "$out_name" >&2; exit 1; }

explain="$(queue explain archived_failed_001)"
grep -q 'state:               failed' <<<"$explain" || { echo "$explain" >&2; exit 1; }

show="$(queue show archived_failed_001)"
grep -q 'clearance/failed/archived_failed_001.job' <<<"$show" || { echo "$show" >&2; exit 1; }

echo "[PASS] history archive resolver smoke checks pass"
