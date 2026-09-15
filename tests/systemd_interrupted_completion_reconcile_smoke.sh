#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "[FAIL] $*" >&2; exit 1; }
root="$(mktemp -d)"
mkdir -p "$root"/{pending,waiting,running,paused,done,failed,pol_blocked,interrupted,cancelled,deleted,logs,workers,outputs,streams,helpers,classes,class.d,envs.d,assets.d,caps.d,reporters.d,policies.d}
cat > "$root/interrupted/ed209b.job" <<JOB
JOB_ID=ed209b
JOB_NAME=audio-calibration-edge
PRIORITY=10
RUNNER_USED=systemd
SYSTEMD_UNIT=queue-ed209b.service
RUN_PID=99999999
INTERRUPTED_REASON=stale-running-detected-by-sentinel
COMMAND=( bash -lc 'true' )
JOB
cat > "$root/logs/ed209b.log" <<'LOG'
=== queue job ed209b : audio-calibration-edge ===
finished: now
exit_code: 0
LOG
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck disable=SC1091
source ./queuebash.sh
_queue_worker_reconcile_stale_interrupted_completion ed209b 0 "$root/logs/ed209b.log" test-worker || fail "reconcile helper returned non-zero"
[[ -f "$root/done/ed209b.job" ]] || fail "stale interrupted systemd completion was not moved to done"
[[ ! -f "$root/interrupted/ed209b.job" ]] || fail "interrupted record remained after completion reconciliation"
grep -q '^RECONCILED_FROM=' "$root/done/ed209b.job" || fail "reconciliation metadata missing"
grep -q '^RECONCILED_REASON=' "$root/done/ed209b.job" || fail "reconciliation reason missing"
rm -rf "$root"
echo "[PASS] stale-interrupted systemd records reconcile to terminal state when payload completion is observed"
