#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/package_registry/package_registry_provider.sh"
[[ -f "$helper" ]]
bash -n "$helper"
[[ -f "docs/PACKAGE_REGISTRY_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/PACKAGE_REGISTRY_EXPLAINABILITY.md" ]]
[[ -f "docs/PACKAGE_REGISTRY_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/package_registry/default-policy.example.json" ]]
# The helper must remain fact-only and must not expose executable operation case labels.
if grep -E '^  "(assign|revoke|purchase|billing|mutate|provision|start|stop|submit|exec|create|delete|upload|download|deploy|promote|route-create|route-delete|issue)($| )' "$helper" >/dev/null; then
  echo "unexpected executable operation case label in $helper" >&2
  exit 1
fi
printf 'PASS package_registry_provider_contracts_static
'
