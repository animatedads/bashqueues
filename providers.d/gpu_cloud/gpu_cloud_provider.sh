#!/usr/bin/env bash
set -euo pipefail
_fixture_dir="${QUEUEBASH_GPU_CLOUD_FIXTURE_DIR:-}"
_norm_provider(){
  case "${1:-}" in
    coreweave|cw) printf 'coreweave' ;;
    lambda|lambda-cloud|lambdalabs|lambda-labs) printf 'lambda' ;;
    dgx|nvidia-dgx|nvidia-dgx-cloud|dgx-cloud) printf 'dgx' ;;
    *) printf '%s' "${1:-}" ;;
  esac
}
_json_file() {
  local provider="$1" name="$2"
  if [[ -n "$_fixture_dir" && -f "$_fixture_dir/$provider/$name" ]]; then
    cat "$_fixture_dir/$provider/$name"
    return 0
  fi
  return 1
}
_fail_json() {
  local provider="$1" schema="$2" check="$3" reason="$4"
  /usr/bin/python3 - "$provider" "$schema" "$check" "$reason" <<'PY'
import json, sys
provider, schema, check, reason = sys.argv[1:5]
print(json.dumps({
  "schema": schema,
  "provider_family": "gpu_cloud",
  "provider": provider,
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "remediation_hint": "Provide QUEUEBASH_GPU_CLOUD_FIXTURE_DIR fixtures for default tests. Live GPU cloud checks are intentionally out of scope for this contract package."
}, sort_keys=True))
PY
}
usage(){
  cat <<'USAGE'
Usage:
  providers.d/gpu_cloud/gpu_cloud_provider.sh PROVIDER detect
  providers.d/gpu_cloud/gpu_cloud_provider.sh PROVIDER identity explain
  providers.d/gpu_cloud/gpu_cloud_provider.sh PROVIDER region explain
  providers.d/gpu_cloud/gpu_cloud_provider.sh PROVIDER accelerator explain
  providers.d/gpu_cloud/gpu_cloud_provider.sh PROVIDER storage explain
  providers.d/gpu_cloud/gpu_cloud_provider.sh PROVIDER network explain
  providers.d/gpu_cloud/gpu_cloud_provider.sh PROVIDER finops explain
  providers.d/gpu_cloud/gpu_cloud_provider.sh PROVIDER legal explain

PROVIDER: coreweave | lambda | dgx
Default mode is fixture-only via QUEUEBASH_GPU_CLOUD_FIXTURE_DIR.
Live provider checks are intentionally not implemented in this contract package.
USAGE
}
if [[ "${1:-help}" == "help" || $# -lt 2 ]]; then usage; exit 0; fi
provider="$(_norm_provider "$1")"; shift
case "$provider" in coreweave|lambda|dgx) ;; *) echo "ERROR: unsupported GPU cloud provider: $provider" >&2; exit 2;; esac
case "${1:-} ${2:-}" in
  "detect ") _json_file "$provider" detect.json || _fail_json "$provider" "queuebash.gpu_cloud.$provider.detect.v1" detect missing_fixture_detect_json ;;
  "identity explain") _json_file "$provider" identity.json || _fail_json "$provider" "queuebash.gpu_cloud.$provider.identity.v1" identity missing_fixture_identity_json ;;
  "region explain") _json_file "$provider" region.json || _fail_json "$provider" "queuebash.gpu_cloud.$provider.region.v1" region missing_fixture_region_json ;;
  "accelerator explain") _json_file "$provider" accelerator.json || _fail_json "$provider" "queuebash.gpu_cloud.$provider.accelerator.v1" accelerator missing_fixture_accelerator_json ;;
  "storage explain") _json_file "$provider" storage.json || _fail_json "$provider" "queuebash.gpu_cloud.$provider.storage.v1" storage missing_fixture_storage_json ;;
  "network explain") _json_file "$provider" network.json || _fail_json "$provider" "queuebash.gpu_cloud.$provider.network.v1" network missing_fixture_network_json ;;
  "finops explain") _json_file "$provider" finops.json || _fail_json "$provider" "queuebash.gpu_cloud.$provider.finops.v1" finops missing_fixture_finops_json ;;
  "legal explain") _json_file "$provider" legal.json || _fail_json "$provider" "queuebash.gpu_cloud.$provider.legal.v1" legal missing_fixture_legal_json ;;
  *) echo "ERROR: unsupported GPU cloud provider command: $provider $*" >&2; exit 2 ;;
esac
