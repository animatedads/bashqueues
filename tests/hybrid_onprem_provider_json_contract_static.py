#!/usr/bin/env python3
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
providers=['vmware','openstack','openshift']
checks=['detect','identity','region','virtualization','storage','network','finops','legal']
for p in providers:
  for c in checks:
    data=json.loads((root/'tests'/'fixtures'/'hybrid_onprem'/p/f'{c}.json').read_text())
    assert data['schema']==f'queuebash.hybrid_onprem.{p}.{c}.v1', (p,c)
    assert data['provider_family']=='hybrid_onprem'
    assert data['provider']==p
    assert data['source']=='fixture'
    if 'decision' in data:
      assert data['decision'] in {'allow','available','deny','unknown'}
    if c=='legal':
      assert data['status']=='mapped_pending_validation'
    if c=='storage':
      assert data['signed_url_redacted'] is True
    if c=='identity':
      assert data['api_token_stored'] is False
print('PASS hybrid_onprem_provider_json_contract_static')
