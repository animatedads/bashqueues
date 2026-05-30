#!/usr/bin/env bash
# Deterministic fixture provider for queue ask provider contract tests.
set -euo pipefail
request=""; output=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --request-json) request="${2:-}"; shift 2 ;;
    --output-json) output="${2:-}"; shift 2 ;;
    --describe)
      echo '{"schema":"queuebash.ask_provider.contract.v1","provider":"fixture","live_supported":false,"fixture_supported":true,"advisory_only":true}'
      exit 0 ;;
    *) shift ;;
  esac
done
# Deliberately static and local: no Python, no network, no credentials, no subprocess-heavy context walk.
json='{"schema":"queuebash.ask_provider.response.v1","provider":"fixture","status":"ok","answer_markdown":"Fixture ask provider response. No live provider call was performed.","live_call_performed":false,"advisory_only":true,"usage":{"input_tokens":0,"output_tokens":0}}'
if [[ -n "$output" ]]; then
  printf '%s\n' "$json" > "$output"
else
  printf '%s\n' "$json"
fi
