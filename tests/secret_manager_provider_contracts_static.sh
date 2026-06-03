#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
for f in providers.d/secret_manager/secret_manager_provider.sh docs/SECRET_MANAGER_PROVIDER_CONTRACTS.md docs/SECRET_MANAGER_EXPLAINABILITY.md docs/SECRET_MANAGER_LEGAL_COMPLIANCE.md policies.d/secret_manager/default-policy.example.json policies.d/secret_manager/governance.example.json tests/fixtures/secret_manager/detect.json tests/fixtures/secret_manager/secret.json tests/fixtures/secret_manager/rotation.json tests/fixtures/secret_manager/access-policy.json tests/fixtures/secret_manager/audit.json; do
  [[ -f "$f" ]] || { echo "missing $f" >&2; exit 1; }
done
bash -n providers.d/secret_manager/secret_manager_provider.sh
python3 - <<'PYSECRETS'
import json
from pathlib import Path
root = Path('.')
for path in list((root/'tests/fixtures/secret_manager').glob('*.json')) + list((root/'policies.d/secret_manager').glob('*.json')):
    obj = json.loads(path.read_text(encoding='utf-8'))
    for key, value in obj.items():
        low = key.lower()
        if low in {'value', 'token', 'api_key', 'password', 'private_key', 'client_secret', 'access_key'}:
            raise SystemExit(f'forbidden value-bearing key in {path}: {key}')
        if isinstance(value, str) and any(marker in value.lower() for marker in ['-----begin private key-----', 'sk-', 'ghp_', 'xoxb-']):
            raise SystemExit(f'forbidden secret-looking value in {path}: {key}')
PYSECRETS
grep -q 'does not read or disclose secret values' docs/SECRET_MANAGER_PROVIDER_CONTRACTS.md
grep -q 'must never return shell commands' docs/SECRET_MANAGER_EXPLAINABILITY.md
grep -q 'Fixture-first secret manager coverage is not live legal approval' docs/SECRET_MANAGER_LEGAL_COMPLIANCE.md
echo 'PASS secret_manager_provider_contracts_static'
