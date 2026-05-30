#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/gcp/gcp_provider.sh"
fixture="tests/fixtures/gcp"

tmpdir="${TMPDIR:-/tmp}/gcp-provider-smoke.$$"
mkdir -p "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT

run_json(){ QUEUEBASH_GCP_FIXTURE_DIR="$fixture" "$helper" "$@"; }

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
    'detect.json': 'queuebash.gcp.detect.v1',
    'identity.json': 'queuebash.gcp.identity.v1',
    'region.json': 'queuebash.gcp.region.v1',
    'compute.json': 'queuebash.gcp.compute.v1',
    'storage.json': 'queuebash.gcp.storage.v1',
    'network.json': 'queuebash.gcp.network.v1',
    'finops.json': 'queuebash.gcp.finops.v1',
    'legal.json': 'queuebash.gcp.legal.v1',
}
for name, schema in expected.items():
    data = json.loads((base / name).read_text(encoding='utf-8'))
    assert data.get('schema') == schema, (name, data.get('schema'), schema)
    assert data.get('provider') == 'gcp', name
    if 'decision' in data:
        assert data['decision'] in ('allow', 'available', 'deny', 'unknown'), name
    text = json.dumps(data)
    forbidden = ['PRIVATE KEY', 'refresh_token', 'signedUrl', 'signed_url_value']
    assert not any(token in text for token in forbidden), name
assert json.loads((base / 'storage.json').read_text())['signed_url_redacted'] is True
assert json.loads((base / 'identity.json').read_text())['key_file_stored'] is False
print('PASS gcp fixture json')
PY

echo 'PASS gcp_provider_fixture_smoke'
