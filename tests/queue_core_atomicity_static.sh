#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q '_queue_allocate_pending_job_record()' queuebash.sh
grep -q 'set -C; : > "$job"' queuebash.sh
grep -q '_queue_state_lock_acquire()' queuebash.sh
grep -q 'worker-pending-to-running' queuebash.sh
grep -q 'health-mark-interrupted' queuebash.sh
grep -q 'sentinel-pending-to-pol-blocked' queuebash.sh
grep -q 'system-daemon-once' queuebash.sh
grep -q 'QUEUEBASH_LAUNCH_METADATA_GRACE' queuebash.sh
grep -q 'stale_deferred_missing_launch_metadata' queuebash.sh
grep -q 'health-duplicate-live-running' queuebash.sh
grep -q 'Usage: queue $cmd \[--force\]' queuebash.sh
