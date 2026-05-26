#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

bash -n assets.d/lxc.sh || fail "bash -n failed for assets.d/lxc.sh"
source assets.d/lxc.sh

for check in running not_running exists healthy image_exists profile_exists storage_pool_ok; do
    queue_asset_facilities | grep -q "lxc:$check" || fail "facility missing: lxc:$check"
    declare -F "queue_asset_check_lxc_${check}" >/dev/null || fail "function missing: queue_asset_check_lxc_${check}"
    queue_asset_hints | grep -q "lxc:$check" || fail "hint missing: lxc:$check"
done

(
    PATH=/nonexistent
    result="$(queue_asset_check_lxc_running "_tok" "dummy" 2>&1 || true)"
    case "$result" in *tool_missing*) ;; *) fail "lxc:running must emit tool_missing when required tool is absent" ;; esac
)

echo "[PASS] lxc asset facilities, functions, hints, and tool_missing path are wired"
