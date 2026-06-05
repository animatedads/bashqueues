#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/certificate_authority'
required = {'detect.json': 'queuebash.certificate_authority.detect.v1', 'issuer.json': 'queuebash.certificate_authority.issuer.v1', 'certificate.json': 'queuebash.certificate_authority.certificate.v1', 'policy.json': 'queuebash.certificate_authority.policy.v1', 'revocation.json': 'queuebash.certificate_authority.revocation.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'certificate_authority', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    assert obj.get('live_api_used') is False, name_file
    assert obj.get('credentials_required') is False, name_file
    forbidden = {'token','api_key','password','private_key','client_secret','access_key','secret_value'}
    assert not (forbidden & {k.lower() for k in obj}), name_file

cert = json.loads((fixtures / 'certificate.json').read_text(encoding='utf-8'))
assert cert['certificate_bytes_returned'] is False
assert cert['private_key_returned'] is False
issuer = json.loads((fixtures / 'issuer.json').read_text(encoding='utf-8'))
assert issuer['key_material_returned'] is False
rev = json.loads((fixtures / 'revocation.json').read_text(encoding='utf-8'))
assert rev['revocation_mutated'] is False

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['certificate_authority']
assert fam['status'] == 'fixture_first_provider_family'
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS certificate_authority_provider_json_contract_static')
