#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/policy_engine/policy_engine_provider.sh"
[[ -x "$helper" ]]
bash -n "$helper"
for f in docs/POLICY_ENGINE_PROVIDER_CONTRACTS.md docs/POLICY_ENGINE_EXPLAINABILITY.md docs/POLICY_ENGINE_LEGAL_COMPLIANCE.md; do
  [[ -s "$f" ]] || { echo "missing doc: $f" >&2; exit 1; }
done
for f in policies.d/policy_engine/default-policy.example.json policies.d/policy_engine/governance.example.json; do
  python3 -m json.tool "$f" >/dev/null
done
python3 - <<'PYSEC'
import json, pathlib
root=pathlib.Path('.')
for path in (root/'tests/fixtures/policy_engine').glob('*.json'):
    obj=json.loads(path.read_text())
    assert obj.get('mutated') is False, path
    assert obj.get('provider_output_is_shell') is False, path
    assert obj.get('credentials_required_for_default_tests') is False, path
PYSEC
echo 'PASS policy_engine_provider_contracts_static'
