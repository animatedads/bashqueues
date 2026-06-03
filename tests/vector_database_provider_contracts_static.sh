#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
for f in   providers.d/vector_database/vector_database_provider.sh   docs/VECTOR_DATABASE_PROVIDER_CONTRACTS.md   docs/VECTOR_DATABASE_EXPLAINABILITY.md   docs/VECTOR_DATABASE_LEGAL_COMPLIANCE.md   policies.d/vector_database/default-policy.example.json   policies.d/vector_database/embedding-governance.example.json   tests/fixtures/vector_database/detect.json   tests/fixtures/vector_database/collection.json   tests/fixtures/vector_database/index.json   tests/fixtures/vector_database/embedding-policy.json   tests/fixtures/vector_database/retention.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done
bash -n providers.d/vector_database/vector_database_provider.sh
if grep -R -E 'api[_-]?key|access[_-]?key|secret[[:space:]_:-]*(=|:)|password|credential' docs/VECTOR_DATABASE_* policies.d/vector_database tests/fixtures/vector_database providers.d/vector_database 2>/dev/null >/tmp/vector_database_secret_hits.$$; then
  cat /tmp/vector_database_secret_hits.$$ >&2
  rm -f /tmp/vector_database_secret_hits.$$
  exit 1
fi
rm -f /tmp/vector_database_secret_hits.$$
grep -q 'does not run retrieval' docs/VECTOR_DATABASE_PROVIDER_CONTRACTS.md
grep -q 'must never return shell commands' docs/VECTOR_DATABASE_EXPLAINABILITY.md
grep -q 'Fixture-first vector database coverage is not live legal approval' docs/VECTOR_DATABASE_LEGAL_COMPLIANCE.md
echo 'PASS vector_database_provider_contracts_static'
