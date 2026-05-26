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
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    queue list >&2 || true
    find "$QUEUEBASH_ROOT" -maxdepth 4 -print >&2 || true
    find "$QUEUEBASH_ROOT" -type f -name '*.job' -print -exec cat {} \; >&2 || true
    find "$QUEUEBASH_ROOT/logs" -maxdepth 1 -type f -print -exec sh -c 'echo "### $1"; cat "$1"' _ {} \; >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

queue submit producer -- bash -c '
  queue_output RESULT_PATH "'"$tmp"'/result.txt"
  queue_output CHECKSUM "abc 123"
  echo "hello" > "'"$tmp"'/result.txt"
' >/dev/null

queue submit consumer --inherit-env-from producer -- bash -c '
  cat "$RESULT_PATH"
  echo "$CHECKSUM"
' >/dev/null

queue run >/dev/null || true

producer_done="$(grep -l '^JOB_NAME=producer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
consumer_done="$(grep -l '^JOB_NAME=consumer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$producer_done" ]] || fail "producer not done"
[[ -n "$consumer_done" ]] || fail "consumer not done"

producer_id="$(basename "$producer_done" .job)"
[[ -f "$QUEUEBASH_ROOT/outputs/$producer_id.env" ]] || fail "producer output env missing"
grep -q '^export RESULT_PATH=' "$QUEUEBASH_ROOT/outputs/$producer_id.env" || fail "producer RESULT_PATH missing"
grep -q '^export CHECKSUM=' "$QUEUEBASH_ROOT/outputs/$producer_id.env" || fail "producer CHECKSUM missing"

consumer_id="$(basename "$consumer_done" .job)"
consumer_log="$QUEUEBASH_ROOT/logs/$consumer_id.log"
grep -q '^hello$' "$consumer_log" || fail "consumer did not cat inherited RESULT_PATH"
grep -q '^abc 123$' "$consumer_log" || fail "consumer did not echo inherited CHECKSUM"

if grep -q 'requested env-drop source is not available' "$consumer_log"; then
    fail "consumer still reports unavailable env-drop source"
fi
if grep -q "cat: ''" "$consumer_log"; then
    fail "consumer still used empty RESULT_PATH"
fi

pass "producer writes env-drop"
pass "consumer resolves producer name at live dispatch"
pass "consumer inherits RESULT_PATH and CHECKSUM"

echo
echo "bashqueues IPC live name resolver tests: OK"
