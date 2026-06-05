#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/dns_service/dns_service_provider.sh"
[[ -f "$helper" ]]
bash -n "$helper"
[[ -f "docs/DNS_SERVICE_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/DNS_SERVICE_EXPLAINABILITY.md" ]]
[[ -f "docs/DNS_SERVICE_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/dns_service/default-policy.example.json" ]]
# The helper must remain fact-only and must not expose executable operation case labels.
if grep -E '^  "(assign|revoke|purchase|billing|mutate|provision|start|stop|submit|exec|create|delete|upload|download|deploy|promote|route-create|route-delete|issue|invalidate|register|deregister|traffic-shift|flush|failover|scale-up|scale-down)($| )' "$helper" >/dev/null; then
  echo "unexpected executable operation case label in $helper" >&2
  exit 1
fi
printf 'PASS dns_service_provider_contracts_static
'
