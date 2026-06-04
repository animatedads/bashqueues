#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/access_review'
required = {'detect.json': 'queuebash.access_review.detect.v1', 'scope.json': 'queuebash.access_review.scope.v1', 'entitlement.json': 'queuebash.access_review.entitlement.v1', 'reviewer.json': 'queuebash.access_review.reviewer.v1', 'exception.json': 'queuebash.access_review.exception.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'access_review', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    evidence = obj.get('evidence', {})
    assert evidence.get('live_api_used') is False, name_file
    assert evidence.get('credentials_used') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value','credential_value','raw_evidence','raw_subject'}
    assert not (forbidden & {k.lower() for k in obj}), name_file
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['access_review']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] == 18
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS access_review_provider_json_contract_static')
