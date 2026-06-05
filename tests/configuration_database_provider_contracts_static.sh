#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/configuration_database/configuration_database_provider.sh"
[[ -x "$helper" ]]
[[ -f "docs/CONFIGURATION_DATABASE_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/CONFIGURATION_DATABASE_EXPLAINABILITY.md" ]]
[[ -f "docs/CONFIGURATION_DATABASE_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/configuration_database/default-policy.example.json" ]]
# The helper must remain fact-only and must not expose executable operation case labels.
if grep -E '^  "(create|update|delete|mutate|write|provision|start|stop|submit|exec)($| )' "$helper" >/dev/null; then
  echo "unexpected executable operation case label in $helper" >&2
  exit 1
fi
printf 'PASS configuration_database_provider_contracts_static
'
