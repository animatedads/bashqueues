#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
for f in   providers.d/data_lake/data_lake_provider.sh   docs/DATA_LAKE_PROVIDER_CONTRACTS.md   docs/DATA_LAKE_EXPLAINABILITY.md   docs/DATA_LAKE_LEGAL_COMPLIANCE.md   policies.d/data_lake/default-policy.example.json   policies.d/data_lake/dataset-governance.example.json   tests/fixtures/data_lake/detect.json   tests/fixtures/data_lake/catalog.json   tests/fixtures/data_lake/dataset.json   tests/fixtures/data_lake/governance.json   tests/fixtures/data_lake/retention.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done
bash -n providers.d/data_lake/data_lake_provider.sh
if grep -R -E 'api[_-]?key|access[_-]?key|secret[[:space:]_:-]*(=|:)|password|credential' docs/DATA_LAKE_* policies.d/data_lake tests/fixtures/data_lake providers.d/data_lake 2>/dev/null >/tmp/data_lake_secret_hits.$$; then
  cat /tmp/data_lake_secret_hits.$$ >&2
  rm -f /tmp/data_lake_secret_hits.$$
  exit 1
fi
rm -f /tmp/data_lake_secret_hits.$$
grep -q 'does not query real tables' docs/DATA_LAKE_PROVIDER_CONTRACTS.md
grep -q 'must never return shell commands' docs/DATA_LAKE_EXPLAINABILITY.md
grep -q 'Fixture-first data lake coverage is not live compliance acceptance' docs/DATA_LAKE_LEGAL_COMPLIANCE.md
echo 'PASS data_lake_provider_contracts_static'
