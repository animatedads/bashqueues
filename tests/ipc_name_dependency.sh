#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export QUEUEBASH_ROOT="$tmp/q"
mkdir -p "$QUEUEBASH_ROOT"

fail() {
    echo "[FAIL] $1" >&2
    queue list >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 3 -print >&2 || true
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec cat {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

queue submit producer_step -- bash -c '
    queue_output RESULT_PATH "'"$tmp"'/producer_result.txt"
    queue_output MAGIC_VALUE "value from producer"
    echo "producer data" > "'"$tmp"'/producer_result.txt"
' >/dev/null

queue submit consumer_step --inherit-env-from producer_step -- bash -c '
    echo "consumer sees: $(cat "$RESULT_PATH")"
    echo "magic=$MAGIC_VALUE"
' >/dev/null

consumer_pending="$(grep -l '^JOB_NAME=consumer_step$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$consumer_pending" ]] || fail "consumer pending job missing"
grep -q '^INHERIT_ENV_FROM=' "$consumer_pending" || fail "consumer missing INHERIT_ENV_FROM"
grep -q 'producer_step' "$consumer_pending" || fail "consumer inherit metadata missing producer name"
grep -q '^DEPENDS_AFTER_SUCCESS=' "$consumer_pending" || fail "consumer missing DEPENDS_AFTER_SUCCESS"
grep -q 'producer_step' "$consumer_pending" || fail "consumer dependency was not auto-created from inheritance"

queue run >/dev/null || true

producer_done="$(grep -l '^JOB_NAME=producer_step$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
consumer_done="$(grep -l '^JOB_NAME=consumer_step$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$producer_done" ]] || fail "producer not done"
[[ -n "$consumer_done" ]] || fail "consumer not done"

producer_id="$(basename "$producer_done" .job)"
[[ -f "$QUEUEBASH_ROOT/outputs/$producer_id.env" ]] || fail "producer output env missing"

consumer_id="$(basename "$consumer_done" .job)"
consumer_log="$QUEUEBASH_ROOT/logs/$consumer_id.log"
grep -q 'consumer sees: producer data' "$consumer_log" || fail "consumer did not inherit RESULT_PATH by producer name"
grep -q 'magic=value from producer' "$consumer_log" || fail "consumer did not inherit MAGIC_VALUE by producer name"

pass "inherit-env-from accepts producer name"
pass "inherit-env-from auto-creates after-success dependency"
pass "consumer submitted before producer completion inherits env-drop at dispatch"

echo
echo "bashqueues IPC name dependency tests: OK"
