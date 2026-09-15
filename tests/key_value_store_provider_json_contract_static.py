#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/key_value_store'
required = {'detect.json': 'queuebash.key_value_store.detect.v1', 'table.json': 'queuebash.key_value_store.table.v1', 'capacity.json': 'queuebash.key_value_store.capacity.v1', 'policy.json': 'queuebash.key_value_store.policy.v1', 'backup.json': 'queuebash.key_value_store.backup.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'key_value_store', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    assert obj.get('live_api_used') is False, name_file
    assert obj.get('credentials_required') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value','license_key','credential','object_body','package_payload','signing_key','certificate_private_key','tls_private_key','session_cookie','query_text','document_body'}
    assert not (forbidden & {k.lower() for k in obj}), name_file
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['key_value_store']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['provider_dir'] == 'key_value_store'
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS key_value_store_provider_json_contract_static')
