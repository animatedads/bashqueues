#!/usr/bin/env bash
# bashqueues secrets scanner provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR:-}"
_live="${QUEUEBASH_SECRETS_SCANNER_LIVE_CHECKS:-0}"

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
  "provider_family": "secrets_scanner",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR fixtures for contract tests. Live secrets scanner reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/secrets_scanner/secrets_scanner_provider.sh detect
  providers.d/secrets_scanner/secrets_scanner_provider.sh rule explain
  providers.d/secrets_scanner/secrets_scanner_provider.sh finding explain
  providers.d/secrets_scanner/secrets_scanner_provider.sh scope explain
  providers.d/secrets_scanner/secrets_scanner_provider.sh policy explain

Default mode is fixture-only via QUEUEBASH_SECRETS_SCANNER_FIXTURE_DIR.
This helper exposes normalized secrets scanner facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.secrets_scanner.detect.v1 detect missing_fixture_detect_json ;;
  "rule explain") _json_file rule.json || _fail_json queuebash.secrets_scanner.rule.v1 rule missing_fixture_rule_json ;;
  "finding explain") _json_file finding.json || _fail_json queuebash.secrets_scanner.finding.v1 finding missing_fixture_finding_json ;;
  "scope explain") _json_file scope.json || _fail_json queuebash.secrets_scanner.scope.v1 scope missing_fixture_scope_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.secrets_scanner.policy.v1 policy missing_fixture_policy_json ;;
  *) echo "ERROR: unsupported secrets scanner provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
