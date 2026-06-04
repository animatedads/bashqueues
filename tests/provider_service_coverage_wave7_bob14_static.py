#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
for family in ('workflow_orchestrator', 'event_stream'):
    fam = service['families'][family]
    assert fam['status'] == 'fixture_first_provider_family', family
    assert (root / 'providers.d' / family / f'{family}_provider.sh').exists(), family
    assert (root / 'policies.d' / family / 'default-policy.example.json').exists(), family
    assert (root / 'tests' / 'fixtures' / family / 'detect.json').exists(), family
    prefix = fam['doc_prefix']
    for suffix in ('PROVIDER_CONTRACTS', 'EXPLAINABILITY', 'LEGAL_COMPLIANCE'):
        assert (root / 'docs' / f'{prefix}_{suffix}.md').exists(), (family, suffix)
    for schema in fam['schemas']:
        assert schema.startswith(f'queuebash.{family}.'), schema
assert service['default_safety_contract']['fixture_first'] is True
assert service['default_safety_contract']['live_api_default'] is False
assert service['default_safety_contract']['provisioning_default'] is False
assert service['default_safety_contract']['queue_dispatch_refactor'] is False
print('PASS provider_service_coverage_wave7_bob14_static')
