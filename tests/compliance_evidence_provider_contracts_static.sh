#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/compliance_evidence/compliance_evidence_provider.sh"
[[ -x "$helper" ]]
bash -n "$helper"
for f in docs/COMPLIANCE_EVIDENCE_PROVIDER_CONTRACTS.md docs/COMPLIANCE_EVIDENCE_EXPLAINABILITY.md docs/COMPLIANCE_EVIDENCE_LEGAL_COMPLIANCE.md; do
  [[ -s "$f" ]]
done
[[ -s policies.d/compliance_evidence/default-policy.example.json ]]
[[ -d tests/fixtures/compliance_evidence ]]
if grep -R -E '(^|[^a-z])(curl|wget|ssh|scp|sudo|kubectl|terraform|pulumi|ansible|eval|source )[[:space:]]' providers.d/compliance_evidence docs/COMPLIANCE_EVIDENCE_*.md policies.d/compliance_evidence tests/fixtures/compliance_evidence >/tmp/compliance_evidence_forbidden.txt 2>/dev/null; then
  cat /tmp/compliance_evidence_forbidden.txt >&2
  exit 1
fi
printf 'PASS compliance_evidence_provider_contracts_static
'
