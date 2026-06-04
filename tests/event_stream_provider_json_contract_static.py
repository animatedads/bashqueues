#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/event_stream'
required = {'detect.json': 'queuebash.event_stream.detect.v1', 'topic.json': 'queuebash.event_stream.topic.v1', 'consumer.json': 'queuebash.event_stream.consumer.v1', 'retention.json': 'queuebash.event_stream.retention.v1', 'governance.json': 'queuebash.event_stream.governance.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'event_stream', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

retention = json.loads((fixtures / 'retention.json').read_text(encoding='utf-8'))
assert retention['retention_is_advisory'] is True

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['event_stream']
assert fam['status'] == 'fixture_first_provider_family'
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS event_stream_provider_json_contract_static')
