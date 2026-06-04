#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/artifact_store'
required = {'detect.json': 'queuebash.artifact_store.detect.v1', 'artifact.json': 'queuebash.artifact_store.artifact.v1', 'provenance.json': 'queuebash.artifact_store.provenance.v1', 'retention.json': 'queuebash.artifact_store.retention.v1', 'integrity.json': 'queuebash.artifact_store.integrity.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'artifact_store', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

integrity = json.loads((fixtures / 'integrity.json').read_text(encoding='utf-8'))
assert integrity['integrity_is_advisory'] is True
assert integrity['artifact_bytes_returned'] is False

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['artifact_store']
assert fam['status'] == 'fixture_first_provider_family'
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS artifact_store_provider_json_contract_static')
