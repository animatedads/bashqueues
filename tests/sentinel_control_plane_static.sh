#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -q 'QUEUEBASH_VERSION="0.17.51"' queuebash.sh || fail "version not bumped"
grep -q '_queue_sentinel_command' queuebash.sh || fail "sentinel command missing"
grep -q '_queue_sentinel_tick' queuebash.sh || fail "sentinel tick missing"
grep -q '_queue_sentinel_eval_deadlines' queuebash.sh || fail "sentinel deadline evaluator missing"
grep -q '_queue_sentinel_check_pending_policy' queuebash.sh || fail "sentinel policy gate missing"
grep -q 'sentinel|supervisor|supervise|scheduler)' queuebash.sh || fail "sentinel aliases missing"
grep -q 'queue sentinel \[--once\]' queuebash.sh || fail "help not updated"

echo "[PASS] queue sentinel cheap control-plane loop is wired"
