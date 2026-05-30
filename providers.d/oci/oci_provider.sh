#!/usr/bin/env bash
set -euo pipefail

_fixture_dir="${QUEUEBASH_OCI_FIXTURE_DIR:-}"
_live="${QUEUEBASH_OCI_LIVE_CHECKS:-0}"

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
  "provider": "oci",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "remediation_hint": "Provide QUEUEBASH_OCI_FIXTURE_DIR fixtures for default tests or explicitly enable future live OCI checks."
}, sort_keys=True))
PY
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/oci/oci_provider.sh detect
  providers.d/oci/oci_provider.sh metadata
  providers.d/oci/oci_provider.sh identity explain
  providers.d/oci/oci_provider.sh region explain
  providers.d/oci/oci_provider.sh object-storage explain
  providers.d/oci/oci_provider.sh network explain
  providers.d/oci/oci_provider.sh resource-shape explain

Default mode is fixture-only via QUEUEBASH_OCI_FIXTURE_DIR.
Live OCI checks are intentionally not implemented in this contract package.
USAGE
    ;;
  "detect ")
    _json_file detect.json || _fail_json queuebash.oci.detect.v1 detect missing_fixture_detect_json
    ;;
  "metadata ")
    _json_file metadata.json || _fail_json queuebash.oci.metadata.v1 metadata missing_fixture_metadata_json
    ;;
  "identity explain")
    _json_file identity_instance_principal.json || _fail_json queuebash.oci.identity.v1 identity missing_fixture_identity_instance_principal_json
    ;;
  "region explain")
    _json_file region.json || _fail_json queuebash.oci.region.v1 region missing_fixture_region_json
    ;;
  "object-storage explain")
    _json_file object_storage.json || _fail_json queuebash.oci.object_storage.v1 object-storage missing_fixture_object_storage_json
    ;;
  "network explain")
    _json_file network.json || _fail_json queuebash.oci.network.v1 network missing_fixture_network_json
    ;;
  "resource-shape explain")
    _json_file resource_shape.json || _fail_json queuebash.oci.resource_shape.v1 resource-shape missing_fixture_resource_shape_json
    ;;
  *)
    echo "ERROR: unsupported OCI provider command: $*" >&2
    exit 2
    ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later live-gated package. Do not add live calls here.
fi
