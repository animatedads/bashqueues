#!/usr/bin/env python3
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
providers=['cloudflare','fastly','flyio']
checks=['detect','identity','region','edge_runtime','storage','network','finops','legal']
for p in providers:
    for c in checks:
        data=json.loads((root/'tests'/'fixtures'/'edge_cloud'/p/(c+'.json')).read_text())
        assert data['schema']==f'queuebash.edge_cloud.{p}.{c}.v1'
        assert data['provider_family']=='edge_cloud'
        assert data['provider']==p
        assert 'reason' in data
        if 'decision' in data:
            assert data['decision'] in {'allow','available','deny','unknown'}
    assert json.loads((root/'tests/fixtures/edge_cloud'/p/'identity.json').read_text())['api_token_stored'] is False
    assert json.loads((root/'tests/fixtures/edge_cloud'/p/'storage.json').read_text())['signed_url_redacted'] is True
    assert json.loads((root/'tests/fixtures/edge_cloud'/p/'legal.json').read_text())['status']=='mapped_pending_validation'
print('PASS edge_cloud_provider_json_contract_static')
