#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/metadata_catalog/metadata_catalog_provider.sh"
[[ -x "$helper" ]]
[[ -f "docs/METADATA_CATALOG_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/METADATA_CATALOG_EXPLAINABILITY.md" ]]
[[ -f "docs/METADATA_CATALOG_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/metadata_catalog/default-policy.example.json" ]]
# The helper must remain fact-only and must not advertise mutating operations.
if grep -E "(upload|download|delete|grant|apply|provision|submit|exec|shell)" "$helper" >/dev/null; then
  echo "unexpected mutating/shell wording in $helper" >&2
  exit 1
fi
printf 'PASS metadata_catalog_provider_contracts_static
'
