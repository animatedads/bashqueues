#!/usr/bin/env bash
# bashqueues workflow orchestrator provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_WORKFLOW_ORCHESTRATOR_FIXTURE_DIR:-}"
_live="${QUEUEBASH_WORKFLOW_ORCHESTRATOR_LIVE_CHECKS:-0}"

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
  "provider_family": "workflow_orchestrator",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_WORKFLOW_ORCHESTRATOR_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh detect
  providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh workflow explain
  providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh schedule explain
  providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh dependency explain
  providers.d/workflow_orchestrator/workflow_orchestrator_provider.sh governance explain

Default mode is fixture-only via QUEUEBASH_WORKFLOW_ORCHESTRATOR_FIXTURE_DIR.
This helper exposes normalized workflow orchestrator facts only. It does not make live
service calls, mutate provider state, provision services, return shell commands,
or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.workflow_orchestrator.detect.v1 detect missing_fixture_detect_json ;;
  "workflow explain") _json_file workflow.json || _fail_json queuebash.workflow_orchestrator.workflow.v1 workflow missing_fixture_workflow_json ;;
  "schedule explain") _json_file schedule.json || _fail_json queuebash.workflow_orchestrator.schedule.v1 schedule missing_fixture_schedule_json ;;
  "dependency explain") _json_file dependency.json || _fail_json queuebash.workflow_orchestrator.dependency.v1 dependency missing_fixture_dependency_json ;;
  "governance explain") _json_file governance.json || _fail_json queuebash.workflow_orchestrator.governance.v1 governance missing_fixture_governance_json ;;
  *) echo "ERROR: unsupported workflow orchestrator provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
