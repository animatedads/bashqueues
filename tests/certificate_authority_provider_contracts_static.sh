#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/certificate_authority/certificate_authority_provider.sh"
[[ -x "$helper" ]]
[[ -f "docs/CERTIFICATE_AUTHORITY_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/CERTIFICATE_AUTHORITY_EXPLAINABILITY.md" ]]
[[ -f "docs/CERTIFICATE_AUTHORITY_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/certificate_authority/default-policy.example.json" ]]
# The helper must remain fact-only and must not expose executable operation case labels.
if grep -E '^  "(start|stop|create|delete|grant|revoke|issue|renew|restore|backup|submit|exec)($| )' "$helper" >/dev/null; then
  echo "unexpected executable operation case label in $helper" >&2
  exit 1
fi
printf 'PASS certificate_authority_provider_contracts_static
'
