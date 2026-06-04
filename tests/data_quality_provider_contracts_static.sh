#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/data_quality/data_quality_provider.sh"
[[ -x "$helper" ]]
[[ -f "docs/DATA_QUALITY_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/DATA_QUALITY_EXPLAINABILITY.md" ]]
[[ -f "docs/DATA_QUALITY_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/data_quality/default-policy.example.json" ]]
# The helper may document non-goals in prose, but supported case labels must remain read-only.
case_labels="$(grep -E '^  "[^"]+"\)' "$helper" || true)"
if printf '%s
' "$case_labels" | grep -E "\b(register|delete|grant|apply|provision|submit|exec|upload|download|sample-read|data-scan|mutate)\b" >/dev/null; then
  echo "unexpected mutating/execution command case in $helper" >&2
  exit 1
fi
printf 'PASS data_quality_provider_contracts_static
'
