#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixture = root / 'tests' / 'fixtures' / 'azure'
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
for filename, schema in expected.items():
    data = json.loads((fixture / filename).read_text(encoding='utf-8'))
    assert data['schema'] == schema, filename
    assert data['provider'] == 'azure', filename
    assert 'reason' in data, filename
    if 'decision' in data:
        assert data['decision'] in {'allow', 'available', 'deny', 'unknown'}, filename
    if filename == 'legal.json':
        assert data['status'] == 'mapped_pending_validation'
        assert data['fail_closed'] is True
    if filename == 'storage.json':
        assert data['sas_redacted'] is True
    if filename == 'identity.json':
        assert data['client_secret_stored'] is False
print('PASS azure_provider_json_contract_static')
