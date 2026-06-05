#!/usr/bin/env bash
# bashqueues configuration database provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_CONFIGURATION_DATABASE_FIXTURE_DIR:-}"
_live="${QUEUEBASH_CONFIGURATION_DATABASE_LIVE_CHECKS:-0}"

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
  "provider_family": "configuration_database",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_CONFIGURATION_DATABASE_FIXTURE_DIR fixtures for contract tests. Live configuration database reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/configuration_database/configuration_database_provider.sh detect
  providers.d/configuration_database/configuration_database_provider.sh ci explain
  providers.d/configuration_database/configuration_database_provider.sh relationship explain
  providers.d/configuration_database/configuration_database_provider.sh change_window explain
  providers.d/configuration_database/configuration_database_provider.sh policy explain

Default mode is fixture-only via QUEUEBASH_CONFIGURATION_DATABASE_FIXTURE_DIR.
This helper exposes normalized configuration database facts only. It does not
make live service calls, mutate provider state, provision services, return
commands for execution, or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.configuration_database.detect.v1 detect missing_fixture_detect_json ;;
  "ci explain") _json_file ci.json || _fail_json queuebash.configuration_database.ci.v1 ci missing_fixture_ci_json ;;
  "relationship explain") _json_file relationship.json || _fail_json queuebash.configuration_database.relationship.v1 relationship missing_fixture_relationship_json ;;
  "change_window explain") _json_file change_window.json || _fail_json queuebash.configuration_database.change_window.v1 change_window missing_fixture_change_window_json ;;
  "policy explain") _json_file policy.json || _fail_json queuebash.configuration_database.policy.v1 policy missing_fixture_policy_json ;;
  *) echo "ERROR: unsupported configuration database provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
