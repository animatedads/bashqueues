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
    queue asset-hints >&2 || true
    queue mgr hint old:thing >&2 || true
    exit 1
}

pass() { echo "[PASS] $1"; }

# Old-style helper: facilities only, no queue_asset_hints.
cat > "$QUEUEBASH_ROOT/assets.d/old.sh" <<'PLUGIN'
queue_asset_facilities() {
    echo "old:thing    Old helper with no hint function"
}
queue_asset_check_old_thing() {
    echo "asset_check_ok: old:thing"
}
PLUGIN

hint="$(queue asset-hint old:thing)"
grep -q 'Facility: old:thing' <<< "$hint" || fail "fallback hint missing facility"
grep -q 'see helper/plugin documentation' <<< "$hint" || fail "fallback hint missing generic target"
grep -q 'Old helper with no hint function' <<< "$hint" || fail "fallback hint missing facility description"

queue asset-hints | grep -q 'old:thing' || fail "asset-hints missing old helper fallback"

mgr_hint="$(queue mgr hint old:thing)"
grep -q 'Facility: old:thing' <<< "$mgr_hint" || fail "QueueManager did not show fallback hint"

unknown="$(queue mgr hint no:such_facility || true)"
count="$(grep -c 'No published helper hint' <<< "$unknown" || true)"
[[ "$count" -eq 1 ]] || fail "unknown hint should print one fallback message, got $count"

pass "old helpers synthesize hints from published facilities"
pass "QueueManager consumes synthesized hints"
pass "unknown hints are not double-printed"

echo
echo "bashqueues asset hint fallback tests: OK"
