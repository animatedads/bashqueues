#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/metadata_catalog'
required = {'detect.json': 'queuebash.metadata_catalog.detect.v1', 'catalog.json': 'queuebash.metadata_catalog.catalog.v1', 'asset.json': 'queuebash.metadata_catalog.asset.v1', 'lineage.json': 'queuebash.metadata_catalog.lineage.v1', 'classification.json': 'queuebash.metadata_catalog.classification.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'metadata_catalog', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

classification = json.loads((fixtures / 'classification.json').read_text(encoding='utf-8'))
assert classification['classification_is_advisory'] is True
assert classification['policy_authority_granted'] is False

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['metadata_catalog']
assert fam['status'] == 'fixture_first_provider_family'
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS metadata_catalog_provider_json_contract_static')
