#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/schema_registry'
required = {'detect.json': 'queuebash.schema_registry.detect.v1', 'registry.json': 'queuebash.schema_registry.registry.v1', 'schema.json': 'queuebash.schema_registry.schema.v1', 'compatibility.json': 'queuebash.schema_registry.compatibility.v1', 'governance.json': 'queuebash.schema_registry.governance.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'schema_registry', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['schema_registry']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] in (14,)
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS schema_registry_provider_json_contract_static')
