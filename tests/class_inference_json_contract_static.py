#!/usr/bin/env python3
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
policy=json.loads((root/'policies.d/class-inference/default.json').read_text())
assert policy['schema']=='queuebash.class_inference.policy.v1'
assert policy['corporate_policy_refs']
assert policy['regulatory_refs']
assert policy['validation_status']=='mapped_pending_validation'
for name in ['recommendation.json','pinned_recommendation.json']:
    data=json.loads((root/'tests/fixtures/class_inference'/name).read_text())
    assert data['schema']=='queuebash.class_inference.recommendation.v1', name
    assert data['fingerprint']['schema']=='queuebash.class_inference.fingerprint.v1', name
    assert data['policy_linkage']['policy_references'], name
    assert data['policy_linkage']['corporate_policy_refs'], name
    assert data['policy_linkage']['regulatory_refs'], name
    assert data['non_mutating'] is True, name
    assert data['submit_integration']=='not_enabled_in_this_package', name
print('PASS class_inference_json_contract_static')
