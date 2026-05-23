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
    find "$QUEUEBASH_ROOT" -maxdepth 3 -print >&2 || true
    find "$QUEUEBASH_ROOT" -type f -print -exec cat {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

grep -q 'systemctl --user kill --kill-whom=all' "$repo_root/queuebash.sh" || fail "missing --kill-whom=all systemd kill"
grep -q 'Do not PGID-fallback by default' "$repo_root/queuebash.sh" || fail "missing no-PGID-fallback guard"

cat > "$QUEUEBASH_ROOT/running/fake_unit.job" <<FAKE
JOB_ID=fake_unit
JOB_NAME=fake_unit
PRIORITY=10
RUNNER_USED=systemd
SYSTEMD_UNIT=definitely-not-a-real-queuebash-unit.service
RUN_PID=$$
RUN_PGID=$$
COMMAND=( sleep 999 )
FAKE

mkfifo "$QUEUEBASH_ROOT/logs/.fake_unit.stdout.fifo"
mkfifo "$QUEUEBASH_ROOT/logs/.fake_unit.stderr.fifo"
touch "$QUEUEBASH_ROOT/logs/.fake_unit.stdout.suppressed"

queue kill fake_unit --force > "$tmp/kill.out" 2>"$tmp/kill.err" || true

grep -q 'Sending -KILL to systemd unit definitely-not-a-real-queuebash-unit.service' "$tmp/kill.out" || fail "kill did not target systemd unit"
if grep -q 'Fallback: sending -KILL' "$tmp/kill.out"; then
    fail "systemd kill still fell back to PGID/PID"
fi

[[ -f "$QUEUEBASH_ROOT/cancelled/fake_unit.job" ]] || fail "job not moved to cancelled"
[[ ! -e "$QUEUEBASH_ROOT/logs/.fake_unit.stdout.fifo" ]] || fail "stdout fifo not cleaned"
[[ ! -e "$QUEUEBASH_ROOT/logs/.fake_unit.stderr.fifo" ]] || fail "stderr fifo not cleaned"
[[ ! -e "$QUEUEBASH_ROOT/logs/.fake_unit.stdout.suppressed" ]] || fail "suppression marker not cleaned"

# Health should also clean stale stream temp files for non-running jobs.
touch "$QUEUEBASH_ROOT/logs/.orphan.stdout.suppressed"
mkfifo "$QUEUEBASH_ROOT/logs/.orphan.stderr.fifo"
queue health --fix > "$tmp/health.out" || true
[[ ! -e "$QUEUEBASH_ROOT/logs/.orphan.stdout.suppressed" ]] || fail "health did not remove stale suppressed marker"
[[ ! -e "$QUEUEBASH_ROOT/logs/.orphan.stderr.fifo" ]] || fail "health did not remove stale fifo"

pass "systemd kill uses unit target"
pass "systemd kill does not fallback to RUN_PGID"
pass "stream temp files cleaned on cancel"
pass "health --fix cleans stale stream temp files"

echo
echo "bashqueues systemd no-PGID-fallback tests: OK"
