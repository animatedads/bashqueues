#!/usr/bin/env bash
# bashqueues service mesh provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_SERVICE_MESH_FIXTURE_DIR:-}"
_live="${QUEUEBASH_SERVICE_MESH_LIVE_CHECKS:-0}"

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
  "provider_family": "service_mesh",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_SERVICE_MESH_FIXTURE_DIR fixtures for contract tests. Live service mesh reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/service_mesh/service_mesh_provider.sh detect
  providers.d/service_mesh/service_mesh_provider.sh mesh explain
  providers.d/service_mesh/service_mesh_provider.sh route explain
  providers.d/service_mesh/service_mesh_provider.sh identity explain
  providers.d/service_mesh/service_mesh_provider.sh policy explain

Default mode is fixture-only via QUEUEBASH_SERVICE_MESH_FIXTURE_DIR.
This helper exposes normalized service mesh facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.service_mesh.detect.v1 detect missing_fixture_detect_json ;;
  "mesh explain") _json_file mesh.json || _fail_json queuebash.service_mesh.mesh.v1 mesh missing_fixture_mesh_json ;;
  "route explain") _json_file route.json || _fail_json queuebash.service_mesh.route.v1 route missing_fixture_route_json ;;
  "identity explain") _json_file identity.json || _fail_json queuebash.service_mesh.identity.v1 identity missing_fixture_identity_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.service_mesh.policy.v1 policy missing_fixture_policy_json ;;
  *) echo "ERROR: unsupported service mesh provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
