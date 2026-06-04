#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/artifact_store/artifact_store_provider.sh"
[[ -x "$helper" ]]
[[ -f "docs/ARTIFACT_STORE_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/ARTIFACT_STORE_EXPLAINABILITY.md" ]]
[[ -f "docs/ARTIFACT_STORE_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/artifact_store/default-policy.example.json" ]]
# The helper must remain fact-only and must not advertise mutating operations.
if grep -E "(upload|download|delete|grant|apply|provision|submit|exec|shell)" "$helper" >/dev/null; then
  echo "unexpected mutating/shell wording in $helper" >&2
  exit 1
fi
printf 'PASS artifact_store_provider_contracts_static
'
