#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/event_stream/event_stream_provider.sh"
[[ -x "$helper" ]]
[[ -f "docs/EVENT_STREAM_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/EVENT_STREAM_EXPLAINABILITY.md" ]]
[[ -f "docs/EVENT_STREAM_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/event_stream/default-policy.example.json" ]]
# The helper must remain fact-only and must not advertise common escape tools.
# Do not forbid the literal word "shell" because provider_output_is_shell=false is a required JSON field.
if grep -E "\b(sudo|curl|wget|ssh|scp|nc|eval)\b" "$helper" >/dev/null; then
  echo "unexpected executable/remote-tool wording in $helper" >&2
  exit 1
fi
printf 'PASS event_stream_provider_contracts_static
'
