#!/usr/bin/env bash
# bashqueues schema registry provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_SCHEMA_REGISTRY_FIXTURE_DIR:-}"
_live="${QUEUEBASH_SCHEMA_REGISTRY_LIVE_CHECKS:-0}"

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
  "provider_family": "schema_registry",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_SCHEMA_REGISTRY_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/schema_registry/schema_registry_provider.sh detect
  providers.d/schema_registry/schema_registry_provider.sh registry explain
  providers.d/schema_registry/schema_registry_provider.sh schema explain
  providers.d/schema_registry/schema_registry_provider.sh compatibility explain
  providers.d/schema_registry/schema_registry_provider.sh governance explain

Default mode is fixture-only via QUEUEBASH_SCHEMA_REGISTRY_FIXTURE_DIR.
This helper exposes normalized schema registry facts only. It does not make live
service calls, mutate provider state, provision services, return executable commands,
or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.schema_registry.detect.v1 detect missing_fixture_detect_json ;;
  "registry explain") _json_file registry.json || _fail_json queuebash.schema_registry.registry.v1 registry missing_fixture_registry_json ;;
  "schema explain") _json_file schema.json || _fail_json queuebash.schema_registry.schema.v1 schema missing_fixture_schema_json ;;
  "compatibility explain") _json_file compatibility.json || _fail_json queuebash.schema_registry.compatibility.v1 compatibility missing_fixture_compatibility_json ;;
  "governance explain") _json_file governance.json || _fail_json queuebash.schema_registry.governance.v1 governance missing_fixture_governance_json ;;
  *) echo "ERROR: unsupported schema registry provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
