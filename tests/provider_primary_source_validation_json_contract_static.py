#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
policy = json.loads((root / 'policies.d/cloud-resource/provider-primary-source-validation.json').read_text(encoding='utf-8'))
assert policy['schema'] == 'queuebash.provider_primary_source_validation.v1'
statuses = set(policy['accepted_statuses'])
for required in {
    'advisory_import',
    'mapped_pending_validation',
    'primary_source_validated',
    'accepted_project_criterion',
    'stale_validation',
    'rejected_or_superseded',
}:
    assert required in statuses, required
assert policy['default_status'] == 'mapped_pending_validation'
assert 'external_ai_output' in policy['not_primary_sources_by_themselves']
assert 'official_provider_documentation' in policy['primary_source_families']
region = policy['region_table_contract']
assert region['production_warning_required'] is True
for field in ['provider_family','region','jurisdiction','legal_framework','validation_status','source_ref','last_validated']:
    assert field in region['required_fields_when_validated'], field
export = policy['export_control_normalization']
for term in ['export_control_required','itar_review_required','gpu_or_accelerator_export_review_required','customer_data_transfer_review_required']:
    assert term in export['required_terms'], term
assert export['claim_without_validation'] == 'mapped_pending_validation'
secret = policy['secret_hygiene']
for forbidden in ['provider_tokens','private_keys','service_account_keys','signed_urls','par_urls','customer_data_logs']:
    assert forbidden in secret['forbidden_evidence_material'], forbidden
guards = policy['scope_guards']
assert guards['live_api_calls_default'] is False
assert guards['credentials_required_for_default_tests'] is False
assert guards['provisioning_default'] is False
assert guards['queue_dispatch_refactor'] is False
# Provider-family and explainability policies must keep their existing schemas.
family = json.loads((root / 'policies.d/cloud-resource/provider-family-consistency.json').read_text(encoding='utf-8'))
assert family['schema'] == 'queuebash.provider_family_consistency.v1'
explain = json.loads((root / 'policies.d/cloud-resource/provider-explainability-standard.json').read_text(encoding='utf-8'))
assert explain['schema'] == 'queuebash.provider_explainability_standard.v1'
print('PASS provider_primary_source_validation_json_contract_static')
