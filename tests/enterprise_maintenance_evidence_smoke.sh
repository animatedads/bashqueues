#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 - <<'PY'
import json
import subprocess
from pathlib import Path
root = Path.cwd()
provider = root / 'providers.d' / 'enterprise' / 'maintenance_evidence_verify.sh'
fix = root / 'tests' / 'fixtures' / 'enterprise' / 'maintenance_evidence'

def run_case(name):
    proc = subprocess.run(
        [str(provider), '--request', str(fix / f'{name}.json'), '--json'],
        cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20
    )
    if not proc.stdout.strip():
        raise AssertionError(f'{name}: no stdout, stderr={proc.stderr!r}, rc={proc.returncode}')
    obj = json.loads(proc.stdout)
    assert obj['schema'] == 'queuebash.enterprise_maintenance_evidence_decision.v1', name
    assert obj['mode'] == 'fixture-only', name
    assert obj['live_clearance_granted'] is False, name
    assert obj['system_modified'] is False, name
    assert obj['redacted'] is True, name
    assert obj['secret_value_included'] is False, name
    assert obj.get('evidence_hash', '').startswith('sha256:'), name
    assert obj.get('requester_hash', '').startswith('sha256:'), name
    dumped = json.dumps(obj)
    assert 'maintenance-requester@example.invalid' not in dumped, name
    return proc.returncode, obj

rc, obj = run_case('valid_approved_maintenance')
assert rc == 0, obj
assert obj['ok'] is True and obj['status'] == 'ok', obj
assert obj['failures'] == [], obj
assert obj['checks']['approver_independence'] is True, obj
assert obj['checks']['expiry_covers_window'] is True, obj
rc, obj = run_case('valid_cluster_maintenance')
assert rc == 0, obj
assert obj['ok'] is True and obj['status'] == 'ok', obj
assert obj['checks']['cluster_context_required'] is True, obj
assert obj['checks']['cluster_quorum'] is True, obj
assert obj['checks']['cluster_vote_approval'] is True, obj
assert obj['checks']['cluster_leader_lease_covers_window'] is True, obj
assert obj['checks']['cluster_membership_hash'] is True, obj
assert obj['checks']['cluster_node_targets_in_membership'] is True, obj
assert obj['checks']['cluster_vote_nodes_cover_quorum'] is True, obj
assert obj['checks']['cluster_fence_token_hash'] is True, obj
assert obj['checks']['cluster_fence_token_redacted'] is True, obj
assert obj['checks']['cluster_split_brain_guard'] is True, obj
blocked = {
    'missing_rollback': 'rollback_evidence_required',
    'single_approver': 'two_approvers_required',
    'secret_env_requested': 'secret_env_must_be_denied',
    'wrong_policy_root': 'canonical_policy_root_required',
    'broad_live_clearance': 'broad_live_clearance_not_allowed',
    'requester_is_approver': 'requester_must_not_approve_own_maintenance',
    'expired_before_window_end': 'evidence_must_not_expire_before_window_end',
    'cluster_missing_quorum': 'cluster_quorum_required',
    'cluster_expired_leader_lease': 'cluster_leader_lease_must_cover_window',
    'cluster_wildcard_node_target': 'cluster_node_targets_must_be_explicit',
    'cluster_network_touched': 'cluster_fixture_must_not_touch_network',
    'cluster_missing_membership_hash': 'cluster_membership_hash_required',
    'cluster_target_outside_membership': 'cluster_node_targets_must_be_in_membership',
    'cluster_vote_below_quorum': 'cluster_vote_nodes_below_quorum',
    'cluster_raw_fence_token': 'cluster_fence_token_must_be_redacted',
    'cluster_missing_split_brain_guard': 'cluster_split_brain_guard_required',
}
for name, expected in blocked.items():
    rc, obj = run_case(name)
    assert rc != 0, (name, obj)
    assert obj['ok'] is False and obj['status'] == 'blocked', (name, obj)
    assert expected in obj['failures'], (name, expected, obj['failures'])
print('[PASS] enterprise_maintenance_evidence_smoke')
PY
