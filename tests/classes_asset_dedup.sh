#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_RUNNER=direct
export QUEUEBASH_GZIP_LOGS=0
export QUEUEBASH_PLUGIN_SOURCE_DIR="$repo_root/assets.d"

source "$repo_root/queuebash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export QUEUEBASH_ROOT="$tmp/q"
_queue_init

fail() {
    echo "[FAIL] $1" >&2
    echo "--- assets ---" >&2
    queue assets >&2 || true
    echo "--- duplicates ---" >&2
    queue assets duplicates >&2 || true
    find "$QUEUEBASH_ROOT/assets.d" -maxdepth 1 -type f -print >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

# Simulate legacy duplicates left behind from older install names.
cp "$QUEUEBASH_ROOT/assets.d/net.sh" "$QUEUEBASH_ROOT/assets.d/network.sh"
cp "$QUEUEBASH_ROOT/assets.d/sys.sh" "$QUEUEBASH_ROOT/assets.d/system.sh"

assets_out="$(queue assets)"

net_count="$(grep -c '^net:http_status[[:space:]]' <<< "$assets_out" || true)"
sys_count="$(grep -c '^sys:cpu_load[[:space:]]' <<< "$assets_out" || true)"
[[ "$net_count" -eq 1 ]] || fail "net:http_status should be de-duplicated"
[[ "$sys_count" -eq 1 ]] || fail "sys:cpu_load should be de-duplicated"

dupes="$(queue assets duplicates)"
grep -q '^net:http_status' <<< "$dupes" || fail "duplicates command should report net:http_status"
grep -q '^sys:cpu_load' <<< "$dupes" || fail "duplicates command should report sys:cpu_load"

pass "queue assets de-duplicates duplicate helper publications"
pass "queue assets duplicates reports legacy duplicate helpers"

echo
echo "bashqueues asset de-dup tests: OK"
