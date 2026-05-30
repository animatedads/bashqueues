#!/usr/bin/env bash
set -euo pipefail

_fixture_dir="${QUEUEBASH_IBM_FIXTURE_DIR:-}"

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
  "provider": "ibm",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "remediation_hint": "Provide QUEUEBASH_IBM_FIXTURE_DIR fixtures for default tests. Live IBM Cloud checks are intentionally out of scope for this contract package."
}, sort_keys=True))
PY
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/ibm/ibm_provider.sh detect
  providers.d/ibm/ibm_provider.sh identity explain
  providers.d/ibm/ibm_provider.sh region explain
  providers.d/ibm/ibm_provider.sh resource explain
  providers.d/ibm/ibm_provider.sh network explain
  providers.d/ibm/ibm_provider.sh finops explain
  providers.d/ibm/ibm_provider.sh legal explain

Default mode is fixture-only via QUEUEBASH_IBM_FIXTURE_DIR.
Live IBM Cloud checks are intentionally not implemented in this contract package.
USAGE
    ;;
  "detect ")
    _json_file detect.json || _fail_json queuebash.ibm.detect.v1 detect missing_fixture_detect_json
    ;;
  "identity explain")
    _json_file identity.json || _fail_json queuebash.ibm.identity.v1 identity missing_fixture_identity_json
    ;;
  "region explain")
    _json_file region.json || _fail_json queuebash.ibm.region.v1 region missing_fixture_region_json
    ;;
  "resource explain")
    _json_file resource.json || _fail_json queuebash.ibm.resource.v1 resource missing_fixture_resource_json
    ;;
  "network explain")
    _json_file network.json || _fail_json queuebash.ibm.network.v1 network missing_fixture_network_json
    ;;
  "finops explain")
    _json_file finops.json || _fail_json queuebash.ibm.finops.v1 finops missing_fixture_finops_json
    ;;
  "legal explain")
    _json_file legal.json || _fail_json queuebash.ibm.legal.v1 legal missing_fixture_legal_json
    ;;
  *)
    echo "ERROR: unsupported IBM provider command: $*" >&2
    exit 2
    ;;
esac
