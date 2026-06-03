#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/policy_engine'
required = dict([('detect.json', 'queuebash.policy_engine.detect.v1'), ('policy.json', 'queuebash.policy_engine.policy.v1'), ('decision.json', 'queuebash.policy_engine.decision.v1'), ('obligation.json', 'queuebash.policy_engine.obligation.v1'), ('audit.json', 'queuebash.policy_engine.audit.v1')])
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'policy_engine', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

policy = json.loads((fixtures / 'decision.json').read_text(encoding='utf-8'))
assert policy['decision_is_advisory'] is True
assert policy['policy_authority_granted'] is False

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['policy_engine']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] == 9
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS policy_engine_provider_json_contract_static')
