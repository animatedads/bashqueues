#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/observability_backend'
required = dict([('detect.json', 'queuebash.observability_backend.detect.v1'), ('signal.json', 'queuebash.observability_backend.signal.v1'), ('metric.json', 'queuebash.observability_backend.metric.v1'), ('trace.json', 'queuebash.observability_backend.trace.v1'), ('alert.json', 'queuebash.observability_backend.alert.v1')])
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'observability_backend', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

metric = json.loads((fixtures / 'metric.json').read_text(encoding='utf-8'))
assert metric['sample_values_returned'] is False
assert metric['telemetry_write_permitted'] is False

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['observability_backend']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] == 10
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS observability_backend_provider_json_contract_static')
