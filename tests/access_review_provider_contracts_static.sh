#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/access_review/access_review_provider.sh"
[[ -x "$helper" ]]
bash -n "$helper"
for f in docs/ACCESS_REVIEW_PROVIDER_CONTRACTS.md docs/ACCESS_REVIEW_EXPLAINABILITY.md docs/ACCESS_REVIEW_LEGAL_COMPLIANCE.md; do
  [[ -s "$f" ]]
done
[[ -s policies.d/access_review/default-policy.example.json ]]
[[ -d tests/fixtures/access_review ]]
if grep -R -E '(^|[^a-z])(curl|wget|ssh|scp|sudo|kubectl|terraform|pulumi|ansible|eval|source )[[:space:]]' providers.d/access_review docs/ACCESS_REVIEW_*.md policies.d/access_review tests/fixtures/access_review >/tmp/access_review_forbidden.txt 2>/dev/null; then
  cat /tmp/access_review_forbidden.txt >&2
  exit 1
fi
printf 'PASS access_review_provider_contracts_static
'
