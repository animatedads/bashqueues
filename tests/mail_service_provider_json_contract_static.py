#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/mail_service'
required = {'detect.json': 'queuebash.mail_service.detect.v1', 'domain.json': 'queuebash.mail_service.domain.v1', 'sender.json': 'queuebash.mail_service.sender.v1', 'delivery.json': 'queuebash.mail_service.delivery.v1', 'policy.json': 'queuebash.mail_service.policy.v1'}
for name_file, schema in required.items():
    obj = json.loads((fixtures / name_file).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name_file, obj.get('schema'))
    assert obj['provider_family'] == 'mail_service', name_file
    assert obj['provider'] == 'fixture', name_file
    assert obj['decision'] in ('allow', 'deny'), name_file
    assert obj.get('fail_closed') is True, name_file
    assert obj.get('mutated') is False, name_file
    assert obj.get('provider_output_is_shell') is False, name_file
    assert obj.get('live_api_used') is False, name_file
    assert obj.get('credentials_required') is False, name_file
    forbidden = ['access_key', 'api_key', 'certificate_private_key', 'client_secret', 'credential', 'email_body', 'license_key', 'mail_body', 'message_body', 'object_body', 'package_payload', 'password', 'private_key', 'secret', 'secret_value', 'session_cookie', 'signing_key', 'tls_private_key', 'token']
    assert not (set(forbidden) & {k.lower() for k in obj}), name_file

service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['mail_service']
assert fam['status'] == 'fixture_first_provider_family'
assert service['default_safety_contract']['normalized_json_only'] is True
print('PASS mail_service_provider_json_contract_static')
