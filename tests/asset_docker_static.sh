#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

bash -n assets.d/docker.sh || fail "bash -n failed for assets.d/docker.sh"
source assets.d/docker.sh

for check in running not_running healthy image_exists image_age volume_exists network_exists container_count registry_reachable no_privileged; do
    queue_asset_facilities | grep -q "docker:$check" || fail "facility missing: docker:$check"
    declare -F "queue_asset_check_docker_${check}" >/dev/null || fail "function missing: queue_asset_check_docker_${check}"
    queue_asset_hints | grep -q "docker:$check" || fail "hint missing: docker:$check"
done

(
    PATH=/nonexistent
    result="$(queue_asset_check_docker_running "_tok" "dummy" 2>&1 || true)"
    case "$result" in *tool_missing*) ;; *) fail "docker:running must emit tool_missing when required tool is absent" ;; esac
)

echo "[PASS] docker asset facilities, functions, hints, and tool_missing path are wired"
