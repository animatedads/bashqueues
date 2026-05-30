#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
parity = json.loads((root / 'policies.d/cloud-resource/platform-parity.json').read_text(encoding='utf-8'))
assert parity['schema'] == 'queuebash.cloud_platform_parity.v1'
assert parity['verdict'] == 'not_equal_yet'
for name in ['azure', 'gcp']:
    item = parity['platforms'][name]
    assert item['first_class'] is True, name
    assert item['provider_json_contract'] is True, name
    assert item['asset_checks'] is True, name
    assert item['governance'] is True, name
    assert item['gdpr_data_protection'] is True, name
    assert item['itar_export_control'] is True, name
    assert item['finops_cost'] is True, name
    assert item['fixtures'] is True, name
    assert item['static_smoke_json_tests'] is True, name
    assert '0.18.52' in item['notes'], name

families = json.loads((root / 'policies.d/cloud-resource/provider-family-consistency.json').read_text(encoding='utf-8'))['families']
assert families['azure']['status'] == 'first_tier_contract'
assert families['gcp']['status'] == 'first_tier_contract'

for provider in ['azure', 'gcp']:
    cost = json.loads((root / f'policies.d/{provider}/cost-policy.example.json').read_text(encoding='utf-8'))
    export = json.loads((root / f'policies.d/{provider}/export-control.example.json').read_text(encoding='utf-8'))
    assert cost['provider'] == provider
    assert cost['billing_api_live_checks_default'] is False
    assert cost['status'] == 'mapped_pending_validation'
    assert export['provider'] == provider
    assert 'ITAR' in export['controls']
    assert export['fail_closed'] is True
    assert export['status'] == 'mapped_pending_validation'

for doc in [
    root / 'docs/AZURE_PROVIDER_CONTRACTS.md',
    root / 'docs/GCP_PROVIDER_CONTRACTS.md',
    root / 'docs/CLOUD_PLATFORM_PARITY_AZURE_GCP_FIRST_TIER.md',
]:
    text = doc.read_text(encoding='utf-8')
    assert 'No live' in text or 'no live' in text

print('PASS azure_gcp_first_tier_platform_parity_json_contract_static')
