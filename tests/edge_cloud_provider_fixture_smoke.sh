#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/edge_cloud/edge_cloud_provider.sh"
fixture="tests/fixtures/edge_cloud"
tmpdir="${TMPDIR:-/tmp}/edge-cloud-provider-smoke.$$"
mkdir -p "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT
run_json(){ QUEUEBASH_EDGE_CLOUD_FIXTURE_DIR="$fixture" "$helper" "$@"; }
for p in cloudflare fastly flyio; do
  run_json "$p" detect > "$tmpdir/$p-detect.json"
  run_json "$p" identity explain > "$tmpdir/$p-identity.json"
  run_json "$p" region explain > "$tmpdir/$p-region.json"
  run_json "$p" edge-runtime explain > "$tmpdir/$p-edge_runtime.json"
  run_json "$p" storage explain > "$tmpdir/$p-storage.json"
  run_json "$p" network explain > "$tmpdir/$p-network.json"
  run_json "$p" finops explain > "$tmpdir/$p-finops.json"
  run_json "$p" legal explain > "$tmpdir/$p-legal.json"
done
/usr/bin/python3 - "$tmpdir" <<'PY'
import json, sys
from pathlib import Path
base=Path(sys.argv[1])
providers=['cloudflare','fastly','flyio']
checks=['detect','identity','region','edge_runtime','storage','network','finops','legal']
for p in providers:
  for c in checks:
    data=json.loads((base/f'{p}-{c}.json').read_text())
    assert data['provider_family']=='edge_cloud'
    assert data['provider']==p
    assert data['schema']==f'queuebash.edge_cloud.{p}.{c}.v1'
    if 'decision' in data:
      assert data['decision'] in ('allow','available','deny','unknown')
    text=json.dumps(data)
    forbidden=['api_token_value','PRIVATE KEY','signedUrl','signed_url_value','secret_env_value','tls_private_key']
    assert not any(x in text for x in forbidden), (p,c)
  assert json.loads((base/f'{p}-storage.json').read_text())['signed_url_redacted'] is True
  assert json.loads((base/f'{p}-identity.json').read_text())['api_token_stored'] is False
  assert json.loads((base/f'{p}-legal.json').read_text())['status']=='mapped_pending_validation'
print('PASS edge cloud fixture json')
PY
echo 'PASS edge_cloud_provider_fixture_smoke'
