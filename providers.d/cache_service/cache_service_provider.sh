#!/usr/bin/env bash
# bashqueues cache service provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_CACHE_SERVICE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_CACHE_SERVICE_LIVE_CHECKS:-0}"

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
  "provider_family": "cache_service",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_CACHE_SERVICE_FIXTURE_DIR fixtures for contract tests. Live cache service reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/cache_service/cache_service_provider.sh detect
  providers.d/cache_service/cache_service_provider.sh cluster explain
  providers.d/cache_service/cache_service_provider.sh endpoint explain
  providers.d/cache_service/cache_service_provider.sh policy explain
  providers.d/cache_service/cache_service_provider.sh metrics explain

Default mode is fixture-only via QUEUEBASH_CACHE_SERVICE_FIXTURE_DIR.
This helper exposes normalized cache service facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.cache_service.detect.v1 detect missing_fixture_detect_json ;;
  "cluster explain") _json_file cluster.json || _fail_json queuebash.cache_service.cluster.v1 cluster missing_fixture_cluster_json ;;
  "endpoint explain") _json_file endpoint.json || _fail_json queuebash.cache_service.endpoint.v1 endpoint missing_fixture_endpoint_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.cache_service.policy.v1 policy missing_fixture_policy_json ;;
  "metrics explain") _json_file metrics.json || _fail_json queuebash.cache_service.metrics.v1 metrics missing_fixture_metrics_json ;;
  *) echo "ERROR: unsupported cache service provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
