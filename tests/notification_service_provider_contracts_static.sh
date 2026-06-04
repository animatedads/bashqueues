#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/notification_service/notification_service_provider.sh"
[[ -x "$helper" ]]
bash -n "$helper"
for f in docs/NOTIFICATION_SERVICE_PROVIDER_CONTRACTS.md docs/NOTIFICATION_SERVICE_EXPLAINABILITY.md docs/NOTIFICATION_SERVICE_LEGAL_COMPLIANCE.md; do
  [[ -s "$f" ]]
done
[[ -s policies.d/notification_service/default-policy.example.json ]]
[[ -d tests/fixtures/notification_service ]]
if grep -R -E '(^|[^a-z])(curl|wget|ssh|scp|sudo|kubectl|terraform|pulumi|ansible|eval|source )[[:space:]]' providers.d/notification_service docs/NOTIFICATION_SERVICE_*.md policies.d/notification_service tests/fixtures/notification_service >/tmp/notification_service_forbidden.txt 2>/dev/null; then
  cat /tmp/notification_service_forbidden.txt >&2
  exit 1
fi
printf 'PASS notification_service_provider_contracts_static
'
