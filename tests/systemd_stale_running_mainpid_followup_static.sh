#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }
grep -q 'recorded systemd unit but unqueryable/unknown: defer' queuebash.sh || fail "unknown systemd unit must defer, not RUN_PID fallback"
grep -q '_queue_worker_reconcile_stale_interrupted_completion' queuebash.sh || fail "worker completion reconciliation helper missing"
grep -q 'payload-completed-after-stale-running-interrupt' queuebash.sh || fail "reconciliation reason missing"
grep -q 'stale-running-detected-by-sentinel' queuebash.sh || fail "sentinel stale reason not recognised"
echo "[PASS] systemd stale-running follow-up guardrails are wired"
