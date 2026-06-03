#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/secret_manager'
required = {'detect.json': 'queuebash.secret_manager.detect.v1', 'secret.json': 'queuebash.secret_manager.secret.v1', 'rotation.json': 'queuebash.secret_manager.rotation.v1', 'access-policy.json': 'queuebash.secret_manager.access_policy.v1', 'audit.json': 'queuebash.secret_manager.audit.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'secret_manager', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    forbidden = {'token','api_key','secret','password','credential','access_key'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

secret = json.loads((fixtures / 'secret.json').read_text(encoding='utf-8'))
assert secret['value_returned'] is False
access = json.loads((fixtures / 'access-policy.json').read_text(encoding='utf-8'))
assert access['read_allowed'] is False and access['metadata_read_allowed'] is True

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['secret_manager']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] == 7
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS secret_manager_provider_json_contract_static')
