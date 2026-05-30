#!/usr/bin/env bash
set -euo pipefail

_fixture_dir="${QUEUEBASH_AZURE_FIXTURE_DIR:-}"

_json_file() {
  local name="$1"
  if [[ -n "$_fixture_dir" && -f "$_fixture_dir/$name" ]]; then
    cat "$_fixture_dir/$name"
    return 0
  fi
  return 1
}

_fail_json() {
  local schema="$1" check="$2" reason="$3"
  /usr/bin/python3 - "$schema" "$check" "$reason" <<'PY'
import json, sys
schema, check, reason = sys.argv[1:4]
print(json.dumps({
  "schema": schema,
  "provider": "azure",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "remediation_hint": "Provide QUEUEBASH_AZURE_FIXTURE_DIR fixtures for default tests. Live Azure checks are intentionally out of scope for this contract package."
}, sort_keys=True))
PY
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/azure/azure_provider.sh detect
  providers.d/azure/azure_provider.sh identity explain
  providers.d/azure/azure_provider.sh region explain
  providers.d/azure/azure_provider.sh compute explain
  providers.d/azure/azure_provider.sh storage explain
  providers.d/azure/azure_provider.sh network explain
  providers.d/azure/azure_provider.sh finops explain
  providers.d/azure/azure_provider.sh legal explain

Default mode is fixture-only via QUEUEBASH_AZURE_FIXTURE_DIR.
Live Azure checks are intentionally not implemented in this contract package.
USAGE
    ;;
  "detect ")
    _json_file detect.json || _fail_json queuebash.azure.detect.v1 detect missing_fixture_detect_json
    ;;
  "identity explain")
    _json_file identity.json || _fail_json queuebash.azure.identity.v1 identity missing_fixture_identity_json
    ;;
  "region explain")
    _json_file region.json || _fail_json queuebash.azure.region.v1 region missing_fixture_region_json
    ;;
  "compute explain")
    _json_file compute.json || _fail_json queuebash.azure.compute.v1 compute missing_fixture_compute_json
    ;;
  "storage explain")
    _json_file storage.json || _fail_json queuebash.azure.storage.v1 storage missing_fixture_storage_json
    ;;
  "network explain")
    _json_file network.json || _fail_json queuebash.azure.network.v1 network missing_fixture_network_json
    ;;
  "finops explain")
    _json_file finops.json || _fail_json queuebash.azure.finops.v1 finops missing_fixture_finops_json
    ;;
  "legal explain")
    _json_file legal.json || _fail_json queuebash.azure.legal.v1 legal missing_fixture_legal_json
    ;;
  *)
    echo "ERROR: unsupported Azure provider command: $*" >&2
    exit 2
    ;;
esac
