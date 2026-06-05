#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/secrets_scanner/secrets_scanner_provider.sh"
[[ -f "$helper" ]]
bash -n "$helper"
[[ -f "docs/SECRETS_SCANNER_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/SECRETS_SCANNER_EXPLAINABILITY.md" ]]
[[ -f "docs/SECRETS_SCANNER_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/secrets_scanner/default-policy.example.json" ]]
# The helper must remain fact-only and must not expose executable operation case labels.
if grep -E '^  "(scan|exfiltrate|reveal|redact|rotate|revoke|mutate|provision|start|stop|submit|exec|create|delete|upload|download|deploy|promote|issue|invalidate|register|deregister|flush|failover|scale-up|scale-down)($| )' "$helper" >/dev/null; then
  echo "unexpected executable operation case label in $helper" >&2
  exit 1
fi
printf 'PASS secrets_scanner_provider_contracts_static
'
