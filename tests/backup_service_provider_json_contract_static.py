#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/backup_service'
required = {'detect.json': 'queuebash.backup_service.detect.v1', 'policy.json': 'queuebash.backup_service.policy.v1', 'repository.json': 'queuebash.backup_service.repository.v1', 'schedule.json': 'queuebash.backup_service.schedule.v1', 'recovery_point.json': 'queuebash.backup_service.recovery_point.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'backup_service', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    assert obj.get('live_api_used') is False, name_file
    assert obj.get('credentials_required') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

recovery = json.loads((fixtures / 'recovery_point.json').read_text(encoding='utf-8'))
assert recovery['restore_started'] is False
assert recovery['backup_bytes_returned'] is False
repo = json.loads((fixtures / 'repository.json').read_text(encoding='utf-8'))
assert repo['repository_bytes_returned'] is False
assert repo['repository_mutated'] is False

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['backup_service']
assert fam['status'] == 'fixture_first_provider_family'
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS backup_service_provider_json_contract_static')
