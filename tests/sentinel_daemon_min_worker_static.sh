#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
grep -q 'daemon)' queuebash.sh
grep -q -- '--min-workers' queuebash.sh
grep -q '_queue_sentinel_ensure_min_workers' queuebash.sh
grep -q 'sentinel_worker_started' queuebash.sh
echo "[PASS] daemon sentinel min-worker guard is wired"
