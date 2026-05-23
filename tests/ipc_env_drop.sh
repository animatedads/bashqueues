#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1 QUEUEBASH_RUNNER=direct QUEUEBASH_GZIP_LOGS=0
source "$repo_root/queuebash.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp/q"; mkdir -p "$QUEUEBASH_ROOT"
fail(){ echo "[FAIL] $1" >&2; queue list >&2 || true; find "$QUEUEBASH_ROOT" -maxdepth 3 -print >&2 || true; exit 1; }
pass(){ echo "[PASS] $1"; }
queue submit producer -- bash -c 'queue_output RESULT_PATH "'"$tmp"'/result.txt"; queue_output CHECKSUM "abc 123"; echo "hello from producer" > "'"$tmp"'/result.txt"' >/dev/null
queue run >/dev/null || true
producer_job="$(grep -l '^JOB_NAME=producer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"; [[ -n "$producer_job" ]] || fail "producer not done"
producer_id="$(basename "$producer_job" .job)"; env_file="$QUEUEBASH_ROOT/outputs/$producer_id.env"
[[ -f "$env_file" ]] || fail "producer env-drop file missing"; grep -q '^export RESULT_PATH=' "$env_file" || fail "RESULT_PATH not exported"; grep -q '^export CHECKSUM=' "$env_file" || fail "CHECKSUM not exported"
[[ ! -e "$QUEUEBASH_ROOT/streams/$producer_id.fifo" ]] || fail "stream FIFO left behind"
queue submit consumer --inherit-env-from "$producer_id" -- bash -c 'echo "consumer-result=$(cat "$RESULT_PATH")"; echo "consumer-checksum=$CHECKSUM"' >/dev/null
queue run >/dev/null || true
consumer_job="$(grep -l '^JOB_NAME=consumer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"; [[ -n "$consumer_job" ]] || fail "consumer not done"
consumer_id="$(basename "$consumer_job" .job)"; consumer_log="$QUEUEBASH_ROOT/logs/$consumer_id.log"
grep -q 'consumer-result=hello from producer' "$consumer_log" || fail "consumer did not inherit RESULT_PATH"; grep -q 'consumer-checksum=abc 123' "$consumer_log" || fail "consumer did not inherit CHECKSUM"
pass "producer writes env-drop output"; pass "consumer inherits env-drop output"; pass "stream FIFO is cleaned after completion"
echo; echo "bashqueues IPC env-drop tests: OK"
