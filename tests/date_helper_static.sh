#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
grep -q "printf '%(%s)T" queuebash.sh || { echo '[FAIL] _queue_now_epoch does not use bash printf time' >&2; exit 1; }
grep -q 'EPOCHREALTIME' queuebash.sh || { echo '[FAIL] _queue_now_nonce does not use EPOCHREALTIME' >&2; exit 1; }
grep -q '_queue_now_iso' queuebash.sh || { echo '[FAIL] _queue_now_iso missing' >&2; exit 1; }
grep -q 'clear_source' queuebash.sh || { echo '[FAIL] audit clear_source missing' >&2; exit 1; }
grep -q 'clearance"/\*/\*.job' queuebash.sh || { echo '[FAIL] _queue_find_jobs does not search clearance archives' >&2; exit 1; }
echo '[PASS] date helper/static archive checks pass'
