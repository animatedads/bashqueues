#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/gpu_cloud/gpu_cloud_provider.sh"
fixture="tests/fixtures/gpu_cloud"
tmpdir="${TMPDIR:-/tmp}/gpu-cloud-provider-smoke.$$"
mkdir -p "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT
run_json(){ QUEUEBASH_GPU_CLOUD_FIXTURE_DIR="$fixture" "$helper" "$@"; }
for p in coreweave lambda dgx; do
  run_json "$p" detect > "$tmpdir/$p-detect.json"
  run_json "$p" identity explain > "$tmpdir/$p-identity.json"
  run_json "$p" region explain > "$tmpdir/$p-region.json"
  run_json "$p" accelerator explain > "$tmpdir/$p-accelerator.json"
  run_json "$p" storage explain > "$tmpdir/$p-storage.json"
  run_json "$p" network explain > "$tmpdir/$p-network.json"
  run_json "$p" finops explain > "$tmpdir/$p-finops.json"
  run_json "$p" legal explain > "$tmpdir/$p-legal.json"
done
/usr/bin/python3 - "$tmpdir" <<'PY'
import json, sys
from pathlib import Path
base=Path(sys.argv[1])
providers=['coreweave','lambda','dgx']
checks=['detect','identity','region','accelerator','storage','network','finops','legal']
for p in providers:
  for c in checks:
    data=json.loads((base/f'{p}-{c}.json').read_text())
    assert data['provider_family']=='gpu_cloud'
    assert data['provider']==p
    assert data['schema']==f'queuebash.gpu_cloud.{p}.{c}.v1'
    if 'decision' in data:
      assert data['decision'] in ('allow','available','deny','unknown')
    text=json.dumps(data)
    forbidden=['api_key_value','kubeconfig_value','PRIVATE KEY','signedUrl','signed_url_value','token_value','model_registry_secret_value']
    assert not any(x in text for x in forbidden), (p,c)
  assert json.loads((base/f'{p}-storage.json').read_text())['signed_url_redacted'] is True
  assert json.loads((base/f'{p}-identity.json').read_text())['api_key_stored'] is False
  assert json.loads((base/f'{p}-identity.json').read_text())['kubeconfig_stored'] is False
  assert json.loads((base/f'{p}-legal.json').read_text())['status']=='mapped_pending_validation'
print('PASS gpu cloud fixture json')
PY
echo 'PASS gpu_cloud_provider_fixture_smoke'
