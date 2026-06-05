#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[1]
helper = root / 'providers.d' / 'enterprise' / 'maintenance_evidence_verify.sh'
valid = root / 'tests' / 'fixtures' / 'enterprise' / 'maintenance_evidence' / 'valid_approved_maintenance.json'
cluster_valid = root / 'tests' / 'fixtures' / 'enterprise' / 'maintenance_evidence' / 'valid_cluster_maintenance.json'
proc = subprocess.run([str(helper), '--request', str(valid), '--json'], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
obj = json.loads(proc.stdout)
assert obj['schema'] == 'queuebash.enterprise_maintenance_evidence_decision.v1'
assert obj['status'] == 'ok'
assert obj['ok'] is True
assert obj['mode'] == 'fixture-only'
assert obj['live_clearance_granted'] is False
assert obj['system_modified'] is False
assert obj['redacted'] is True
assert obj['secret_value_included'] is False
assert obj['evidence_hash'].startswith('sha256:')
assert obj['requester_hash'].startswith('sha256:')
assert 'maintenance-requester@example.invalid' not in json.dumps(obj)
for key in [
    'evidence_id_present', 'requester_present', 'created_at_present',
    'expires_at_present', 'change_ticket', 'dual_control', 'signed_approval',
    'approver_independence', 'rollback_evidence', 'audit_path',
    'canonical_policy_root', 'secret_env_denied', 'secret_json_denied',
    'external_ai_denied', 'window_order_valid', 'expiry_covers_window',
    'cluster_context_required', 'cluster_context_present', 'cluster_schema',
    'cluster_node_targets_explicit', 'cluster_network_untouched',
    'cluster_wide_mutation_denied', 'cluster_quorum', 'cluster_vote_approval',
    'cluster_leader_lease', 'cluster_leader_lease_covers_window',
    'cluster_membership_hash', 'cluster_node_targets_in_membership',
    'cluster_quorum_count', 'cluster_vote_nodes_cover_quorum',
    'cluster_fence_token_hash', 'cluster_fence_token_redacted',
    'cluster_split_brain_guard'
]:
    assert key in obj['checks'], key
proc = subprocess.run([str(helper), '--request', str(cluster_valid), '--json'], cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
cluster_obj = json.loads(proc.stdout)
assert cluster_obj['checks']['cluster_context_required'] is True
assert cluster_obj['checks']['cluster_schema'] is True
assert cluster_obj['checks']['cluster_quorum'] is True
assert cluster_obj['checks']['cluster_vote_approval'] is True
assert cluster_obj['checks']['cluster_leader_lease_covers_window'] is True
assert cluster_obj['checks']['cluster_membership_hash'] is True
assert cluster_obj['checks']['cluster_vote_nodes_cover_quorum'] is True
assert cluster_obj['checks']['cluster_fence_token_redacted'] is True

for sample in ['approved_maintenance_request.example.json', 'approved_maintenance_decision.allowed.example.json', 'approved_maintenance_decision.blocked.example.json', 'approved_maintenance_cluster_context.example.json']:
    loaded = json.loads((root / 'schemas' / 'enterprise' / sample).read_text())
    assert loaded['schema'].startswith(('queuebash.enterprise_maintenance_', 'queuebash.enterprise_maintenance_cluster_'))
print('[PASS] enterprise_maintenance_evidence_json_contract_static')
