#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
policy = json.loads((root / 'policies.d/cloud-resource/provider-explainability-standard.json').read_text(encoding='utf-8'))
assert policy['schema'] == 'queuebash.provider_explainability_standard.v1'
assert policy['scope'] == 'bob2_provider_family_explainability'
safety = policy['default_safety_contract']
assert safety['fixture_first'] is True
assert safety['live_api_default'] is False
assert safety['credentials_required_for_default_tests'] is False
assert safety['provisioning_default'] is False
assert safety['queue_dispatch_refactor'] is False
assert safety['compliance_claims_default'] is False
for field in ['Provider','Check','Decision','Reason','Source','Fail-closed','Remediation','Validation status']:
    assert field in policy['required_human_fields'], field
for field in ['schema','provider','check','decision','reason','source','fail_closed','remediation_hint']:
    assert field in policy['required_json_concepts'], field
for status in ['first_tier_contract','high_standard_reference','fixture_first_provider_family','mapped_pending_validation','needs_primary_source_validation']:
    assert status in policy['status_vocabulary'], status
families = policy['provider_families']
for name in ['aws','gcp','azure','eu_sovereign','apac_china','gpu_cloud','edge_cloud','hybrid_onprem']:
    assert name in families, name
# Ensure accepted Bob2 family fixtures carry explainable decisions/reasons/sources.
fixture_roots = {
    'gcp': root / 'tests/fixtures/gcp',
    'azure': root / 'tests/fixtures/azure',
    'eu_sovereign': root / 'tests/fixtures/eu_sovereign',
    'apac_china': root / 'tests/fixtures/apac_china',
    'gpu_cloud': root / 'tests/fixtures/gpu_cloud',
    'edge_cloud': root / 'tests/fixtures/edge_cloud',
    'hybrid_onprem': root / 'tests/fixtures/hybrid_onprem',
}
for family, base in fixture_roots.items():
    assert base.exists(), family
    json_files = list(base.rglob('*.json'))
    assert json_files, family
    for jf in json_files:
        data = json.loads(jf.read_text(encoding='utf-8'))
        assert 'schema' in data, jf
        assert 'provider' in data, jf
        assert 'reason' in data, jf
        if 'decision' in data:
            assert data['decision'] in {'allow','available','deny','unknown'}, jf
        text = json.dumps(data)
        forbidden = ['PRIVATE KEY','BEGIN RSA','refresh_token','secret_access_key','signedUrl','signed_url_value','par_url_value']
        assert not any(token in text for token in forbidden), jf
# Docs must keep compliance claim status honest.
doc = (root / 'docs/PROVIDER_EXPLAINABILITY_STANDARD.md').read_text(encoding='utf-8')
assert 'not a compliance certification' in doc
assert 'not first-tier parity unless tests prove it' in doc
parity = (root / 'docs/CLOUD_PLATFORM_PARITY.md').read_text(encoding='utf-8')
assert '0.18.44 Bob2 provider explainability standardization' in parity
print('PASS provider_explainability_standard_json_contract_static')
