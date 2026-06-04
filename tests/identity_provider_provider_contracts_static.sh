#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/identity_provider/identity_provider_provider.sh"
[[ -x "$helper" ]]
bash -n "$helper"
for f in docs/IDENTITY_PROVIDER_PROVIDER_CONTRACTS.md docs/IDENTITY_PROVIDER_EXPLAINABILITY.md docs/IDENTITY_PROVIDER_LEGAL_COMPLIANCE.md; do
  [[ -s "$f" ]]
done
[[ -s policies.d/identity_provider/default-policy.example.json ]]
[[ -d tests/fixtures/identity_provider ]]
if grep -R -E '(^|[^a-z])(curl|wget|ssh|scp|sudo|kubectl|terraform|pulumi|ansible|eval|source )[[:space:]]' providers.d/identity_provider docs/IDENTITY_PROVIDER_*.md policies.d/identity_provider tests/fixtures/identity_provider >/tmp/identity_provider_forbidden.txt 2>/dev/null; then
  cat /tmp/identity_provider_forbidden.txt >&2
  exit 1
fi
printf 'PASS identity_provider_provider_contracts_static
'
