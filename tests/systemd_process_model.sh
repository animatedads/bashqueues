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
    queue health --deep >&2 || true
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec cat {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

parsed="$(_queue_systemd_unit_clean 'run-p1148361-i1148362.service; invocation ID: c67ba70fa61c4c9293de08e9c14ac11f')"
[[ "$parsed" == "run-p1148361-i1148362.service" ]] || fail "systemd unit clean failed: $parsed"

cat > "$QUEUEBASH_ROOT/running/fake_systemd.job" <<FAKE
JOB_ID=fake_systemd
JOB_NAME=fake_systemd
PRIORITY=10
RUNNER_USED=systemd
SYSTEMD_UNIT=definitely-not-a-real-queuebash-unit.service
RUN_PID=$$
RUN_PGID=$$
COMMAND=( true )
FAKE

if queue health > "$tmp/health.txt"; then
    fail "health unexpectedly passed with dead systemd unit and live RUN_PID"
fi
grep -q 'stale running job' "$tmp/health.txt" || fail "dead systemd unit was not reported stale"

queue health --fix > "$tmp/fix.txt" || fail "health --fix failed"
[[ -f "$QUEUEBASH_ROOT/interrupted/fake_systemd.job" ]] || fail "dead systemd unit job was not moved to interrupted"

grep -q '^INTERRUPTED_REASON=' "$QUEUEBASH_ROOT/interrupted/fake_systemd.job" || fail "interrupted metadata missing"

queue explain fake_systemd > "$tmp/explain.txt" || true
grep -q 'systemd-run client' "$tmp/explain.txt" || fail "explain did not label RUN_PID as systemd-run client"

pass "systemd unit parsing strips invocation ID"
pass "health treats dead systemd unit as stale even with live RUN_PID"
pass "health --fix moves stale systemd job to interrupted"
pass "explain labels RUN_PID as systemd-run client"

echo
echo "bashqueues systemd process-model tests: OK"
