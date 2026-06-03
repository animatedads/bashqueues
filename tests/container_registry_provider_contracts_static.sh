#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
for f in \
  providers.d/container_registry/container_registry_provider.sh \
  docs/CONTAINER_REGISTRY_PROVIDER_CONTRACTS.md \
  docs/CONTAINER_REGISTRY_EXPLAINABILITY.md \
  docs/CONTAINER_REGISTRY_LEGAL_COMPLIANCE.md \
  policies.d/container_registry/default-policy.example.json \
  policies.d/container_registry/provenance-threshold.example.json \
  tests/fixtures/container_registry/detect.json \
  tests/fixtures/container_registry/image.json \
  tests/fixtures/container_registry/provenance.json \
  tests/fixtures/container_registry/vulnerability.json \
  tests/fixtures/container_registry/retention.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done
bash -n providers.d/container_registry/container_registry_provider.sh
if grep -R -E 'api[_-]?key|secret|password|token' docs/CONTAINER_REGISTRY_* policies.d/container_registry tests/fixtures/container_registry providers.d/container_registry 2>/dev/null >/tmp/container_registry_secret_hits.$$; then
  cat /tmp/container_registry_secret_hits.$$ >&2
  rm -f /tmp/container_registry_secret_hits.$$
  exit 1
fi
rm -f /tmp/container_registry_secret_hits.$$
grep -q 'does not pull images, push images, delete tags' docs/CONTAINER_REGISTRY_PROVIDER_CONTRACTS.md
grep -q 'must never return shell commands' docs/CONTAINER_REGISTRY_EXPLAINABILITY.md
grep -q 'Fixture-first container registry coverage is not live compliance acceptance' docs/CONTAINER_REGISTRY_LEGAL_COMPLIANCE.md
echo 'PASS container_registry_provider_contracts_static'
