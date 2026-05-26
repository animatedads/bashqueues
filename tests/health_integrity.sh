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
    queue health --deep >&2 || true
    find "$QUEUEBASH_ROOT" -type f -print -exec cat {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

queue list >/dev/null
queue health > "$tmp/health1.txt" || fail "initial health failed"
grep -q 'OK root writable' "$tmp/health1.txt" || fail "root writable check missing"
grep -q 'OK events.jsonl writable' "$tmp/health1.txt" || fail "events writable check missing"

rm -rf "$QUEUEBASH_ROOT/cancelled"
queue health > "$tmp/health_init.txt" || fail "health failed after queue init recreated missing dir"
[[ -d "$QUEUEBASH_ROOT/cancelled" ]] || fail "queue init did not recreate cancelled dir before health"
grep -q 'OK directory: cancelled' "$tmp/health_init.txt" || fail "cancelled dir not reported OK"

cat > "$QUEUEBASH_ROOT/pending/bad.job" <<'BAD'
JOB_ID=bad
JOB_NAME=bad
PRIORITY=not_an_int
BAD

if queue health > "$tmp/health_bad.txt"; then
    fail "health unexpectedly passed with malformed job"
fi
grep -q 'non-integer PRIORITY' "$tmp/health_bad.txt" || fail "malformed priority not reported"

rm -f "$QUEUEBASH_ROOT/pending/bad.job"

cat > "$QUEUEBASH_ROOT/running/stale.job" <<'STALE'
JOB_ID=stale
JOB_NAME=stalejob
PRIORITY=10
RUN_PID=99999999
COMMAND=( true )
STALE

if queue health > "$tmp/health_stale.txt"; then
    fail "health unexpectedly passed with stale running job"
fi
grep -q 'stale running job' "$tmp/health_stale.txt" || fail "stale running job not reported"

queue health --fix > "$tmp/health_stale_fix.txt" || fail "health --fix failed on stale running"
[[ -f "$QUEUEBASH_ROOT/interrupted/stale.job" ]] || fail "stale job was not moved to interrupted"
grep -q '^INTERRUPTED_REASON=' "$QUEUEBASH_ROOT/interrupted/stale.job" || fail "interrupted metadata missing"

queue submit cycle_a --after-success cycle_b -- true >/dev/null
queue submit cycle_b --after-success cycle_a -- true >/dev/null

queue health --deep > "$tmp/health_deep.txt" || true
grep -q 'dependency' "$tmp/health_deep.txt" || fail "dependency warnings missing"
grep -q 'cycle' "$tmp/health_deep.txt" || fail "cycle hint missing"

pass "health basic checks work"
pass "health observes queue init directory repair"
pass "health detects malformed jobs"
pass "health moves stale running jobs to interrupted"
pass "health --deep reports dependency cycle hints"

echo
echo "bashqueues health-integrity tests: OK"
