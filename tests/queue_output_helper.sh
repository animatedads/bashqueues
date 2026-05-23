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
    exit 1
}

pass() { echo "[PASS] $1"; }

# Prove queue_output is an external command available through PATH, not only a shell function.
queue submit producer -- bash -c '
    type queue_output
    queue_output RESULT_PATH "'"$tmp"'/result.txt"
    queue_output CHECKSUM "abc 123"
    echo "hello" > "'"$tmp"'/result.txt"
' >/dev/null

queue submit consumer --inherit-env-from producer -- bash -c '
    echo "consumer-result=$(cat "$RESULT_PATH")"
    echo "consumer-checksum=$CHECKSUM"
' >/dev/null

queue run >/dev/null || true

producer_job="$(grep -l '^JOB_NAME=producer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
consumer_job="$(grep -l '^JOB_NAME=consumer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$producer_job" ]] || fail "producer not done"
[[ -n "$consumer_job" ]] || fail "consumer not done"

producer_id="$(basename "$producer_job" .job)"
env_file="$QUEUEBASH_ROOT/outputs/$producer_id.env"
[[ -f "$env_file" ]] || fail "producer env-drop missing"
grep -q '^export RESULT_PATH=' "$env_file" || fail "RESULT_PATH missing from env-drop"
grep -q '^export CHECKSUM=' "$env_file" || fail "CHECKSUM missing from env-drop"

consumer_id="$(basename "$consumer_job" .job)"
consumer_log="$QUEUEBASH_ROOT/logs/$consumer_id.log"
grep -q 'consumer-result=hello' "$consumer_log" || fail "consumer did not inherit RESULT_PATH"
grep -q 'consumer-checksum=abc 123' "$consumer_log" || fail "consumer did not inherit CHECKSUM"

producer_log="$QUEUEBASH_ROOT/logs/$producer_id.log"
grep -q 'queue_output is' "$producer_log" || fail "queue_output was not found by type"

# Static guard for systemd runner: explicit env passing is present.
grep -q -- '--setenv=' "$repo_root/queuebash.sh" || fail "systemd env passing missing"

pass "queue_output is available as external helper command"
pass "producer writes env-drop under helper command"
pass "consumer inherits producer env-drop"
pass "systemd runner has explicit --setenv propagation"

echo
echo "bashqueues queue_output helper tests: OK"
