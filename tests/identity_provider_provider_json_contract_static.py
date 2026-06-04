#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/identity_provider'
required = {'detect.json': 'queuebash.identity_provider.detect.v1', 'directory.json': 'queuebash.identity_provider.directory.v1', 'authentication.json': 'queuebash.identity_provider.authentication.v1', 'federation.json': 'queuebash.identity_provider.federation.v1', 'group.json': 'queuebash.identity_provider.group.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'identity_provider', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    evidence = obj.get('evidence', {})
    assert evidence.get('live_api_used') is False, name_file
    assert evidence.get('credentials_used') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value','credential_value'}
    assert not (forbidden & {k.lower() for k in obj}), name_file
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['identity_provider']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] == 16
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS identity_provider_provider_json_contract_static')
