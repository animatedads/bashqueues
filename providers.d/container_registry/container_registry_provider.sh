#!/usr/bin/env bash
# bashqueues container registry provider contract helper.
# Fixture/read-only facts only. No pull, push, delete, repository creation, or runtime mutation.
set -euo pipefail

_fixture_dir="${QUEUEBASH_CONTAINER_REGISTRY_FIXTURE_DIR:-}"
_live="${QUEUEBASH_CONTAINER_REGISTRY_LIVE_CHECKS:-0}"

_json_file() {
  local name="$1"
  [[ -n "$_fixture_dir" && -f "$_fixture_dir/$name" ]] && cat "$_fixture_dir/$name" && return 0
  return 1
}

_fail_json() {
  local schema="$1" check="$2" reason="$3"
  /usr/bin/python3 - "$schema" "$check" "$reason" <<'PYFAIL'
import json, sys
schema, check, reason = sys.argv[1:4]
print(json.dumps({
  "schema": schema,
  "provider_family": "container_registry",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "remediation_hint": "Provide QUEUEBASH_CONTAINER_REGISTRY_FIXTURE_DIR fixtures for contract tests. Live registry reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/container_registry/container_registry_provider.sh detect
  providers.d/container_registry/container_registry_provider.sh image explain
  providers.d/container_registry/container_registry_provider.sh provenance explain
  providers.d/container_registry/container_registry_provider.sh vulnerability explain
  providers.d/container_registry/container_registry_provider.sh retention explain

Default mode is fixture-only via QUEUEBASH_CONTAINER_REGISTRY_FIXTURE_DIR.
This helper exposes normalized container-image metadata only. It does not pull,
push, delete, create repositories, resolve credentials, or alter job execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.container_registry.detect.v1 detect missing_fixture_detect_json ;;
  "image explain") _json_file image.json || _fail_json queuebash.container_registry.image.v1 image missing_fixture_image_json ;;
  "provenance explain") _json_file provenance.json || _fail_json queuebash.container_registry.provenance.v1 provenance missing_fixture_provenance_json ;;
  "vulnerability explain") _json_file vulnerability.json || _fail_json queuebash.container_registry.vulnerability.v1 vulnerability missing_fixture_vulnerability_json ;;
  "retention explain") _json_file retention.json || _fail_json queuebash.container_registry.retention.v1 retention missing_fixture_retention_json ;;
  *) echo "ERROR: unsupported container registry provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
