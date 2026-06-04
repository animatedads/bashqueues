#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/workflow_orchestrator'
required = {'detect.json': 'queuebash.workflow_orchestrator.detect.v1', 'workflow.json': 'queuebash.workflow_orchestrator.workflow.v1', 'schedule.json': 'queuebash.workflow_orchestrator.schedule.v1', 'dependency.json': 'queuebash.workflow_orchestrator.dependency.v1', 'governance.json': 'queuebash.workflow_orchestrator.governance.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'workflow_orchestrator', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

dependency = json.loads((fixtures / 'dependency.json').read_text(encoding='utf-8'))
assert dependency['dependency_is_advisory'] is True

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['workflow_orchestrator']
assert fam['status'] == 'fixture_first_provider_family'
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS workflow_orchestrator_provider_json_contract_static')
