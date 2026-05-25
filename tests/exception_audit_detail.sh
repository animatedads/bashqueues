#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"
export QUEUEBASH_CLASS_SOURCE_DIR="$repo_root/classes"

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    cat /tmp/after.out 2>/dev/null >&2 || true
    cat "$QUEUEBASH_ROOT/events.jsonl" 2>/dev/null >&2 || true
    cat /tmp/refs.out 2>/dev/null >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

queue assets refresh "$repo_root/assets.d" >/dev/null
queue classes refresh "$repo_root/classes" >/dev/null

tue_1030="$(date -d '2026-05-26 10:30:00' +%s)"

cat > "$QUEUEBASH_ROOT/pending/overnight2.job" <<JOB
JOB_ID=overnight2
JOB_NAME=overnight
JOB_CLASS=OVERNIGHT_WINDOW
PRIORITY=10
COMMAND=( bash -c true )
JOB

queue exception add overnight2 time:window --reason "Sysadmin requires download on weekend" >/dev/null

(
    export QUEUEBASH_TIME_NOW_EPOCH="$tue_1030"
    _queue_class_load_for_job "$QUEUEBASH_ROOT/pending/overnight2.job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/after.out || fail "exception overlay should allow"

grep -q 'asset_exception_applied: job=overnight2 asset=time:window:overnight-window exception=time:window reason=Sysadmin requires download on weekend' /tmp/after.out || fail "stdout exception detail missing"
grep -q 'exception_applied' "$QUEUEBASH_ROOT/events.jsonl" || fail "event missing"
grep -q 'reason=Sysadmin requires download on weekend' "$QUEUEBASH_ROOT/events.jsonl" || fail "event reason missing"
grep -q 'by=' "$QUEUEBASH_ROOT/events.jsonl" || fail "event creator missing"

# The removed exception-class filename must not exist in bundled classes.
if find "$repo_root/classes" -maxdepth 1 -type f -name '*EXCEPTION*' -print | grep . >/tmp/refs.out; then
    fail "exception class file remains"
fi

grep -q 'queue exception add <qid> time:window' "$repo_root/classes/OVERNIGHT_WINDOW.env" || fail "overnight class comment still not overlay-focused"

pass "exception_applied event includes reason and creator"
pass "OVERNIGHT_WINDOW documentation points to QID overlay"
pass "exception class remains absent"

echo
echo "bashqueues exception audit detail tests: OK"
