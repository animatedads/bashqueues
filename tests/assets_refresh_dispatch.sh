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
    echo "--- assets refresh output ---" >&2
    cat /tmp/assets_refresh.out 2>/dev/null >&2 || true
    queue assets validate >&2 || true
    queue assets explain runnable:path_safe >&2 || true
    exit 1
}

pass(){ echo "[PASS] $1"; }

rm -f "$QUEUEBASH_ROOT/assets.d/runnable.sh"

queue assets refresh "$repo_root/assets.d" >/tmp/assets_refresh.out 2>&1 || fail "assets refresh failed"

grep -q 'Refreshing asset plugin family=runnable' /tmp/assets_refresh.out || fail "asset refresh did not process runnable helper"
if grep -q 'queue classes refresh' /tmp/assets_refresh.out || grep -q 'directory not found: refresh' /tmp/assets_refresh.out; then
    fail "assets refresh incorrectly routed to class refresh"
fi

[[ -f "$QUEUEBASH_ROOT/assets.d/runnable.sh" ]] || fail "runnable helper was not installed"
queue assets validate runnable >/dev/null || fail "refreshed runnable helper did not validate"
queue assets | grep -q 'runnable:path_safe' || fail "refreshed runnable helper did not publish path_safe"
queue asset-hint runnable:path_safe | grep -q 'allow_relative' || fail "path_safe hint missing after refresh"
explain="$(queue assets explain runnable:path_safe || true)"
grep -q 'queue_asset_check_runnable_path_safe' <<< "$explain" || fail "asset explain did not resolve path_safe function"

pass "queue assets refresh routes to asset plugin refresh"
pass "refreshed runnable helper publishes runnable:path_safe"
pass "asset explain/hints work for runnable:path_safe after refresh"

echo
echo "bashqueues asset refresh dispatch tests: OK"
