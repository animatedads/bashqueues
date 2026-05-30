#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/aws'
required = {'detect.json':'queuebash.aws.detect.v1','metadata.json':'queuebash.aws.metadata.v1','identity.json':'queuebash.aws.identity.v1','region.json':'queuebash.aws.region.v1','data_protection.json':'queuebash.aws.data_protection.v1','itar.json':'queuebash.aws.itar.v1','finops.json':'queuebash.aws.finops.v1','resource_shape.json':'queuebash.aws.resource_shape.v1'}
for name, schema in required.items():
    obj=json.loads((fixtures/name).read_text(encoding='utf-8'))
    assert obj['schema']==schema, (name, obj.get('schema'))
    assert obj['provider']=='aws'
    assert obj['decision'] in ('allow','deny')
    assert obj.get('mutated', False) is False
matrix=json.loads((root/'policies.d/cloud-resource/platform-parity.json').read_text(encoding='utf-8'))
aws=matrix['platforms']['aws']
for key in ['first_class','governance','gdpr_data_protection','itar_export_control','finops_cost','provider_json_contract','asset_checks','fixtures','static_smoke_json_tests']:
    assert aws.get(key) is True, key
assert matrix['verdict']=='not_equal_yet'
assert matrix['platforms']['azure']['first_class'] is False
assert matrix['platforms']['gcp']['first_class'] is False
print('PASS aws_provider_json_contract_static')
