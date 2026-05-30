#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests' / 'fixtures' / 'oci'
expected = {
    'detect.json': 'queuebash.oci.detect.v1',
    'metadata.json': 'queuebash.oci.metadata.v1',
    'identity_instance_principal.json': 'queuebash.oci.identity.v1',
    'region.json': 'queuebash.oci.region.v1',
    'object_storage.json': 'queuebash.oci.object_storage.v1',
    'network.json': 'queuebash.oci.network.v1',
    'resource_shape.json': 'queuebash.oci.resource_shape.v1',
}
for name, schema in expected.items():
    path = fixtures / name
    assert path.exists(), f'missing fixture {name}'
    data = json.loads(path.read_text(encoding='utf-8'))
    assert data['schema'] == schema
    assert data['provider'] == 'oci'
    assert 'reason' in data

identity = json.loads((fixtures / 'identity_instance_principal.json').read_text())
assert identity['auth_mode'] == 'instance_principal'
assert identity['oci_cli_auth'] == 'instance_principal'
assert identity['fail_closed'] is False

metadata = json.loads((fixtures / 'metadata.json').read_text())
assert metadata['auth_header_required'] is True
assert metadata['imds_version'] == 'v2'

region = json.loads((fixtures / 'region.json').read_text())
assert 'legal_frameworks' in region
assert region['data_residency_decision'] in ('allow', 'deny', 'review', 'unknown')

obj = json.loads((fixtures / 'object_storage.json').read_text())
assert obj['par_expiry_required'] is True
assert obj['par_url_redacted'] is True
assert 'retention_days' in obj

network = json.loads((fixtures / 'network.json').read_text())
assert network['nsg_ids']
assert network['security_lists']

print('PASS oci_provider_json_contract_static')
