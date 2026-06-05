#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/object_storage'
required = {'detect.json': 'queuebash.object_storage.detect.v1', 'bucket.json': 'queuebash.object_storage.bucket.v1', 'object.json': 'queuebash.object_storage.object.v1', 'retention.json': 'queuebash.object_storage.retention.v1', 'policy.json': 'queuebash.object_storage.policy.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'object_storage', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    assert obj.get('live_api_used') is False, name_file
    assert obj.get('credentials_required') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value','license_key','credential','object_body','certificate_private_key'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['object_storage']
assert fam['status'] == 'fixture_first_provider_family'
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS object_storage_provider_json_contract_static')
