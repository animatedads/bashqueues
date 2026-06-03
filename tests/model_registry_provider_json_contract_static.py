#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/model_registry'
required = {
    'detect.json': 'queuebash.model_registry.detect.v1',
    'catalog.json': 'queuebash.model_registry.catalog.v1',
    'model.json': 'queuebash.model_registry.model.v1',
    'governance.json': 'queuebash.model_registry.governance.v1',
}
for name, schema in required.items():
    obj = json.loads((fixtures / name).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name, obj.get('schema'))
    assert obj['provider_family'] == 'model_registry', name
    assert obj['provider'] == 'fixture', name
    assert obj['decision'] in ('allow', 'deny'), name
    assert obj.get('fail_closed') is True, name
    assert obj.get('mutated') is False, name
    forbidden = {'token','api_key','secret','password','credential','access_key'}
    assert not (forbidden & {k.lower() for k in obj}), name
catalog = json.loads((fixtures / 'catalog.json').read_text(encoding='utf-8'))
assert isinstance(catalog['models'], list) and catalog['models'], 'catalog models'
for model in catalog['models']:
    for field in ['model_id','capabilities','endpoint_class','data_residency','cost_tier','validation_status']:
        assert field in model, field
governance = json.loads((fixtures / 'governance.json').read_text(encoding='utf-8'))
assert governance['live_inference_permitted'] is False
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['model_registry']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] == 1
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS model_registry_provider_json_contract_static')
