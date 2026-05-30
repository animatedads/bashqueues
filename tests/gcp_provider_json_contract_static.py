#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixture = root / 'tests' / 'fixtures' / 'gcp'
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
for filename, schema in expected.items():
    data = json.loads((fixture / filename).read_text(encoding='utf-8'))
    assert data['schema'] == schema, filename
    assert data['provider'] == 'gcp', filename
    assert 'reason' in data, filename
    if 'decision' in data:
        assert data['decision'] in {'allow', 'available', 'deny', 'unknown'}, filename
    if filename == 'legal.json':
        assert data['status'] == 'mapped_pending_validation'
        assert data['fail_closed'] is True
    if filename == 'storage.json':
        assert data['signed_url_redacted'] is True
    if filename == 'identity.json':
        assert data['key_file_stored'] is False
print('PASS gcp_provider_json_contract_static')
