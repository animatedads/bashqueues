#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/object_storage/object_storage_provider.sh"
[[ -f "$helper" ]]
bash -n "$helper"
[[ -f "docs/OBJECT_STORAGE_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/OBJECT_STORAGE_EXPLAINABILITY.md" ]]
[[ -f "docs/OBJECT_STORAGE_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/object_storage/default-policy.example.json" ]]
# The helper must remain fact-only and must not expose executable operation case labels.
if grep -E '^  "(assign|revoke|purchase|billing|mutate|provision|start|stop|submit|exec|create|delete|upload|download|shift|inject|issue)($| )' "$helper" >/dev/null; then
  echo "unexpected executable operation case label in $helper" >&2
  exit 1
fi
printf 'PASS object_storage_provider_contracts_static
'
