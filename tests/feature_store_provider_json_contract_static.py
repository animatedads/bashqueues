#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/feature_store'
required = {'detect.json': 'queuebash.feature_store.detect.v1', 'entity.json': 'queuebash.feature_store.entity.v1', 'feature-view.json': 'queuebash.feature_store.feature_view.v1', 'training-set.json': 'queuebash.feature_store.training_set.v1', 'lineage.json': 'queuebash.feature_store.lineage.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'feature_store', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    forbidden = {'token','api_key','secret','password','credential','access_key'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

entity = json.loads((fixtures / 'entity.json').read_text(encoding='utf-8'))
assert entity['value_returned'] is False
training = json.loads((fixtures / 'training-set.json').read_text(encoding='utf-8'))
assert training['training_set_export_permitted'] is False

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['feature_store']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] == 8
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS feature_store_provider_json_contract_static')
