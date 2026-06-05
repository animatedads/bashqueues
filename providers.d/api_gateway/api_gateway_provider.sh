#!/usr/bin/env bash
# bashqueues api gateway provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_API_GATEWAY_FIXTURE_DIR:-}"
_live="${QUEUEBASH_API_GATEWAY_LIVE_CHECKS:-0}"

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
  "provider_family": "api_gateway",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_API_GATEWAY_FIXTURE_DIR fixtures for contract tests. Live API gateway reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/api_gateway/api_gateway_provider.sh detect
  providers.d/api_gateway/api_gateway_provider.sh gateway explain
  providers.d/api_gateway/api_gateway_provider.sh route explain
  providers.d/api_gateway/api_gateway_provider.sh auth explain
  providers.d/api_gateway/api_gateway_provider.sh policy explain

Default mode is fixture-only via QUEUEBASH_API_GATEWAY_FIXTURE_DIR.
This helper exposes normalized api gateway facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.api_gateway.detect.v1 detect missing_fixture_detect_json ;;
  "gateway explain") _json_file gateway.json || _fail_json queuebash.api_gateway.gateway.v1 gateway missing_fixture_gateway_json ;;
  "route explain") _json_file route.json || _fail_json queuebash.api_gateway.route.v1 route missing_fixture_route_json ;;
  "auth explain") _json_file auth.json || _fail_json queuebash.api_gateway.auth.v1 auth missing_fixture_auth_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.api_gateway.policy.v1 policy missing_fixture_policy_json ;;
  *) echo "ERROR: unsupported api gateway provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
