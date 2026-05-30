#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/azure/azure_provider.sh"
fixture="tests/fixtures/azure"

tmpdir="${TMPDIR:-/tmp}/azure-provider-smoke.$$"
mkdir -p "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT

run_json(){ QUEUEBASH_AZURE_FIXTURE_DIR="$fixture" "$helper" "$@"; }

run_json detect > "$tmpdir/detect.json"
run_json identity explain > "$tmpdir/identity.json"
run_json region explain > "$tmpdir/region.json"
run_json compute explain > "$tmpdir/compute.json"
run_json storage explain > "$tmpdir/storage.json"
run_json network explain > "$tmpdir/network.json"
run_json finops explain > "$tmpdir/finops.json"
run_json legal explain > "$tmpdir/legal.json"

/usr/bin/python3 - "$tmpdir" <<'PY'
import json, sys
from pathlib import Path
base = Path(sys.argv[1])
expected = {
    'detect.json': 'queuebash.azure.detect.v1',
    'identity.json': 'queuebash.azure.identity.v1',
    'region.json': 'queuebash.azure.region.v1',
    'compute.json': 'queuebash.azure.compute.v1',
    'storage.json': 'queuebash.azure.storage.v1',
    'network.json': 'queuebash.azure.network.v1',
    'finops.json': 'queuebash.azure.finops.v1',
    'legal.json': 'queuebash.azure.legal.v1',
}
for name, schema in expected.items():
    data = json.loads((base / name).read_text(encoding='utf-8'))
    assert data.get('schema') == schema, (name, data.get('schema'), schema)
    assert data.get('provider') == 'azure', name
    if 'decision' in data:
        assert data['decision'] in ('allow', 'available', 'deny', 'unknown'), name
    text = json.dumps(data)
    forbidden = ['access_token_value', 'refresh_token_value', 'client_secret_value', 'SharedAccessSignature=', 'sig=']
    assert not any(token in text for token in forbidden), name
assert json.loads((base / 'storage.json').read_text())['sas_redacted'] is True
assert json.loads((base / 'identity.json').read_text())['client_secret_stored'] is False
print('PASS azure fixture json')
PY

echo 'PASS azure_provider_fixture_smoke'
