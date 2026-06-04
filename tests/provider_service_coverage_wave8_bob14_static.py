#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
for family, priority in {'schema_registry': 14, 'data_quality': 15}.items():
    fam = service['families'][family]
    assert fam['status'] == 'fixture_first_provider_family', family
    assert fam['priority'] == priority, family
    for key in ('provider_dir','policy_dir','fixture_dir','doc_prefix'):
        assert fam.get(key), (family, key)
    assert (root / 'providers.d' / family / f'{family}_provider.sh').exists(), family
    assert (root / 'policies.d' / family / 'default-policy.example.json').exists(), family
    assert (root / 'tests' / 'fixtures' / family).is_dir(), family
    assert fam['schemas'], family
assert service['next_candidates'] == ['identity_provider', 'notification_service']
print('PASS provider_service_coverage_wave8_bob14_static')
