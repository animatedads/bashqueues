#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/compliance_evidence'
required = {'detect.json': 'queuebash.compliance_evidence.detect.v1', 'control.json': 'queuebash.compliance_evidence.control.v1', 'evidence_pack.json': 'queuebash.compliance_evidence.evidence_pack.v1', 'attestation.json': 'queuebash.compliance_evidence.attestation.v1', 'retention.json': 'queuebash.compliance_evidence.retention.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'compliance_evidence', name_file
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
fam = service['families']['compliance_evidence']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] == 19
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS compliance_evidence_provider_json_contract_static')
