#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
res = json.loads((root / 'examples/cloud-resource/oci-vm-gdpr.example.json').read_text())
assert res['schema'] == 'queuebash.cloud_resource.v1'
assert res['provider'] == 'oci'
assert res['resource_type'] == 'vm'
assert 'gdpr' in res['compliance']
assert 'capacity' in res and res['capacity']['cpu'] >= 1
assert 'provenance' in res
parity = json.loads((root / 'policies.d/cloud-resource/platform-parity.json').read_text())
assert parity['schema'] == 'queuebash.cloud_platform_parity.v1'
assert parity['verdict'] == 'not_equal_yet'
for platform in ('oci', 'ibm', 'azure', 'gcp', 'aws'):
    assert platform in parity['platforms']
    for key in ('first_class', 'governance', 'gdpr_data_protection', 'itar_export_control', 'finops_cost'):
        assert key in parity['platforms'][platform]
assert parity['platforms']['aws']['first_class'] is True
assert parity['platforms']['gcp']['provider_json_contract'] is True
assert parity['platforms']['oci']['governance'] is True
assert parity['platforms']['ibm']['finops_cost'] is True
print('PASS cloud_resource_json_contract_static')
