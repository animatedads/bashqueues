#!/usr/bin/env bash
# bashqueues license manager provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_LICENSE_MANAGER_FIXTURE_DIR:-}"
_live="${QUEUEBASH_LICENSE_MANAGER_LIVE_CHECKS:-0}"

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
  "provider_family": "license_manager",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_LICENSE_MANAGER_FIXTURE_DIR fixtures for contract tests. Live license manager reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/license_manager/license_manager_provider.sh detect
  providers.d/license_manager/license_manager_provider.sh entitlement explain
  providers.d/license_manager/license_manager_provider.sh pool explain
  providers.d/license_manager/license_manager_provider.sh usage explain
  providers.d/license_manager/license_manager_provider.sh policy explain

Default mode is fixture-only via QUEUEBASH_LICENSE_MANAGER_FIXTURE_DIR.
This helper exposes normalized license manager facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.license_manager.detect.v1 detect missing_fixture_detect_json ;;
  "entitlement explain") _json_file entitlement.json || _fail_json queuebash.license_manager.entitlement.v1 entitlement missing_fixture_entitlement_json ;;
  "pool explain") _json_file pool.json || _fail_json queuebash.license_manager.pool.v1 pool missing_fixture_pool_json ;;
  "usage explain") _json_file usage.json || _fail_json queuebash.license_manager.usage.v1 usage missing_fixture_usage_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.license_manager.policy.v1 policy missing_fixture_policy_json ;;
  *) echo "ERROR: unsupported license manager provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
