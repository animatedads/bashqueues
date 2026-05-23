#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_RUNNER=direct

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
  tmp="'"$tmp"'/result.txt.tmp"
  final="'"$tmp"'/result.txt"
  echo "hello checksum" > "$tmp"
  mv "$tmp" "$final"
  queue_output_file RESULT_PATH "$final"
' >/dev/null

queue submit consumer --inherit-env-from producer -- bash -e -c '
  queue_require_file RESULT_PATH
  cat "$RESULT_PATH"
  echo "$RESULT_PATH_SHA256" | grep -E "^[0-9a-f]{64}$" >/dev/null
  echo "validated"
' >/dev/null

queue run >/dev/null || true

producer_done="$(grep -l '^JOB_NAME=producer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
consumer_done="$(grep -l '^JOB_NAME=consumer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$producer_done" ]] || fail "producer not done"
[[ -n "$consumer_done" ]] || fail "consumer not done"

producer_id="$(basename "$producer_done" .job)"
env_file="$QUEUEBASH_ROOT/outputs/$producer_id.env"

grep -q '^export RESULT_PATH=' "$env_file" || fail "RESULT_PATH missing"
grep -q '^export RESULT_PATH_SHA256=' "$env_file" || fail "RESULT_PATH_SHA256 missing"
grep -q '^export RESULT_PATH_BYTES=' "$env_file" || fail "RESULT_PATH_BYTES missing"
grep -q '^export RESULT_PATH_MTIME=' "$env_file" || fail "RESULT_PATH_MTIME missing"

consumer_id="$(basename "$consumer_done" .job)"
consumer_log="$QUEUEBASH_ROOT/logs/$consumer_id.log"
grep -q '^hello checksum$' "$consumer_log" || fail "consumer did not read validated file"
grep -q '^validated$' "$consumer_log" || fail "consumer did not validate file"

queue submit producer_bad -- bash -c '
  final="'"$tmp"'/bad.txt"
  echo "original" > "$final"
  queue_output_file BAD_PATH "$final"
  echo "tampered" > "$final"
' >/dev/null

queue submit consumer_bad --inherit-env-from producer_bad -- bash -e -c '
  queue_require_file BAD_PATH
  echo should-not-run
' >/dev/null

queue run >/dev/null || true

bad_failed="$(grep -l '^JOB_NAME=consumer_bad$' "$QUEUEBASH_ROOT"/failed/*.job 2>/dev/null | head -1 || true)"
[[ -n "$bad_failed" ]] || fail "consumer_bad should have failed checksum validation"

bad_id="$(basename "$bad_failed" .job)"
bad_log="$QUEUEBASH_ROOT/logs/$bad_id.log"
grep -q 'queue_require_file: .*mismatch' "$bad_log" || fail "checksum/size mismatch not reported"
if grep -q '^should-not-run$' "$bad_log"; then
    fail "consumer_bad continued after failed validation"
fi

pass "queue_output_file publishes checksum metadata"
pass "queue_require_file validates good hand-off"
pass "queue_require_file fails tampered hand-off with fail-fast shell"

echo
echo "bashqueues IPC checksum tests: OK"
