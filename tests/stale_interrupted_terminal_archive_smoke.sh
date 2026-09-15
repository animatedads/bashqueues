#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
source ./queuebash.sh
_queue_init >/dev/null 2>&1 || true
id="TERMDUP001"
mkdir -p "$root/done" "$root/interrupted" "$root/logs"
cat > "$root/done/$id.job" <<JOB
JOB_ID=$id
JOB_NAME=done_duplicate_test
PRIORITY=10
COMMAND=( true )
JOB
cat > "$root/interrupted/$id.job" <<JOB
JOB_ID=$id
JOB_NAME=done_duplicate_test
PRIORITY=10
COMMAND=( true )
INTERRUPTED_REASON=stale-running-detected-by-sentinel
INTERRUPTED_FROM=running
JOB
_queue_worker_archive_stale_interrupted_duplicate "$id" done
[[ ! -f "$root/interrupted/$id.job" ]]
find "$root/logs/queue-state-reconcile" -type f -name "$id.interrupted.duplicate.*.job" | grep -q .

echo "PASS stale interrupted terminal archive smoke"
