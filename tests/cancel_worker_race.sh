#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT"/{pending,running,paused,done,failed,interrupted,cancelled,deleted,logs,workers}

fail() {
    echo "[FAIL] $1" >&2
    find "$QUEUEBASH_ROOT" -type f -print -exec cat {} \; >&2 || true
    echo "--- explain ---" >&2
    queue explain fake_systemd >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

cat > "$QUEUEBASH_ROOT/cancelled/racejob.job" <<'JOB'
JOB_ID=racejob
JOB_NAME=racejob
PRIORITY=10
COMMAND=( true )
JOB

state="$(_queue_worker_external_move_state racejob)"
[[ "$state" == "cancelled" ]] || fail "external move state did not detect cancelled"

grep -q 'operator cancellation observed' "$repo_root/queuebash.sh" || fail "worker cancellation race message missing"
grep -q 'worker_observed_cancelled' "$repo_root/queuebash.sh" || fail "worker cancellation event missing"

cat > "$QUEUEBASH_ROOT/cancelled/fake_systemd.job" <<'JOB'
JOB_ID=fake_systemd
JOB_NAME=fake_systemd
PRIORITY=10
RUNNER_USED=systemd
SYSTEMD_UNIT=unit.service
RUN_PID=123
COMMAND=( true )
JOB

queue explain fake_systemd > "$tmp/explain.txt" || true
grep -q 'does not PGID-fallback' "$tmp/explain.txt" || fail "systemd cancellation wording not updated"

pass "external moved state detects cancelled"
pass "worker race branch reports cancelled"
pass "systemd cancellation model wording updated"

echo
echo "bashqueues cancel/worker race tests: OK"
