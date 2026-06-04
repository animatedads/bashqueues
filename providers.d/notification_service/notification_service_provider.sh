#!/usr/bin/env bash
# bashqueues notification service provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_NOTIFICATION_SERVICE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_NOTIFICATION_SERVICE_LIVE_CHECKS:-0}"

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
  "provider_family": "notification_service",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_NOTIFICATION_SERVICE_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/notification_service/notification_service_provider.sh detect
  providers.d/notification_service/notification_service_provider.sh channel explain
  providers.d/notification_service/notification_service_provider.sh route explain
  providers.d/notification_service/notification_service_provider.sh template explain
  providers.d/notification_service/notification_service_provider.sh delivery explain

Default mode is fixture-only via QUEUEBASH_NOTIFICATION_SERVICE_FIXTURE_DIR.
This helper exposes normalized notification service facts only. It does not make live
service calls, mutate provider state, provision services, return executable commands,
or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.notification_service.detect.v1 detect missing_fixture_detect_json ;;
  "channel explain") _json_file channel.json || _fail_json queuebash.notification_service.channel.v1 channel missing_fixture_channel_json ;;
  "route explain") _json_file route.json || _fail_json queuebash.notification_service.route.v1 route missing_fixture_route_json ;;
  "template explain") _json_file template.json || _fail_json queuebash.notification_service.template.v1 template missing_fixture_template_json ;;
  "delivery explain") _json_file delivery.json || _fail_json queuebash.notification_service.delivery.v1 delivery missing_fixture_delivery_json ;;
  *) echo "ERROR: unsupported notification service provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
