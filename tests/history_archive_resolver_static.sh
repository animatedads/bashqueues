#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }

grep -q 'QUEUEBASH_VERSION="0.17.97"' queuebash.sh || fail "version not bumped to 0.17.95"
grep -q '_queue_find_jobs "$selector"' queuebash.sh || fail "queue history does not use shared resolver"
grep -q '"$root/clearance"/\*/\*.job' queuebash.sh || fail "history child scan does not include clearance archives"
grep -q '_queue_state_for_job_path "$f"' queuebash.sh || fail "history state helper not archive-aware"

if grep -n 'for st in pending running paused done failed pol_blocked policy_blocked interrupted cancelled deleted; do' queuebash.sh | grep -q '_queue_job_history()'; then
  fail "queue history still appears to use a local live-only state loop"
fi

echo "[PASS] history archive resolver static checks pass"
