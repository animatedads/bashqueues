#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

bash -n assets.d/vsphere.sh || fail "bash -n failed for assets.d/vsphere.sh"
source assets.d/vsphere.sh

for check in vm_running vm_not_running vm_exists host_connected datastore_free snapshot_exists task_complete cluster_healthy; do
    queue_asset_facilities | grep -q "vsphere:$check" || fail "facility missing: vsphere:$check"
    declare -F "queue_asset_check_vsphere_${check}" >/dev/null || fail "function missing: queue_asset_check_vsphere_${check}"
    queue_asset_hints | grep -q "vsphere:$check" || fail "hint missing: vsphere:$check"
done

(
    PATH=/nonexistent
    result="$(queue_asset_check_vsphere_vm_running "_tok" "dummy" 2>&1 || true)"
    case "$result" in *tool_missing*) ;; *) fail "vsphere:vm_running must emit tool_missing when required tool is absent" ;; esac
)

# Credential redaction: blocked output must not echo govc_password values.
(
    PATH=/nonexistent
    result="$(queue_asset_check_vsphere_vm_running "_tok" "/dc/vm/app" govc_password=supersecret 2>&1 || true)"
    case "$result" in *supersecret*) fail "vsphere output leaked govc_password" ;; esac
)

echo "[PASS] vsphere asset facilities, functions, hints, and tool_missing path are wired"
