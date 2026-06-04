#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
service = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
for fam in ('metadata_catalog', 'artifact_store'):
    entry = service['families'][fam]
    assert entry['status'] == 'fixture_first_provider_family', fam
    assert (root / 'providers.d' / fam / f'{fam}_provider.sh').exists(), fam
    assert (root / 'policies.d' / fam / 'default-policy.example.json').exists(), fam
    assert (root / 'tests' / 'fixtures' / fam / 'detect.json').exists(), fam
    assert service['default_safety_contract']['fixture_first'] is True
    assert service['default_safety_contract']['provisioning_default'] is False
    assert service['default_safety_contract']['provider_output_is_shell'] is False
print('PASS provider_service_coverage_wave6_bob14_static')
