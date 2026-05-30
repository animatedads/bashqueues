#!/usr/bin/env python3
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=root/'tests'/'fixtures'/'apac_china'
providers=['alibaba','tencent','huawei']
checks=['detect','identity','region','compute','storage','network','finops','legal']
for p in providers:
    for c in checks:
        data=json.loads((base/p/f'{c}.json').read_text(encoding='utf-8'))
        assert data['schema']==f'queuebash.apac_china.{p}.{c}.v1', (p,c)
        assert data['provider_family']=='apac_china', (p,c)
        assert data['provider']==p, (p,c)
        assert 'reason' in data, (p,c)
        if 'decision' in data:
            assert data['decision'] in {'allow','available','deny','unknown'}, (p,c)
        if c=='legal':
            assert data['status']=='mapped_pending_validation', p
            assert data['fail_closed'] is True, p
        if c=='storage':
            assert data['signed_url_redacted'] is True, p
        if c=='identity':
            assert data['access_key_stored'] is False, p
print('PASS apac_china_provider_json_contract_static')
