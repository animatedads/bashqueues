#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/license_manager/license_manager_provider.sh"
[[ -x "$helper" ]]
[[ -f "docs/LICENSE_MANAGER_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/LICENSE_MANAGER_EXPLAINABILITY.md" ]]
[[ -f "docs/LICENSE_MANAGER_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/license_manager/default-policy.example.json" ]]
# The helper must remain fact-only and must not expose executable operation case labels.
if grep -E '^  "(assign|revoke|purchase|billing|mutate|provision|start|stop|submit|exec)($| )' "$helper" >/dev/null; then
  echo "unexpected executable operation case label in $helper" >&2
  exit 1
fi
printf 'PASS license_manager_provider_contracts_static
'
