#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
for f in providers.d/feature_store/feature_store_provider.sh docs/FEATURE_STORE_PROVIDER_CONTRACTS.md docs/FEATURE_STORE_EXPLAINABILITY.md docs/FEATURE_STORE_LEGAL_COMPLIANCE.md policies.d/feature_store/default-policy.example.json policies.d/feature_store/governance.example.json tests/fixtures/feature_store/detect.json tests/fixtures/feature_store/entity.json tests/fixtures/feature_store/feature-view.json tests/fixtures/feature_store/training-set.json tests/fixtures/feature_store/lineage.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done
bash -n providers.d/feature_store/feature_store_provider.sh
python3 - <<'PYSECRETS'
import json
from pathlib import Path
root = Path('.')
for path in list((root/'tests/fixtures/feature_store').glob('*.json')) + list((root/'policies.d/feature_store').glob('*.json')):
    obj = json.loads(path.read_text(encoding='utf-8'))
    for key, value in obj.items():
        low = key.lower()
        if low in {'value', 'token', 'api_key', 'password', 'private_key', 'client_secret', 'access_key'}:
            raise SystemExit(f'forbidden value-bearing key in {path}: {key}')
        if isinstance(value, str) and any(marker in value.lower() for marker in ['-----begin private key-----', 'sk-', 'ghp_', 'xoxb-']):
            raise SystemExit(f'forbidden secret-looking value in {path}: {key}')
PYSECRETS
grep -q 'does not materialize online or offline feature values' docs/FEATURE_STORE_PROVIDER_CONTRACTS.md
grep -q 'must never return shell commands' docs/FEATURE_STORE_EXPLAINABILITY.md
grep -q 'Fixture-first feature store coverage is not live legal approval' docs/FEATURE_STORE_LEGAL_COMPLIANCE.md
echo 'PASS feature_store_provider_contracts_static'
