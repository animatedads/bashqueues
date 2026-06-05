#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/backup_service/backup_service_provider.sh"
[[ -x "$helper" ]]
[[ -f "docs/BACKUP_SERVICE_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/BACKUP_SERVICE_EXPLAINABILITY.md" ]]
[[ -f "docs/BACKUP_SERVICE_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/backup_service/default-policy.example.json" ]]
# The helper must remain fact-only and must not expose executable operation case labels.
if grep -E '^  "(start|stop|create|delete|grant|revoke|issue|renew|restore|backup|submit|exec)($| )' "$helper" >/dev/null; then
  echo "unexpected executable operation case label in $helper" >&2
  exit 1
fi
printf 'PASS backup_service_provider_contracts_static
'
