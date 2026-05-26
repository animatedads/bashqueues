#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

bash -n assets.d/vm.sh || fail "bash -n failed for assets.d/vm.sh"
source assets.d/vm.sh

for check in running not_running exists snapshot_exists disk_available disk_format disk_age pool_active net_active vcpu_count; do
    queue_asset_facilities | grep -q "vm:$check" || fail "facility missing: vm:$check"
    declare -F "queue_asset_check_vm_${check}" >/dev/null || fail "function missing: queue_asset_check_vm_${check}"
    queue_asset_hints | grep -q "vm:$check" || fail "hint missing: vm:$check"
done

(
    PATH=/nonexistent
    result="$(queue_asset_check_vm_running "_tok" "dummy" 2>&1 || true)"
    case "$result" in *tool_missing*) ;; *) fail "vm:running must emit tool_missing when required tool is absent" ;; esac
)

echo "[PASS] vm asset facilities, functions, hints, and tool_missing path are wired"
