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
    echo "--- time validate ---" >&2
    queue assets validate time >&2 || true
    echo "--- outputs ---" >&2
    cat /tmp/tue_block.out /tmp/tue_ok.out /tmp/sat_ok.out /tmp/exception.out 2>/dev/null >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

queue assets refresh "$repo_root/assets.d" >/dev/null
queue classes refresh "$repo_root/classes" >/dev/null

queue assets validate time >/dev/null || fail "time helper did not validate"
queue assets | grep -q 'time:window' || fail "time:window facility missing"

tue_1030="$(date -d '2026-05-26 10:30:00' +%s)"
tue_1900="$(date -d '2026-05-26 19:00:00' +%s)"
sat_1030="$(date -d '2026-05-30 10:30:00' +%s)"

cat > "$QUEUEBASH_ROOT/pending/tue.job" <<JOB
JOB_ID=tue
JOB_NAME=overnight
JOB_CLASS=OVERNIGHT_WINDOW
PRIORITY=10
COMMAND=( bash -c true )
JOB

(
    export QUEUEBASH_TIME_NOW_EPOCH="$tue_1030"
    _queue_class_load_for_job "$QUEUEBASH_ROOT/pending/tue.job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/tue_block.out && fail "Tuesday 10:30 should be blocked" || true

grep -q 'asset_check_blocked: time:window outside_allowed_window' /tmp/tue_block.out || fail "blocked output missing time window reason"

(
    export QUEUEBASH_TIME_NOW_EPOCH="$tue_1900"
    _queue_class_load_for_job "$QUEUEBASH_ROOT/pending/tue.job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/tue_ok.out || fail "Tuesday 19:00 should be allowed"

grep -q 'asset_check_ok: time:window' /tmp/tue_ok.out || fail "Tuesday 19:00 missing ok output"

(
    export QUEUEBASH_TIME_NOW_EPOCH="$sat_1030"
    _queue_class_load_for_job "$QUEUEBASH_ROOT/pending/tue.job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/sat_ok.out || fail "Saturday 10:30 should be allowed"

grep -q 'matched=weekend' /tmp/sat_ok.out || fail "Saturday did not match weekend"

queue exception add tue time:window --reason "operator approved daytime run" >/dev/null || fail "exception overlay add failed"

(
    export QUEUEBASH_TIME_NOW_EPOCH="$tue_1030"
    _queue_class_load_for_job "$QUEUEBASH_ROOT/pending/tue.job" >/dev/null
    _queue_asset_implied_preflight_for_class
) >/tmp/exception.out || fail "QID exception overlay should allow Tuesday 10:30"

grep -q 'asset_exception_applied: job=tue asset=time:window:overnight-window exception=time:window' /tmp/exception.out || fail "exception overlay application missing"

pass "time:window blocks weekday daytime"
pass "time:window allows weekday overnight and weekends"
pass "QID exception overlay explicitly bypasses selected time restriction"

echo
echo "bashqueues time window asset tests: OK"
