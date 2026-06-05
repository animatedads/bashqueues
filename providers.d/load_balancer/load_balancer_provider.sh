#!/usr/bin/env bash
# bashqueues load balancer provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_LOAD_BALANCER_FIXTURE_DIR:-}"
_live="${QUEUEBASH_LOAD_BALANCER_LIVE_CHECKS:-0}"

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
  "provider_family": "load_balancer",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_LOAD_BALANCER_FIXTURE_DIR fixtures for contract tests. Live load balancer reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/load_balancer/load_balancer_provider.sh detect
  providers.d/load_balancer/load_balancer_provider.sh balancer explain
  providers.d/load_balancer/load_balancer_provider.sh listener explain
  providers.d/load_balancer/load_balancer_provider.sh target explain
  providers.d/load_balancer/load_balancer_provider.sh health explain

Default mode is fixture-only via QUEUEBASH_LOAD_BALANCER_FIXTURE_DIR.
This helper exposes normalized load balancer facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.load_balancer.detect.v1 detect missing_fixture_detect_json ;;
  "balancer explain") _json_file balancer.json || _fail_json queuebash.load_balancer.balancer.v1 balancer missing_fixture_balancer_json ;;
  "listener explain") _json_file listener.json || _fail_json queuebash.load_balancer.listener.v1 listener missing_fixture_listener_json ;;
  "target explain") _json_file target.json || _fail_json queuebash.load_balancer.target.v1 target missing_fixture_target_json ;;
  "health explain") _json_file health.json || _fail_json queuebash.load_balancer.health.v1 health missing_fixture_health_json ;;
  *) echo "ERROR: unsupported load balancer provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
