#!/usr/bin/env bash
set -euo pipefail

_fixture_dir="${QUEUEBASH_GCP_FIXTURE_DIR:-}"
_live="${QUEUEBASH_GCP_LIVE_CHECKS:-0}"

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
  "provider": "gcp",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "remediation_hint": "Provide QUEUEBASH_GCP_FIXTURE_DIR fixtures for default tests. Live GCP checks are intentionally out of scope for this contract package."
}, sort_keys=True))
PY
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/gcp/gcp_provider.sh detect
  providers.d/gcp/gcp_provider.sh identity explain
  providers.d/gcp/gcp_provider.sh region explain
  providers.d/gcp/gcp_provider.sh compute explain
  providers.d/gcp/gcp_provider.sh storage explain
  providers.d/gcp/gcp_provider.sh network explain
  providers.d/gcp/gcp_provider.sh finops explain
  providers.d/gcp/gcp_provider.sh legal explain

Default mode is fixture-only via QUEUEBASH_GCP_FIXTURE_DIR.
Live GCP checks are intentionally not implemented in this contract package.
USAGE
    ;;
  "detect ")
    _json_file detect.json || _fail_json queuebash.gcp.detect.v1 detect missing_fixture_detect_json
    ;;
  "identity explain")
    _json_file identity.json || _fail_json queuebash.gcp.identity.v1 identity missing_fixture_identity_json
    ;;
  "region explain")
    _json_file region.json || _fail_json queuebash.gcp.region.v1 region missing_fixture_region_json
    ;;
  "compute explain")
    _json_file compute.json || _fail_json queuebash.gcp.compute.v1 compute missing_fixture_compute_json
    ;;
  "storage explain")
    _json_file storage.json || _fail_json queuebash.gcp.storage.v1 storage missing_fixture_storage_json
    ;;
  "network explain")
    _json_file network.json || _fail_json queuebash.gcp.network.v1 network missing_fixture_network_json
    ;;
  "finops explain")
    _json_file finops.json || _fail_json queuebash.gcp.finops.v1 finops missing_fixture_finops_json
    ;;
  "legal explain")
    _json_file legal.json || _fail_json queuebash.gcp.legal.v1 legal missing_fixture_legal_json
    ;;
  *)
    echo "ERROR: unsupported GCP provider command: $*" >&2
    exit 2
    ;;
esac

if [[ "$_live" == "1" ]]; then
  echo "ERROR: live GCP checks are out of scope for this contract package" >&2
  exit 3
fi
