#!/usr/bin/env bash
set -euo pipefail
_fixture_dir="${QUEUEBASH_APAC_CHINA_FIXTURE_DIR:-}"
_norm_provider(){
  case "${1:-}" in
    alibaba|aliyun|alibaba-cloud|alibabacloud) printf 'alibaba' ;;
    tencent|tencent-cloud|qcloud) printf 'tencent' ;;
    huawei|huawei-cloud|huaweicloud) printf 'huawei' ;;
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
  "provider_family": "apac_china",
  "provider": provider,
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "remediation_hint": "Provide QUEUEBASH_APAC_CHINA_FIXTURE_DIR fixtures for default tests. Live APAC/China provider checks are intentionally out of scope for this contract package."
}, sort_keys=True))
PY
}
usage(){
  cat <<'USAGE'
Usage:
  providers.d/apac_china/apac_china_provider.sh PROVIDER detect
  providers.d/apac_china/apac_china_provider.sh PROVIDER identity explain
  providers.d/apac_china/apac_china_provider.sh PROVIDER region explain
  providers.d/apac_china/apac_china_provider.sh PROVIDER compute explain
  providers.d/apac_china/apac_china_provider.sh PROVIDER storage explain
  providers.d/apac_china/apac_china_provider.sh PROVIDER network explain
  providers.d/apac_china/apac_china_provider.sh PROVIDER finops explain
  providers.d/apac_china/apac_china_provider.sh PROVIDER legal explain

PROVIDER: alibaba | tencent | huawei
Default mode is fixture-only via QUEUEBASH_APAC_CHINA_FIXTURE_DIR.
Live provider checks are intentionally not implemented in this contract package.
USAGE
}
if [[ "${1:-help}" == "help" || $# -lt 2 ]]; then usage; exit 0; fi
provider="$(_norm_provider "$1")"; shift
case "$provider" in alibaba|tencent|huawei) ;; *) echo "ERROR: unsupported APAC/China provider: $provider" >&2; exit 2;; esac
case "${1:-} ${2:-}" in
  "detect ") _json_file "$provider" detect.json || _fail_json "$provider" "queuebash.apac_china.$provider.detect.v1" detect missing_fixture_detect_json ;;
  "identity explain") _json_file "$provider" identity.json || _fail_json "$provider" "queuebash.apac_china.$provider.identity.v1" identity missing_fixture_identity_json ;;
  "region explain") _json_file "$provider" region.json || _fail_json "$provider" "queuebash.apac_china.$provider.region.v1" region missing_fixture_region_json ;;
  "compute explain") _json_file "$provider" compute.json || _fail_json "$provider" "queuebash.apac_china.$provider.compute.v1" compute missing_fixture_compute_json ;;
  "storage explain") _json_file "$provider" storage.json || _fail_json "$provider" "queuebash.apac_china.$provider.storage.v1" storage missing_fixture_storage_json ;;
  "network explain") _json_file "$provider" network.json || _fail_json "$provider" "queuebash.apac_china.$provider.network.v1" network missing_fixture_network_json ;;
  "finops explain") _json_file "$provider" finops.json || _fail_json "$provider" "queuebash.apac_china.$provider.finops.v1" finops missing_fixture_finops_json ;;
  "legal explain") _json_file "$provider" legal.json || _fail_json "$provider" "queuebash.apac_china.$provider.legal.v1" legal missing_fixture_legal_json ;;
  *) echo "ERROR: unsupported APAC/China provider command: $provider $*" >&2; exit 2 ;;
esac
