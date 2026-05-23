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
  final="'"$tmp"'/good.txt"
  echo "good automatic preflight" > "$final"
  queue_output_file RESULT_PATH "$final"
' >/dev/null

queue submit consumer --inherit-env-from producer -- bash -c '
  cat "$RESULT_PATH"
  echo payload-ran
' >/dev/null

queue run >/dev/null || true

consumer_done="$(grep -l '^JOB_NAME=consumer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$consumer_done" ]] || fail "consumer should have completed"
consumer_id="$(basename "$consumer_done" .job)"
consumer_log="$QUEUEBASH_ROOT/logs/$consumer_id.log"
grep -q '^good automatic preflight$' "$consumer_log" || fail "consumer did not read validated file"
grep -q '^payload-ran$' "$consumer_log" || fail "consumer payload did not run"
grep -q 'auto_required_files: RESULT_PATH' "$consumer_log" || fail "auto required file key not logged"
grep -q 'preflight_require_file_ok: RESULT_PATH' "$consumer_log" || fail "automatic preflight ok not logged"

queue submit producer_bad -- bash -c '
  final="'"$tmp"'/bad.txt"
  echo "original" > "$final"
  queue_output_file BAD_PATH "$final"
  echo "tampered" > "$final"
' >/dev/null

queue submit consumer_bad --inherit-env-from producer_bad -- bash -c '
  echo should-not-run
' >/dev/null

queue run >/dev/null || true

bad_failed="$(grep -l '^JOB_NAME=consumer_bad$' "$QUEUEBASH_ROOT"/failed/*.job 2>/dev/null | head -1 || true)"
[[ -n "$bad_failed" ]] || fail "consumer_bad should have failed automatic preflight"

bad_id="$(basename "$bad_failed" .job)"
bad_log="$QUEUEBASH_ROOT/logs/$bad_id.log"
grep -q 'auto_required_files: BAD_PATH' "$bad_log" || fail "bad auto required file key not logged"
grep -q 'preflight_require_file: BAD_PATH' "$bad_log" || fail "automatic preflight check not logged"
grep -q 'queue_require_file: .*mismatch' "$bad_log" || fail "automatic preflight mismatch not reported"
grep -q 'PRE_FLIGHT_REQUIRE_FILE_FAILED: exit_code=14' "$bad_log" || fail "preflight failure marker or rc missing"
if grep -q '^should-not-run$' "$bad_log"; then
    fail "payload ran despite failed automatic preflight"
fi

pass "automatic preflight validates good inherited file"
pass "automatic preflight blocks tampered inherited file"
pass "payload is not launched after automatic preflight failure"

echo
echo "bashqueues IPC automatic preflight checksum tests: OK"
