#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
for f in \
  providers.d/model_registry/model_registry_provider.sh \
  docs/MODEL_REGISTRY_PROVIDER_CONTRACTS.md \
  docs/MODEL_REGISTRY_EXPLAINABILITY.md \
  docs/MODEL_REGISTRY_LEGAL_COMPLIANCE.md \
  policies.d/model_registry/default-policy.example.json \
  policies.d/model_registry/data-governance.example.json \
  tests/fixtures/model_registry/detect.json \
  tests/fixtures/model_registry/catalog.json \
  tests/fixtures/model_registry/model.json \
  tests/fixtures/model_registry/governance.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done
bash -n providers.d/model_registry/model_registry_provider.sh
if grep -R -E 'api[_-]?key|access[_-]?key|secret[[:space:]_:-]*(=|:)|password|credential' docs/MODEL_REGISTRY_* policies.d/model_registry tests/fixtures/model_registry providers.d/model_registry 2>/dev/null | grep -v 'regulated-live' | grep -v 'API keys' | grep -v 'credentials_required_for_default_tests' >/tmp/model_registry_secret_hits.$$; then
  cat /tmp/model_registry_secret_hits.$$ >&2
  rm -f /tmp/model_registry_secret_hits.$$
  exit 1
fi
rm -f /tmp/model_registry_secret_hits.$$
grep -q 'does not call inference APIs' docs/MODEL_REGISTRY_PROVIDER_CONTRACTS.md
grep -q 'must never return shell commands' docs/MODEL_REGISTRY_EXPLAINABILITY.md
grep -q 'Fixture-first model registry coverage is not live legal approval' docs/MODEL_REGISTRY_LEGAL_COMPLIANCE.md
echo 'PASS model_registry_provider_contracts_static'
