#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/license_manager'
required = {'detect.json': 'queuebash.license_manager.detect.v1', 'entitlement.json': 'queuebash.license_manager.entitlement.v1', 'pool.json': 'queuebash.license_manager.pool.v1', 'usage.json': 'queuebash.license_manager.usage.v1', 'policy.json': 'queuebash.license_manager.policy.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'license_manager', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    assert obj.get('live_api_used') is False, name_file
    assert obj.get('credentials_required') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value','license_key','credential'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['license_manager']
assert fam['status'] == 'fixture_first_provider_family'
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS license_manager_provider_json_contract_static')
