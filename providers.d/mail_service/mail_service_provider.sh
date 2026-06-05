#!/usr/bin/env bash
# bashqueues mail service provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_MAIL_SERVICE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_MAIL_SERVICE_LIVE_CHECKS:-0}"

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
  "provider_family": "mail_service",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_MAIL_SERVICE_FIXTURE_DIR fixtures for contract tests. Live mail service reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/mail_service/mail_service_provider.sh detect
  providers.d/mail_service/mail_service_provider.sh domain explain
  providers.d/mail_service/mail_service_provider.sh sender explain
  providers.d/mail_service/mail_service_provider.sh delivery explain
  providers.d/mail_service/mail_service_provider.sh policy explain

Default mode is fixture-only via QUEUEBASH_MAIL_SERVICE_FIXTURE_DIR.
This helper exposes normalized mail service facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.mail_service.detect.v1 detect missing_fixture_detect_json ;;
  "domain explain") _json_file domain.json || _fail_json queuebash.mail_service.domain.v1 domain missing_fixture_domain_json ;;
  "sender explain") _json_file sender.json || _fail_json queuebash.mail_service.sender.v1 sender missing_fixture_sender_json ;;
  "delivery explain") _json_file delivery.json || _fail_json queuebash.mail_service.delivery.v1 delivery missing_fixture_delivery_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.mail_service.policy.v1 policy missing_fixture_policy_json ;;
  *) echo "ERROR: unsupported mail service provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
