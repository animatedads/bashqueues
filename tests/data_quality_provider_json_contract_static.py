#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/data_quality'
required = {'detect.json': 'queuebash.data_quality.detect.v1', 'ruleset.json': 'queuebash.data_quality.ruleset.v1', 'expectation.json': 'queuebash.data_quality.expectation.v1', 'profile.json': 'queuebash.data_quality.profile.v1', 'result.json': 'queuebash.data_quality.result.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'data_quality', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['data_quality']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] in (15,)
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS data_quality_provider_json_contract_static')
