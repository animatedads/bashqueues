#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper="providers.d/apac_china/apac_china_provider.sh"
fixture="tests/fixtures/apac_china"
tmpdir="${TMPDIR:-/tmp}/apac-china-provider-smoke.$$"
mkdir -p "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT
run_json(){ QUEUEBASH_APAC_CHINA_FIXTURE_DIR="$fixture" "$helper" "$@"; }
for p in alibaba tencent huawei; do
  run_json "$p" detect > "$tmpdir/$p-detect.json"
  run_json "$p" identity explain > "$tmpdir/$p-identity.json"
  run_json "$p" region explain > "$tmpdir/$p-region.json"
  run_json "$p" compute explain > "$tmpdir/$p-compute.json"
  run_json "$p" storage explain > "$tmpdir/$p-storage.json"
  run_json "$p" network explain > "$tmpdir/$p-network.json"
  run_json "$p" finops explain > "$tmpdir/$p-finops.json"
  run_json "$p" legal explain > "$tmpdir/$p-legal.json"
done
/usr/bin/python3 - "$tmpdir" <<'PY'
import json, sys
from pathlib import Path
base=Path(sys.argv[1])
providers=['alibaba','tencent','huawei']
checks=['detect','identity','region','compute','storage','network','finops','legal']
for p in providers:
  for c in checks:
    data=json.loads((base/f'{p}-{c}.json').read_text())
    assert data['provider_family']=='apac_china'
    assert data['provider']==p
    assert data['schema']==f'queuebash.apac_china.{p}.{c}.v1'
    if 'decision' in data:
      assert data['decision'] in ('allow','available','deny','unknown')
    text=json.dumps(data)
    forbidden=['access_key_secret','secret_key_value','PRIVATE KEY','signedUrl','signed_url_value','token_value','console_session']
    assert not any(x in text for x in forbidden), (p,c)
  assert json.loads((base/f'{p}-storage.json').read_text())['signed_url_redacted'] is True
  assert json.loads((base/f'{p}-identity.json').read_text())['access_key_stored'] is False
  assert json.loads((base/f'{p}-legal.json').read_text())['status']=='mapped_pending_validation'
print('PASS apac china fixture json')
PY
echo 'PASS apac_china_provider_fixture_smoke'
