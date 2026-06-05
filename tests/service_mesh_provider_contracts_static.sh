#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/service_mesh/service_mesh_provider.sh"
[[ -f "$helper" ]]
bash -n "$helper"
[[ -f "docs/SERVICE_MESH_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/SERVICE_MESH_EXPLAINABILITY.md" ]]
[[ -f "docs/SERVICE_MESH_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/service_mesh/default-policy.example.json" ]]
# The helper must remain fact-only and must not expose executable operation case labels.
if grep -E '^  "(assign|revoke|purchase|billing|mutate|provision|start|stop|submit|exec|create|delete|upload|download|shift|inject|issue)($| )' "$helper" >/dev/null; then
  echo "unexpected executable operation case label in $helper" >&2
  exit 1
fi
printf 'PASS service_mesh_provider_contracts_static
'
