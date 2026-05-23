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
    queue dispatch-trace >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

out="$(queue dispatch-trace || true)"
grep -q 'No dispatch trace found' <<< "$out" || fail "dispatch-trace should report absent trace"

queue submit runnable -- bash -c 'echo runnable' >/dev/null
out="$(queue explain runnable || true)"
grep -q 'Dispatch decision' <<< "$out" || fail "explain should still show dispatch decision"
grep -q 'Claim/lock snapshot' <<< "$out" || fail "runnable explain should show claim/lock snapshot"

pass "dispatch trace command is available"
pass "runnable explain shows claim/lock snapshot"

echo
echo "bashqueues dispatch trace command tests: OK"
