#!/usr/bin/env bash
# bashqueues policy engine provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_POLICY_ENGINE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_POLICY_ENGINE_LIVE_CHECKS:-0}"

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
  "provider_family": "policy_engine",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "remediation_hint": "Provide QUEUEBASH_POLICY_ENGINE_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/policy_engine/policy_engine_provider.sh detect
  providers.d/policy_engine/policy_engine_provider.sh policy explain
  providers.d/policy_engine/policy_engine_provider.sh decision explain
  providers.d/policy_engine/policy_engine_provider.sh obligation explain
  providers.d/policy_engine/policy_engine_provider.sh audit explain

Default mode is fixture-only via QUEUEBASH_POLICY_ENGINE_FIXTURE_DIR.
This helper exposes normalized policy engine facts only. It does not make live
service calls, create resources, mutate policy/telemetry, return shell commands, or alter
queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.policy_engine.detect.v1 detect missing_fixture_detect_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.policy_engine.policy.v1 policy missing_fixture_policy_json ;;
  "decision explain") _json_file decision.json || _fail_json queuebash.policy_engine.decision.v1 decision missing_fixture_decision_json ;;
  "obligation explain") _json_file obligation.json || _fail_json queuebash.policy_engine.obligation.v1 obligation missing_fixture_obligation_json ;;
  "audit explain") _json_file audit.json || _fail_json queuebash.policy_engine.audit.v1 audit missing_fixture_audit_json ;;
  *) echo "ERROR: unsupported policy engine provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
