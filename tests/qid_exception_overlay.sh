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
    echo "--- exceptions ---" >&2
    find "$QUEUEBASH_ROOT/exceptions" -type f -maxdepth 2 -print -exec cat {} \; 2>/dev/null >&2 || true
    echo "--- outputs ---" >&2
    cat /tmp/before.out /tmp/after.out /tmp/explain.out /tmp/history.out 2>/dev/null >&2 || true
    echo "--- events ---" >&2
    cat "$QUEUEBASH_ROOT/events.jsonl" 2>/dev/null >&2 || true
    exit 1
}
pass(){ echo "[PASS] $1"; }

queue assets refresh "$repo_root/assets.d" >/dev/null
queue classes refresh "$repo_root/classes" >/dev/null

tue_1030="$(date -d '2026-05-26 10:30:00' +%s)"

cat > "$QUEUEBASH_ROOT/pending/overnight1.job" <<JOB
JOB_ID=overnight1
JOB_NAME=overnight
JOB_CLASS=OVERNIGHT_WINDOW
PRIORITY=10
COMMAND=( bash -c true )
JOB

(
    export QUEUEBASH_TIME_NOW_EPOCH="$tue_1030"
    _queue_class_load_for_job "$QUEUEBASH_ROOT/pending/overnight1.job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/before.out && fail "job should be blocked before exception" || true

grep -q 'asset_check_blocked: time:window outside_allowed_window' /tmp/before.out || fail "before exception did not show time block"

queue exception add overnight1 time:window --reason "operator approved daytime run" >/dev/null || fail "exception add failed"
queue exception list overnight1 | grep -q 'operator approved daytime run' || fail "exception list missing reason"

(
    export QUEUEBASH_TIME_NOW_EPOCH="$tue_1030"
    _queue_class_load_for_job "$QUEUEBASH_ROOT/pending/overnight1.job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/after.out || fail "job should pass after exception overlay"

grep -q 'asset_exception_applied: job=overnight1 asset=time:window:overnight-window exception=time:window' /tmp/after.out || fail "exception application not reported"

queue explain overnight1 >/tmp/explain.out || fail "explain failed"
grep -q 'Exception overlays' /tmp/explain.out || fail "explain missing exception overlay section"
grep -q 'ignore: time:window' /tmp/explain.out || fail "explain missing time exception"

grep -q 'exception_added' "$QUEUEBASH_ROOT/events.jsonl" || fail "exception_added event missing"
grep -q 'exception_applied' "$QUEUEBASH_ROOT/events.jsonl" || fail "exception_applied event missing"

queue exception clear overnight1 time:window >/dev/null || fail "exception clear failed"

(
    export QUEUEBASH_TIME_NOW_EPOCH="$tue_1030"
    _queue_class_load_for_job "$QUEUEBASH_ROOT/pending/overnight1.job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/cleared.out && fail "job should block again after clear" || true

grep -q 'asset_check_blocked: time:window outside_allowed_window' /tmp/cleared.out || fail "cleared exception did not restore block"

pass "QID exception overlay skips selected time restriction without exception class"
pass "exception add/list/clear are auditable"
pass "queue explain shows active exception overlays"

echo
echo "bashqueues QID exception overlay tests: OK"
