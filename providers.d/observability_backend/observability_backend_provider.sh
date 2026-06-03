#!/usr/bin/env bash
# bashqueues observability backend provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_OBSERVABILITY_BACKEND_FIXTURE_DIR:-}"
_live="${QUEUEBASH_OBSERVABILITY_BACKEND_LIVE_CHECKS:-0}"

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
  "provider_family": "observability_backend",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "remediation_hint": "Provide QUEUEBASH_OBSERVABILITY_BACKEND_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/observability_backend/observability_backend_provider.sh detect
  providers.d/observability_backend/observability_backend_provider.sh signal explain
  providers.d/observability_backend/observability_backend_provider.sh metric explain
  providers.d/observability_backend/observability_backend_provider.sh trace explain
  providers.d/observability_backend/observability_backend_provider.sh alert explain

Default mode is fixture-only via QUEUEBASH_OBSERVABILITY_BACKEND_FIXTURE_DIR.
This helper exposes normalized observability backend facts only. It does not make live
service calls, create resources, mutate policy/telemetry, return shell commands, or alter
queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.observability_backend.detect.v1 detect missing_fixture_detect_json ;;
  "signal explain") _json_file signal.json || _fail_json queuebash.observability_backend.signal.v1 signal missing_fixture_signal_json ;;
  "metric explain") _json_file metric.json || _fail_json queuebash.observability_backend.metric.v1 metric missing_fixture_metric_json ;;
  "trace explain") _json_file trace.json || _fail_json queuebash.observability_backend.trace.v1 trace missing_fixture_trace_json ;;
  "alert explain") _json_file alert.json || _fail_json queuebash.observability_backend.alert.v1 alert missing_fixture_alert_json ;;
  *) echo "ERROR: unsupported observability backend provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
