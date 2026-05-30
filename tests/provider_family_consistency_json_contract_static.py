#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
status = json.loads((root / 'policies.d/cloud-resource/provider-family-consistency.json').read_text(encoding='utf-8'))
assert status['schema'] == 'queuebash.provider_family_consistency.v1'
assert status['verdict'] == 'not_equal_yet'
safety = status['default_safety_contract']
assert safety['fixture_first'] is True
assert safety['live_api_default'] is False
assert safety['credentials_required_for_default_tests'] is False
assert safety['provisioning_default'] is False
assert safety['queue_dispatch_refactor'] is False
families = status['families']
expected = {
    'aws', 'oci', 'ibm', 'gcp', 'azure', 'eu_sovereign', 'apac_china',
    'gpu_cloud', 'edge_cloud', 'hybrid_onprem'
}
assert expected.issubset(families), sorted(expected - set(families))
assert families['aws']['status'] == 'first_tier_contract'
assert families['azure']['status'] == 'first_tier_contract'
assert families['gcp']['status'] == 'first_tier_contract'
assert families['oci']['status'] == 'high_standard_reference'
assert families['ibm']['status'] == 'high_standard_reference'

for name in ['azure','gcp']:
    fam = families[name]
    provider_dir = fam['provider_dir']
    policy_dir = fam['policy_dir']
    fixture_dir = fam['fixture_dir']
    doc_prefix = fam['doc_prefix']
    class_prefix = fam['class_prefix']
    assert (root / 'providers.d' / provider_dir).is_dir(), name
    assert any((root / 'providers.d' / provider_dir).glob('*.sh')), name
    assert (root / 'policies.d' / policy_dir).is_dir(), name
    assert (root / 'tests' / 'fixtures' / fixture_dir).is_dir(), name
    assert (root / 'policies.d' / policy_dir / 'cost-policy.example.json').exists(), name
    assert (root / 'policies.d' / policy_dir / 'export-control.example.json').exists(), name
    for suffix in ['PROVIDER_CONTRACTS.md','CLASS_CRITERIA.md','EXPLAINABILITY.md','LEGAL_COMPLIANCE.md']:
        assert (root / 'docs' / f'{doc_prefix}_{suffix}').exists(), (name, suffix)
    assert list((root / 'classes').glob(f'{class_prefix}*.env')), name
    assert (root / 'tests' / f'{name}_provider_contracts_static.sh').exists(), (name, 'provider static')
    assert (root / 'tests' / f'{name}_provider_fixture_smoke.sh').exists(), (name, 'fixture smoke')
    assert (root / 'tests' / f'{name}_provider_json_contract_static.py').exists(), (name, 'json contract')

for name in ['eu_sovereign','apac_china','gpu_cloud','edge_cloud','hybrid_onprem']:
    fam = families[name]
    assert fam['status'] == 'fixture_first_provider_family', name
    provider_dir = fam['provider_dir']
    policy_dir = fam['policy_dir']
    fixture_dir = fam['fixture_dir']
    doc_prefix = fam['doc_prefix']
    class_prefix = fam['class_prefix']
    assert (root / 'providers.d' / provider_dir).is_dir(), name
    assert any((root / 'providers.d' / provider_dir).glob('*.sh')), name
    assert (root / 'policies.d' / policy_dir).is_dir(), name
    assert (root / 'tests' / 'fixtures' / fixture_dir).is_dir(), name
    for suffix in ['PROVIDER_CONTRACTS.md','CLASS_CRITERIA.md','EXPLAINABILITY.md','LEGAL_COMPLIANCE.md']:
        assert (root / 'docs' / f'{doc_prefix}_{suffix}').exists(), (name, suffix)
    assert list((root / 'classes').glob(f'{class_prefix}*.env')), name
    static_candidates = [root / 'tests' / f'{name}_provider_contracts_static.sh', root / 'tests' / f'{name}_provider_contract_static.sh']
    assert any(p.exists() for p in static_candidates), (name, 'provider static')
    assert (root / 'tests' / f'{name}_provider_fixture_smoke.sh').exists(), (name, 'fixture smoke')
    assert (root / 'tests' / f'{name}_provider_json_contract_static.py').exists(), (name, 'json contract')
# Reference providers have known material but are not forced through Bob2 fixture-family shape.
assert (root / 'docs/OCI_PROVIDER_CONTRACTS.md').exists()
assert (root / 'providers.d/oci/oci_provider.sh').exists()
assert list((root / 'classes').glob('CLOUD_OCI*.env'))
assert (root / 'docs/IBM_CLOUD_GOVERNANCE.md').exists()
assert list((root / 'classes').glob('CLOUD_IBM*.env'))
# Keep consistency docs honest.
doc = (root / 'docs/PROVIDER_FAMILY_CONSISTENCY.md').read_text(encoding='utf-8')
assert 'Provider-family presence is not the same as first-tier parity' in doc or 'Provider/platform entries should use' in doc
parity = (root / 'docs/CLOUD_PLATFORM_PARITY.md').read_text(encoding='utf-8')
assert '0.18.43 Bob2 provider-family consistency backfill' in parity
assert 'mapped pending validation' in parity
print('PASS provider_family_consistency_json_contract_static')
