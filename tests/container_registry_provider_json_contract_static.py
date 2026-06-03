#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
fixtures = root / 'tests/fixtures/container_registry'
required = {
    'detect.json': 'queuebash.container_registry.detect.v1',
    'image.json': 'queuebash.container_registry.image.v1',
    'provenance.json': 'queuebash.container_registry.provenance.v1',
    'vulnerability.json': 'queuebash.container_registry.vulnerability.v1',
    'retention.json': 'queuebash.container_registry.retention.v1',
}
for name, schema in required.items():
    obj = json.loads((fixtures / name).read_text(encoding='utf-8'))
    assert obj['schema'] == schema, (name, obj.get('schema'))
    assert obj['provider_family'] == 'container_registry', name
    assert obj['provider'] == 'fixture', name
    assert obj['decision'] in ('allow', 'deny'), name
    assert obj.get('fail_closed') is True, name
    assert obj.get('mutated') is False, name
    forbidden = {'token','api_key','secret','password','credential','access_key'}
    assert not (forbidden & {k.lower() for k in obj}), name
image = json.loads((fixtures / 'image.json').read_text(encoding='utf-8'))
assert image['digest'].startswith('sha256:') and len(image['digest']) == 71
assert isinstance(image['architectures'], list) and image['architectures']
prov = json.loads((fixtures / 'provenance.json').read_text(encoding='utf-8'))
assert prov['signature_status'] == 'signed_fixture'
assert prov['sbom_status'] == 'fixture_present'
vuln = json.loads((fixtures / 'vulnerability.json').read_text(encoding='utf-8'))
assert vuln['critical_count'] == 0
assert vuln['high_count'] == 0
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
fam = service['families']['container_registry']
assert fam['status'] == 'fixture_first_provider_family'
assert fam['priority'] == 2
assert service['default_safety_contract']['provider_output_is_shell'] is False
print('PASS container_registry_provider_json_contract_static')
