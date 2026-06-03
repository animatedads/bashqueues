#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
svc = json.loads((root / 'policies.d/service-coverage/provider-service-coverage.json').read_text(encoding='utf-8'))
assert svc['schema'] == 'queuebash.provider_service_coverage.v1'
safety = svc['default_safety_contract']
for key in ['fixture_first','normalized_json_only']:
    assert safety[key] is True, key
for key in ['live_api_default','credentials_required_for_default_tests','provisioning_default','queue_dispatch_refactor','provider_output_is_shell']:
    assert safety[key] is False, key
for name in ['model_registry', 'container_registry']:
    fam = svc['families'][name]
    assert fam['status'] == 'fixture_first_provider_family', name
    assert (root / 'providers.d' / fam['provider_dir']).is_dir(), name
    assert any((root / 'providers.d' / fam['provider_dir']).glob('*.sh')), name
    assert (root / 'policies.d' / fam['policy_dir']).is_dir(), name
    assert (root / 'tests' / 'fixtures' / fam['fixture_dir']).is_dir(), name
    for suffix in ['PROVIDER_CONTRACTS.md','EXPLAINABILITY.md','LEGAL_COMPLIANCE.md']:
        assert (root / 'docs' / f"{fam['doc_prefix']}_{suffix}").exists(), (name, suffix)
    assert (root / 'tests' / f'{name}_provider_contracts_static.sh').exists(), name
    assert (root / 'tests' / f'{name}_provider_fixture_smoke.sh').exists(), name
    assert (root / 'tests' / f'{name}_provider_json_contract_static.py').exists(), name
roadmap = (root / 'docs/PROVIDER_SERVICE_COVERAGE_ROADMAP.md').read_text(encoding='utf-8')
assert 'implemented as fixture-first Bob14 contract in 0.18.89' in roadmap
assert 'do not perform live API' in roadmap
print('PASS provider_service_coverage_bob14_static')
