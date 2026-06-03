#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/data_lake'
required = {
    'detect.json': 'queuebash.data_lake.detect.v1',
    'catalog.json': 'queuebash.data_lake.catalog.v1',
    'dataset.json': 'queuebash.data_lake.dataset.v1',
    'governance.json': 'queuebash.data_lake.governance.v1',
    'retention.json': 'queuebash.data_lake.retention.v1',
}
for name, schema in required.items():
    obj = json.loads((fixtures / name).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name, obj.get('schema'))
    assert obj['provider_family'] == 'data_lake', name
    assert obj['provider'] == 'fixture', name
    assert obj['decision'] in ('allow', 'deny'), name
    assert obj.get('fail_closed') is True, name
    assert obj.get('mutated') is False, name
    forbidden = {'token','api_key','secret','password','credential','access_key'}
    assert not (forbidden & {k.lower() for k in obj}), name
catalog = json.loads((fixtures / 'catalog.json').read_text(encoding='utf-8'))
assert catalog['classification'] == 'synthetic_or_public'
dataset = json.loads((fixtures / 'dataset.json').read_text(encoding='utf-8'))
assert dataset['sample_access_permitted'] is False
assert dataset['contains_live_customer_data'] is False
governance = json.loads((fixtures / 'governance.json').read_text(encoding='utf-8'))
assert governance['export_control_review_required'] is True
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['data_lake']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] == 4
assert service['default_safety_contract']['provider_output_is_shell'] is False
print('PASS data_lake_provider_json_contract_static')
