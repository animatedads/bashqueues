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

# Historical producer with same name.
queue submit producer -- bash -c '
  queue_output RESULT_PATH "'"$tmp"'/old.txt"
  echo old > "'"$tmp"'/old.txt"
' >/dev/null
queue run >/dev/null || true

old_done="$(grep -l '^JOB_NAME=producer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$old_done" ]] || fail "old producer not done"

# Fresh producer and consumer. Consumer should bind to fresh pending QID, not old done producer.
queue submit producer -- bash -c '
  queue_output RESULT_PATH "'"$tmp"'/new.txt"
  queue_output CHECKSUM "new checksum"
  echo new > "'"$tmp"'/new.txt"
' >/dev/null

new_pending="$(grep -l '^JOB_NAME=producer$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$new_pending" ]] || fail "new pending producer missing"
new_qid="$(basename "$new_pending" .job)"

queue submit consumer --inherit-env-from producer -- bash -c '
  cat "$RESULT_PATH"
  echo "$CHECKSUM"
' >/dev/null

consumer_pending="$(grep -l '^JOB_NAME=consumer$' "$QUEUEBASH_ROOT"/pending/*.job | head -1)"
[[ -n "$consumer_pending" ]] || fail "consumer pending missing"

grep -q "INHERIT_ENV_FROM=.*$new_qid" "$consumer_pending" || fail "consumer did not bind INHERIT_ENV_FROM to fresh producer QID"
grep -q "DEPENDS_AFTER_SUCCESS=.*$new_qid" "$consumer_pending" || fail "consumer did not bind dependency to fresh producer QID"
if grep -q 'INHERIT_ENV_FROM=producer' "$consumer_pending"; then
    fail "consumer still stores inherit source as ambiguous name"
fi

queue run >/dev/null || true

consumer_done="$(grep -l '^JOB_NAME=consumer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$consumer_done" ]] || fail "consumer not done"
consumer_id="$(basename "$consumer_done" .job)"
consumer_log="$QUEUEBASH_ROOT/logs/$consumer_id.log"

grep -q '^new$' "$consumer_log" || fail "consumer did not read fresh producer output"
grep -q '^new checksum$' "$consumer_log" || fail "consumer did not inherit fresh producer checksum"
if grep -q '^old$' "$consumer_log"; then
    fail "consumer inherited old historical producer output"
fi

pass "inherit-env-from name binds to fresh pending producer QID"
pass "auto dependency also binds to fresh producer QID"
pass "consumer inherits fresh producer env despite older same-name done job"

echo
echo "bashqueues IPC submit-time QID binding tests: OK"
