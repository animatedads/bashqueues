#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail() { echo "[FAIL] $*" >&2; exit 1; }

bash -n assets.d/k8s.sh || fail "bash -n failed for assets.d/k8s.sh"
source assets.d/k8s.sh

for check in reachable deployment_ready pod_running pod_not_running job_complete node_ready pvc_bound configmap_exists secret_exists namespace_exists resource_quota_ok no_crashlooping; do
    queue_asset_facilities | grep -q "k8s:$check" || fail "facility missing: k8s:$check"
    declare -F "queue_asset_check_k8s_${check}" >/dev/null || fail "function missing: queue_asset_check_k8s_${check}"
    queue_asset_hints | grep -q "k8s:$check" || fail "hint missing: k8s:$check"
done

(
    PATH=/nonexistent
    result="$(queue_asset_check_k8s_reachable "_tok" "dummy" 2>&1 || true)"
    case "$result" in *tool_missing*) ;; *) fail "k8s:reachable must emit tool_missing when required tool is absent" ;; esac
)

# k8s:secret_exists must only check object existence; it must not extract or decode secret payload values.
secret_body="$(awk '/^queue_asset_check_k8s_secret_exists\(\)/,/^queue_asset_check_k8s_namespace_exists\(\)/ {print}' assets.d/k8s.sh)"
for forbidden in ' data' content decode base64; do
    ! grep -qi "$forbidden" <<<"$secret_body" || fail "k8s:secret_exists body contains forbidden secret-read term: $forbidden"
done

echo "[PASS] k8s asset facilities, functions, hints, and tool_missing path are wired"
