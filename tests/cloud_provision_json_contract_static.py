#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]

templates = json.loads((root / 'policies.d/cloud-provision/templates.example.json').read_text(encoding='utf-8'))
assert templates['schema'] == 'queuebash.cloud_provision.templates.v1'
items = templates['templates']
providers = {t['provider'] for t in items if not t['name'].startswith('bad-')}
for required in ['aws', 'oci', 'azure', 'gcp', 'ibm']:
    assert required in providers, f'missing provider template {required}'
for t in items:
    assert 'name' in t and 'provider' in t and 'resource_type' in t
    assert t.get('allow_live') is False

policy = json.loads((root / 'policies.d/cloud-provision/approval-policy.example.json').read_text(encoding='utf-8'))
assert policy['schema'] == 'queuebash.cloud_provision.approval_policy.v1'
assert 'allowed_regions' in policy['rules']
assert 'allowed_legal_frameworks' in policy['rules']
assert 'monthly_cost_ceiling' in policy['rules']

for name in ['oci-vm-gdpr', 'aws-ec2-gdpr', 'azure-vm-gdpr', 'gcp-compute-gdpr', 'ibm-vpc-gdpr']:
    plan = json.loads((root / f'examples/cloud-provision/{name}-plan.example.json').read_text(encoding='utf-8'))
    assert plan['schema'] == 'queuebash.cloud_provision.plan.v1'
    assert plan['template'] == name
    assert plan['live_mutation'] is False
    assert plan['mutated'] is False
    assert plan['resource_record_preview']['schema'] == 'queuebash.cloud_resource.v1'
    assert any(g['name'] == 'legal_framework_allowed' for g in plan['policy_gates'])
    assert any(g['name'] == 'cost_ceiling' for g in plan['policy_gates'])

print('PASS cloud_provision_json_contract_static')
