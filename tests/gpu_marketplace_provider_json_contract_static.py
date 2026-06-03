#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/gpu_marketplace'
required = {'detect.json': 'queuebash.gpu_marketplace.detect.v1', 'offer.json': 'queuebash.gpu_marketplace.offer.v1', 'capability.json': 'queuebash.gpu_marketplace.capability.v1', 'quota.json': 'queuebash.gpu_marketplace.quota.v1', 'compliance.json': 'queuebash.gpu_marketplace.compliance.v1'}
for name, schema in required.items():
    obj = json.loads((fixtures / name).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name, obj.get('schema'))
    assert obj['provider_family'] == 'gpu_marketplace', name
    assert obj['provider'] == 'fixture', name
    assert obj['decision'] in ('allow', 'deny'), name
    assert obj.get('fail_closed') is True, name
    assert obj.get('mutated') is False, name
    forbidden = {'token','api_key','secret','password','credential','access_key'}
    assert not (forbidden & {k.lower() for k in obj}), name
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['gpu_marketplace']
assert fam['status'] == 'fixture_first_provider_family'
assert service['default_safety_contract']['normalized_json_only'] is True
assert service['default_safety_contract']['provider_output_is_shell'] is False
print('PASS gpu_marketplace_provider_json_contract_static')
