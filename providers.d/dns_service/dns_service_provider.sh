#!/usr/bin/env bash
# bashqueues dns service provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_DNS_SERVICE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_DNS_SERVICE_LIVE_CHECKS:-0}"

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
  "provider_family": "dns_service",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_DNS_SERVICE_FIXTURE_DIR fixtures for contract tests. Live dns service reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/dns_service/dns_service_provider.sh detect
  providers.d/dns_service/dns_service_provider.sh zone explain
  providers.d/dns_service/dns_service_provider.sh record explain
  providers.d/dns_service/dns_service_provider.sh resolver explain
  providers.d/dns_service/dns_service_provider.sh policy explain

Default mode is fixture-only via QUEUEBASH_DNS_SERVICE_FIXTURE_DIR.
This helper exposes normalized dns service facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.dns_service.detect.v1 detect missing_fixture_detect_json ;;
  "zone explain") _json_file zone.json || _fail_json queuebash.dns_service.zone.v1 zone missing_fixture_zone_json ;;
  "record explain") _json_file record.json || _fail_json queuebash.dns_service.record.v1 record missing_fixture_record_json ;;
  "resolver explain") _json_file resolver.json || _fail_json queuebash.dns_service.resolver.v1 resolver missing_fixture_resolver_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.dns_service.policy.v1 policy missing_fixture_policy_json ;;
  *) echo "ERROR: unsupported dns service provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
