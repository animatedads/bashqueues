#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/configuration_database'
required = {'detect.json': 'queuebash.configuration_database.detect.v1', 'ci.json': 'queuebash.configuration_database.ci.v1', 'relationship.json': 'queuebash.configuration_database.relationship.v1', 'change_window.json': 'queuebash.configuration_database.change_window.v1', 'policy.json': 'queuebash.configuration_database.policy.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'configuration_database', name_file
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
fam = service['families']['configuration_database']
assert fam['status'] == 'fixture_first_provider_family'
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS configuration_database_provider_json_contract_static')
