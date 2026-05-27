#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.17.94"' queuebash.sh || fail "version not bumped to 0.17.94"
grep -q '_queue_pending_job_files "$root"' queuebash.sh || fail "queue stats does not use bucket-aware pending scan"
stats_block="$(sed -n '/        stats)/,/        events)/p' queuebash.sh)"
! grep -q 'for state in pending running paused done failed pol_blocked policy_blocked interrupted cancelled deleted; do' <<<"$stats_block" || fail "queue stats still exposes legacy policy_blocked state"
grep -q 'for state in pending running paused done failed pol_blocked interrupted cancelled deleted; do' <<<"$stats_block" || fail "queue stats canonical state list not found"

echo "[PASS] stats pending bucket static checks pass"
