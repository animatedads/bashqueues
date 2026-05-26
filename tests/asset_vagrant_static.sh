#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

bash -n assets.d/vagrant.sh || fail "bash -n failed for assets.d/vagrant.sh"
source assets.d/vagrant.sh

for check in running not_running exists box_exists box_outdated; do
    queue_asset_facilities | grep -q "vagrant:$check" || fail "facility missing: vagrant:$check"
    declare -F "queue_asset_check_vagrant_${check}" >/dev/null || fail "function missing: queue_asset_check_vagrant_${check}"
    queue_asset_hints | grep -q "vagrant:$check" || fail "hint missing: vagrant:$check"
done

(
    PATH=/nonexistent
    result="$(queue_asset_check_vagrant_running "_tok" "dummy" 2>&1 || true)"
    case "$result" in *tool_missing*) ;; *) fail "vagrant:running must emit tool_missing when required tool is absent" ;; esac
)

echo "[PASS] vagrant asset facilities, functions, hints, and tool_missing path are wired"
