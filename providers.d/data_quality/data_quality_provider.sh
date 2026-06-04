#!/usr/bin/env bash
# bashqueues data quality provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_DATA_QUALITY_FIXTURE_DIR:-}"
_live="${QUEUEBASH_DATA_QUALITY_LIVE_CHECKS:-0}"

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
  "provider_family": "data_quality",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_DATA_QUALITY_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/data_quality/data_quality_provider.sh detect
  providers.d/data_quality/data_quality_provider.sh ruleset explain
  providers.d/data_quality/data_quality_provider.sh expectation explain
  providers.d/data_quality/data_quality_provider.sh profile explain
  providers.d/data_quality/data_quality_provider.sh result explain

Default mode is fixture-only via QUEUEBASH_DATA_QUALITY_FIXTURE_DIR.
This helper exposes normalized data quality facts only. It does not make live
service calls, mutate provider state, provision services, return executable commands,
or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.data_quality.detect.v1 detect missing_fixture_detect_json ;;
  "ruleset explain") _json_file ruleset.json || _fail_json queuebash.data_quality.ruleset.v1 ruleset missing_fixture_ruleset_json ;;
  "expectation explain") _json_file expectation.json || _fail_json queuebash.data_quality.expectation.v1 expectation missing_fixture_expectation_json ;;
  "profile explain") _json_file profile.json || _fail_json queuebash.data_quality.profile.v1 profile missing_fixture_profile_json ;;
  "result explain") _json_file result.json || _fail_json queuebash.data_quality.result.v1 result missing_fixture_result_json ;;
  *) echo "ERROR: unsupported data quality provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
