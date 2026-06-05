#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
svc = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text())
for fam in ('license_manager', 'configuration_database'):
    assert fam in svc['families'], fam
    entry = svc['families'][fam]
    assert entry['status'] == 'fixture_first_provider_family', fam
    assert (root / 'providers.d' / fam / f'{fam}_provider.sh').exists(), fam
    assert (root / 'policies.d' / fam / 'default-policy.example.json').exists(), fam
    assert (root / 'tests' / 'fixtures' / fam).exists(), fam
    for suffix in ('PROVIDER_CONTRACTS', 'EXPLAINABILITY', 'LEGAL_COMPLIANCE'):
        assert (root / 'docs' / f"{entry['doc_prefix']}_{suffix}.md").exists(), (fam, suffix)
    assert 'provisioning' in entry['non_goals'], fam
    assert 'queue-dispatch-refactor' in entry['non_goals'], fam
assert svc['next_candidates'] == ['service_mesh', 'object_storage']
print('PASS provider_service_coverage_wave12_bob14_static')
