#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q '_queue_health_job_run_process_alive' queuebash.sh
grep -q '_queue_health_reconcile_duplicate_running_interrupted' queuebash.sh
grep -q '_queue_worker_archive_stale_interrupted_duplicate' queuebash.sh
grep -q 'duplicate_state_reconciled' queuebash.sh
grep -q 'interrupted_duplicate_deferred' queuebash.sh

echo "PASS stale direct duplicate reconcile static"
