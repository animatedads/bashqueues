#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT"

fail() {
    echo "[FAIL] $1" >&2
    queue list >&2 || true
    queue scheduled >&2 || true
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec cat {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

run_queue_bounded() {
    timeout 3s bash -lc '
        set -e
        export QUEUEBASH_ALLOW_NONINTERACTIVE=1
        export QUEUEBASH_RUNNER=direct
        export QUEUEBASH_ROOT="$1"
        source "$2/queuebash.sh"
        queue run >/dev/null || true
    ' _ "$QUEUEBASH_ROOT" "$repo_root" || true
}

queue submit-in 5s delayed_job -- bash -c 'echo delayed > "$QUEUEBASH_ROOT/delayed.ran"' >/dev/null

queue scheduled > "$tmp/scheduled.txt"
grep -q 'delayed_job' "$tmp/scheduled.txt" || fail "scheduled job not listed"

run_queue_bounded
[[ ! -f "$QUEUEBASH_ROOT/delayed.ran" ]] || fail "delayed job ran before schedule"

sleep 6

run_queue_bounded
[[ -f "$QUEUEBASH_ROOT/delayed.ran" ]] || fail "delayed job did not run after schedule"

queue submit-at "$(date -d '+5 seconds' '+%Y-%m-%d %H:%M:%S')" at_job -- bash -c 'echo at > "$QUEUEBASH_ROOT/at.ran"' >/dev/null

queue scheduled > "$tmp/scheduled_at.txt"
grep -q 'at_job' "$tmp/scheduled_at.txt" || fail "submit-at job not listed"

run_queue_bounded
[[ ! -f "$QUEUEBASH_ROOT/at.ran" ]] || fail "submit-at job ran before schedule"

sleep 6

run_queue_bounded
[[ -f "$QUEUEBASH_ROOT/at.ran" ]] || fail "submit-at job did not run after schedule"

pass "submit-in delay works"
pass "submit-at absolute time works"

echo
echo "bashqueues scheduling tests: OK"
