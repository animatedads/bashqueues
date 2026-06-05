#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/mail_service/mail_service_provider.sh"
[[ -f "$helper" ]]
bash -n "$helper"
[[ -f "docs/MAIL_SERVICE_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/MAIL_SERVICE_EXPLAINABILITY.md" ]]
[[ -f "docs/MAIL_SERVICE_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/mail_service/default-policy.example.json" ]]
# The helper must remain fact-only and must not expose executable operation case labels.
if grep -E '^  "(send|receive|relay|mutate|provision|start|stop|submit|exec|create|delete|upload|download|deploy|promote|route-create|route-delete|issue|invalidate|register|deregister|traffic-shift|flush|failover|scale-up|scale-down)($| )' "$helper" >/dev/null; then
  echo "unexpected executable operation case label in $helper" >&2
  exit 1
fi
printf 'PASS mail_service_provider_contracts_static
'
