#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
for family, priority in [('access_review', 18), ('compliance_evidence', 19)]:
    meta = service['families'][family]
    assert meta['status'] == 'fixture_first_provider_family', family
    assert meta['priority'] == priority, family
    assert (root / 'providers.d' / family / f'{family}_provider.sh').is_file(), family
    assert (root / 'policies.d' / family / 'default-policy.example.json').is_file(), family
    assert (root / 'tests' / 'fixtures' / family / 'detect.json').is_file(), family
    assert meta['provider_dir'] == family, family
    assert meta['policy_dir'] == family, family
    assert meta['fixture_dir'] == family, family
    safety = service['default_safety_contract']
    assert safety['fixture_first'] is True
    assert safety['live_api_default'] is False
    assert safety['provisioning_default'] is False
    assert safety['queue_dispatch_refactor'] is False
    assert safety['provider_output_is_shell'] is False
print('PASS provider_service_coverage_wave10_bob14_static')
