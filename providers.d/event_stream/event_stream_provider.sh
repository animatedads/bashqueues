#!/usr/bin/env bash
# bashqueues event stream provider contract helper.
# Fixture/read-only facts only. No live calls, mutation, provisioning, or queue dispatch changes.
set -euo pipefail

_fixture_dir="${QUEUEBASH_EVENT_STREAM_FIXTURE_DIR:-}"
_live="${QUEUEBASH_EVENT_STREAM_LIVE_CHECKS:-0}"

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
  "provider_family": "event_stream",
  "provider": "fixture",
  "check": check,
  "decision": "deny",
  "reason": reason,
  "source": "fixture" if reason.startswith("missing_fixture") else "config",
  "fail_closed": True,
  "mutated": False,
  "provider_output_is_shell": False,
  "remediation_hint": "Provide QUEUEBASH_EVENT_STREAM_FIXTURE_DIR fixtures for contract tests. Live reads are deferred and must be explicitly gated."
}, sort_keys=True))
PYFAIL
}

case "${1:-help} ${2:-}" in
  "help ")
    cat <<'USAGE'
Usage:
  providers.d/event_stream/event_stream_provider.sh detect
  providers.d/event_stream/event_stream_provider.sh topic explain
  providers.d/event_stream/event_stream_provider.sh consumer explain
  providers.d/event_stream/event_stream_provider.sh retention explain
  providers.d/event_stream/event_stream_provider.sh governance explain

Default mode is fixture-only via QUEUEBASH_EVENT_STREAM_FIXTURE_DIR.
This helper exposes normalized event stream facts only. It does not make live
service calls, mutate provider state, provision services, return shell commands,
or alter queue scheduling/execution.
USAGE
    ;;
  "detect ") _json_file detect.json || _fail_json queuebash.event_stream.detect.v1 detect missing_fixture_detect_json ;;
  "topic explain") _json_file topic.json || _fail_json queuebash.event_stream.topic.v1 topic missing_fixture_topic_json ;;
  "consumer explain") _json_file consumer.json || _fail_json queuebash.event_stream.consumer.v1 consumer missing_fixture_consumer_json ;;
  "retention explain") _json_file retention.json || _fail_json queuebash.event_stream.retention.v1 retention missing_fixture_retention_json ;;
  "governance explain") _json_file governance.json || _fail_json queuebash.event_stream.governance.v1 governance missing_fixture_governance_json ;;
  *) echo "ERROR: unsupported event stream provider command: $*" >&2; exit 2 ;;
esac

if [[ "$_live" == "1" ]]; then
  : # Reserved for a later explicitly gated live-read package. Do not add mutation here.
fi
