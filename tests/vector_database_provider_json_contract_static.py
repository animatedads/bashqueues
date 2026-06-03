#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/vector_database'
required = {
    'detect.json': 'queuebash.vector_database.detect.v1',
    'collection.json': 'queuebash.vector_database.collection.v1',
    'index.json': 'queuebash.vector_database.index.v1',
    'embedding-policy.json': 'queuebash.vector_database.embedding_policy.v1',
    'retention.json': 'queuebash.vector_database.retention.v1',
}
for name, schema in required.items():
    obj = json.loads((fixtures / name).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name, obj.get('schema'))
    assert obj['provider_family'] == 'vector_database', name
    assert obj['provider'] == 'fixture', name
    assert obj['decision'] in ('allow', 'deny'), name
    assert obj.get('fail_closed') is True, name
    assert obj.get('mutated') is False, name
    forbidden = {'token','api_key','secret','password','credential','access_key'}
    assert not (forbidden & {k.lower() for k in obj}), name
collection = json.loads((fixtures / 'collection.json').read_text(encoding='utf-8'))
assert collection['query_runtime_permitted'] is False
index = json.loads((fixtures / 'index.json').read_text(encoding='utf-8'))
assert index['dimensions'] > 0 and index['metric'] in {'cosine','dot','euclidean'}
policy = json.loads((fixtures / 'embedding-policy.json').read_text(encoding='utf-8'))
assert policy['live_embedding_permitted'] is False
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['vector_database']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] == 3
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS vector_database_provider_json_contract_static')
