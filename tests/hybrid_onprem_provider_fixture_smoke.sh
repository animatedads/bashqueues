#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/hybrid_onprem/hybrid_onprem_provider.sh"
fixture="tests/fixtures/hybrid_onprem"
tmpdir="${TMPDIR:-/tmp}/hybrid-onprem-provider-smoke.$$"
mkdir -p "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT
run_json(){ QUEUEBASH_HYBRID_ONPREM_FIXTURE_DIR="$fixture" "$helper" "$@"; }
for p in vmware openstack openshift; do
  run_json "$p" detect > "$tmpdir/$p-detect.json"
  run_json "$p" identity explain > "$tmpdir/$p-identity.json"
  run_json "$p" region explain > "$tmpdir/$p-region.json"
  run_json "$p" virtualization explain > "$tmpdir/$p-virtualization.json"
  run_json "$p" storage explain > "$tmpdir/$p-storage.json"
  run_json "$p" network explain > "$tmpdir/$p-network.json"
  run_json "$p" finops explain > "$tmpdir/$p-finops.json"
  run_json "$p" legal explain > "$tmpdir/$p-legal.json"
done
/usr/bin/python3 - "$tmpdir" <<'PY'
import json, sys
from pathlib import Path
base=Path(sys.argv[1])
providers=['vmware','openstack','openshift']
checks=['detect','identity','region','virtualization','storage','network','finops','legal']
for p in providers:
  for c in checks:
    data=json.loads((base/f'{p}-{c}.json').read_text())
    assert data['provider_family']=='hybrid_onprem'
    assert data['provider']==p
    assert data['schema']==f'queuebash.hybrid_onprem.{p}.{c}.v1'
    if 'decision' in data:
      assert data['decision'] in ('allow','available','deny','unknown')
    text=json.dumps(data)
    forbidden=['PRIVATE KEY','kubeconfig_value','OS_PASSWORD','vcenter_password','tls_private_key']
    assert not any(x in text for x in forbidden), (p,c)
  assert json.loads((base/f'{p}-storage.json').read_text())['signed_url_redacted'] is True
  assert json.loads((base/f'{p}-identity.json').read_text())['api_token_stored'] is False
  assert json.loads((base/f'{p}-legal.json').read_text())['status']=='mapped_pending_validation'
print('PASS hybrid/on-prem fixture json')
PY
echo 'PASS hybrid_onprem_provider_fixture_smoke'
