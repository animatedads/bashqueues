#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/edge_cdn/edge_cdn_provider.sh"
[[ -f "$helper" ]]
bash -n "$helper"
[[ -f "docs/EDGE_CDN_PROVIDER_CONTRACTS.md" ]]
[[ -f "docs/EDGE_CDN_EXPLAINABILITY.md" ]]
[[ -f "docs/EDGE_CDN_LEGAL_COMPLIANCE.md" ]]
[[ -f "policies.d/edge_cdn/default-policy.example.json" ]]
# The helper must remain fact-only and must not expose executable operation case labels.
if grep -E '^  "(assign|revoke|purchase|billing|mutate|provision|start|stop|submit|exec|create|delete|upload|download|deploy|promote|route-create|route-delete|issue|invalidate|register|deregister|traffic-shift)($| )' "$helper" >/dev/null; then
  echo "unexpected executable operation case label in $helper" >&2
  exit 1
fi
printf 'PASS edge_cdn_provider_contracts_static
'
