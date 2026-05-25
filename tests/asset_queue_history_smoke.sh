#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source assets.d/queue.sh

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/done" "$root/pending"
export QUEUEBASH_ROOT="$root"

qid="20260524_000000_000000000_000000_1"
cat > "$root/done/$qid.job" <<JOB
JOB_ID='$qid'
JOB_NAME='nightly_export'
SUBMITTED_AT='$(date -Is)'
RUN_STARTED_AT='$(date -Is)'
EXEC_FINISHED_AT='$(date -Is)'
EXIT_CODE=0
COMMAND=( bash /home/hc3/bin/nightly_export.sh )
JOB

queue_asset_check_queue_command_has_run "nightly_export.sh" match=substr time=24h >/tmp/bq_queue_asset_has_run.out
queue_asset_check_queue_command_has_not_run "unmatched_job" match=substr time=24h >/tmp/bq_queue_asset_has_not_run.out

if queue_asset_check_queue_command_has_not_run "nightly_export.sh" match=substr time=24h >/tmp/bq_queue_asset_not_run_bad.out 2>&1; then
    echo "command_has_not_run should block when a recent matching job exists" >&2
    exit 1
fi

grep -q "asset_check_ok: queue:command_has_run" /tmp/bq_queue_asset_has_run.out || exit 1
grep -q "asset_check_ok: queue:command_has_not_run" /tmp/bq_queue_asset_has_not_run.out || exit 1
grep -q "asset_check_blocked: queue:command_has_not_run" /tmp/bq_queue_asset_not_run_bad.out || exit 1

echo "[PASS] functional queue history asset smoke test passed"
