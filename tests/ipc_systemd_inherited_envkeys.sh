#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
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

# Force systemd path only where user systemd is usable.
if command -v systemd-run >/dev/null 2>&1 && systemd-run --user --scope true >/dev/null 2>&1; then
    export QUEUEBASH_RUNNER=systemd
else
    export QUEUEBASH_RUNNER=direct
fi

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

consumer_done="$(grep -l '^JOB_NAME=consumer$' "$QUEUEBASH_ROOT"/done/*.job | head -1)"
[[ -n "$consumer_done" ]] || fail "consumer not done"

consumer_id="$(basename "$consumer_done" .job)"
consumer_log="$QUEUEBASH_ROOT/logs/$consumer_id.log"

grep -q '^hello$' "$consumer_log" || fail "consumer did not receive RESULT_PATH"
grep -q '^abc 123$' "$consumer_log" || fail "consumer did not receive CHECKSUM"
grep -q 'inherited_env_keys: .*RESULT_PATH' "$consumer_log" || fail "inherited env keys not logged"
grep -q 'inherited_env_keys: .*CHECKSUM' "$consumer_log" || fail "CHECKSUM inherited key not logged"

if grep -q 'cat: .*No such file or directory' "$consumer_log"; then
    fail "consumer still failed cat inherited path"
fi

if grep -q 'RUNNER_USED=systemd' "$consumer_done"; then
    grep -q -- '--setenv=RESULT_PATH=' "$consumer_log" || fail "systemd launch argv missing RESULT_PATH setenv"
    grep -q -- '--setenv=CHECKSUM=' "$consumer_log" || fail "systemd launch argv missing CHECKSUM setenv"
fi

pass "consumer receives inherited RESULT_PATH"
pass "consumer receives inherited CHECKSUM"
pass "systemd runner receives dynamic env-drop keys"

echo
echo "bashqueues IPC systemd inherited env-key tests: OK"
