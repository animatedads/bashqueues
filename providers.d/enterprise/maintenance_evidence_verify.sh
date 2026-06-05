#!/usr/bin/env bash
set -euo pipefail
usage(){ cat <<'USAGE'
Usage: providers.d/enterprise/maintenance_evidence_verify.sh --request FILE [--json]
       providers.d/enterprise/maintenance_evidence_verify.sh FILE [--json]

Fixture-only verifier for hospital approved-maintenance evidence. It reads a
bounded JSON fixture and emits redacted decision metadata only. It does not run
commands, source policy, deliver secrets, contact providers, modify systems, or
grant live clearance.
USAGE
}
request=""; json=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --request) request="${2:-}"; shift 2 ;;
    --json) json=1; shift ;;
    --help|-h) usage; exit 0 ;;
    --*) echo "maintenance_evidence_verify: unknown option: $1" >&2; exit 2 ;;
    *) if [[ -z "$request" ]]; then request="$1"; shift; else echo "maintenance_evidence_verify: extra argument: $1" >&2; exit 2; fi ;;
  esac
done
[[ -n "$request" ]] || { echo "maintenance_evidence_verify: request file required" >&2; exit 2; }
[[ -f "$request" ]] || { echo "maintenance_evidence_verify: request file missing: $request" >&2; exit 1; }
export PYTHONNOUSERSITE=1
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1
python3 - "$request" "$json" <<'PY'
import datetime as _dt
import hashlib
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
as_json = sys.argv[2] == '1'
try:
    raw = path.read_bytes()
    obj = json.loads(raw.decode())
except Exception as exc:
    print(f"maintenance_evidence_verify: invalid json: {exc}", file=sys.stderr)
    sys.exit(1)

failures = []

def get(d, *keys, default=None):
    cur = d
    for key in keys:
        if not isinstance(cur, dict) or key not in cur:
            return default
        cur = cur[key]
    return cur

def parse_utc_z(value, failure_name):
    if not isinstance(value, str) or not value.endswith('Z'):
        failures.append(failure_name)
        return None
    try:
        return _dt.datetime.fromisoformat(value[:-1] + '+00:00')
    except ValueError:
        failures.append(failure_name)
        return None

def hash_text(value):
    if value is None:
        value = ''
    if not isinstance(value, str):
        value = json.dumps(value, sort_keys=True)
    return 'sha256:' + hashlib.sha256(value.encode('utf-8')).hexdigest()

schema = obj.get('schema')
profile = obj.get('profile', '')
evidence_id = obj.get('evidence_id', '')
requester = obj.get('requester', '')
created_at = obj.get('created_at')
expires_at = obj.get('expires_at')
window_start = get(obj, 'maintenance_window', 'start')
window_end = get(obj, 'maintenance_window', 'end')
requested_actions = obj.get('requested_actions')
if not isinstance(requested_actions, list):
    requested_actions = []
cluster = obj.get('cluster')
cluster_required = bool(cluster) or any(isinstance(a, str) and 'cluster' in a.lower() for a in requested_actions)

if schema != 'queuebash.enterprise_maintenance_evidence_request.v1':
    failures.append('schema_mismatch')
if profile != 'hospital-live-approved-maintenance-default':
    failures.append('profile_not_approved_maintenance')
if not obj.get('change_ticket'):
    failures.append('missing_change_ticket')
if not evidence_id:
    failures.append('missing_evidence_id')
if not requester:
    failures.append('missing_requester')
if not created_at:
    failures.append('missing_created_at')
if not expires_at:
    failures.append('missing_expires_at')
if not obj.get('maintenance_class'):
    failures.append('missing_maintenance_class')
if not obj.get('purpose'):
    failures.append('missing_purpose')
if not window_start or not window_end:
    failures.append('missing_maintenance_window')
if not isinstance(obj.get('requested_actions'), list) or not obj.get('requested_actions'):
    failures.append('missing_requested_actions')
if get(obj, 'approval', 'dual_control') is not True:
    failures.append('dual_control_required')
if get(obj, 'approval', 'signed_approval') is not True:
    failures.append('signed_approval_required')
approvers = get(obj, 'approval', 'approvers', default=[])
if not isinstance(approvers, list) or len([a for a in approvers if a]) < 2:
    failures.append('two_approvers_required')
if requester and isinstance(approvers, list) and requester in approvers:
    failures.append('requester_must_not_approve_own_maintenance')
rollback_ok = bool(get(obj, 'rollback', 'procedure')) or bool(get(obj, 'rollback', 'command'))
if not rollback_ok:
    failures.append('rollback_evidence_required')
if not get(obj, 'audit', 'audit_path'):
    failures.append('audit_path_required')
if get(obj, 'policy', 'policy_root') != '/etc/queuebash/policies.d':
    failures.append('canonical_policy_root_required')
if get(obj, 'secrets', 'secret_env_allowed') is not False:
    failures.append('secret_env_must_be_denied')
if get(obj, 'secrets', 'secret_value_json_allowed') is not False:
    failures.append('secret_value_json_must_be_denied')
if get(obj, 'ai', 'external_provider_allowed') is not False:
    failures.append('external_ai_must_be_denied_by_default')
if obj.get('live_clearance_requested') is not False:
    failures.append('broad_live_clearance_not_allowed')

if cluster_required and not isinstance(cluster, dict):
    failures.append('cluster_context_required')
    cluster = {}
if cluster_required:
    if cluster.get('schema') != 'queuebash.enterprise_maintenance_cluster_context.v1':
        failures.append('cluster_context_schema_required')
    scope = cluster.get('scope')
    if scope not in ('standalone', 'single-node', 'cluster'):
        failures.append('cluster_scope_invalid')
    node_targets = cluster.get('node_targets')
    if not isinstance(node_targets, list) or not [n for n in node_targets if n]:
        failures.append('cluster_node_targets_required')
    elif any(n in ('*', 'all', 'ALL') for n in node_targets):
        failures.append('cluster_node_targets_must_be_explicit')
    if cluster.get('network_touched') is not False:
        failures.append('cluster_fixture_must_not_touch_network')
    if cluster.get('cluster_wide_mutation_allowed') is not False:
        failures.append('cluster_wide_mutation_not_allowed')
    timing_skew = get(cluster, 'timing', 'skew_budget_seconds')
    if not isinstance(timing_skew, int) or timing_skew < 0 or timing_skew > 5:
        failures.append('cluster_skew_budget_required')
    if scope == 'cluster':
        if cluster.get('cluster_enabled') is not True:
            failures.append('cluster_enabled_required_for_cluster_scope')
        if cluster.get('quorum_met') is not True:
            failures.append('cluster_quorum_required')
        if get(cluster, 'voting', 'required') is not True or get(cluster, 'voting', 'approved') is not True:
            failures.append('cluster_vote_approval_required')
        if get(cluster, 'leader_lease', 'valid') is not True:
            failures.append('cluster_leader_lease_required')

        membership = cluster.get('membership')
        members = get(cluster, 'membership', 'members', default=[])
        membership_hash = get(cluster, 'membership', 'hash')
        if not isinstance(membership, dict):
            failures.append('cluster_membership_required')
            members = []
        elif not isinstance(members, list) or not [m for m in members if m]:
            failures.append('cluster_membership_members_required')
            members = []
        if not isinstance(membership_hash, str) or not membership_hash.startswith('sha256:'):
            failures.append('cluster_membership_hash_required')
        if isinstance(node_targets, list) and isinstance(members, list) and members:
            unknown_targets = [n for n in node_targets if n not in members]
            if unknown_targets:
                failures.append('cluster_node_targets_must_be_in_membership')
        leader_id = get(cluster, 'leader_lease', 'leader_id')
        if leader_id and isinstance(members, list) and members and leader_id not in members:
            failures.append('cluster_leader_must_be_in_membership')

        quorum = cluster.get('quorum')
        required_count = get(cluster, 'quorum', 'required_count')
        approver_nodes = get(cluster, 'voting', 'approver_nodes', default=[])
        if not isinstance(quorum, dict) or not isinstance(required_count, int) or required_count <= 0:
            failures.append('cluster_quorum_count_required')
        elif isinstance(members, list) and members and required_count > len(members):
            failures.append('cluster_quorum_count_exceeds_membership')
        if not isinstance(approver_nodes, list) or not approver_nodes:
            failures.append('cluster_vote_nodes_required')
        elif isinstance(required_count, int) and len(set(approver_nodes)) < required_count:
            failures.append('cluster_vote_nodes_below_quorum')
        if isinstance(approver_nodes, list) and isinstance(members, list) and members:
            unknown_voters = [n for n in approver_nodes if n not in members]
            if unknown_voters:
                failures.append('cluster_vote_nodes_must_be_in_membership')

        fencing = cluster.get('fencing')
        fence_hash = get(cluster, 'fencing', 'token_hash')
        if not isinstance(fencing, dict) or fencing.get('enabled') is not True:
            failures.append('cluster_fencing_required')
        if not isinstance(fence_hash, str) or not fence_hash.startswith('sha256:'):
            failures.append('cluster_fence_token_hash_required')
        if isinstance(fencing, dict) and ('token' in fencing or 'raw_token' in fencing):
            failures.append('cluster_fence_token_must_be_redacted')
        if cluster.get('split_brain_guard') is not True:
            failures.append('cluster_split_brain_guard_required')

        blast = cluster.get('blast_radius')
        if not isinstance(blast, dict):
            failures.append('cluster_blast_radius_required')
        else:
            max_nodes = blast.get('max_nodes')
            per_batch = blast.get('per_batch')
            percentage = blast.get('percentage')
            if not isinstance(max_nodes, int) or max_nodes <= 0:
                failures.append('cluster_blast_radius_max_nodes_required')
            elif isinstance(node_targets, list) and max_nodes < len(set(node_targets)):
                failures.append('cluster_blast_radius_covers_targets_required')
            if not isinstance(per_batch, int) or per_batch <= 0:
                failures.append('cluster_blast_radius_per_batch_required')
            elif isinstance(node_targets, list) and per_batch > max(1, len(set(node_targets))):
                failures.append('cluster_blast_radius_per_batch_exceeds_targets')
            if not isinstance(percentage, int) or percentage <= 0 or percentage > 50:
                failures.append('cluster_blast_radius_percentage_limited')

        canary = cluster.get('canary')
        if not isinstance(canary, dict):
            failures.append('cluster_canary_required')
        else:
            canary_nodes = canary.get('nodes')
            if canary.get('required') is not True:
                failures.append('cluster_canary_required')
            if canary.get('completed') is not True:
                failures.append('cluster_canary_completion_required')
            if not isinstance(canary_nodes, list) or not canary_nodes:
                failures.append('cluster_canary_nodes_required')
            elif isinstance(node_targets, list):
                unknown_canary = [n for n in canary_nodes if n not in node_targets]
                if unknown_canary:
                    failures.append('cluster_canary_nodes_must_be_targeted')
            if canary.get('health_after') != 'ok':
                failures.append('cluster_canary_health_ok_required')

        drain = cluster.get('drain')
        if not isinstance(drain, dict):
            failures.append('cluster_drain_evidence_required')
        else:
            if drain.get('required') is not True:
                failures.append('cluster_drain_required')
            if drain.get('verified') is not True:
                failures.append('cluster_drain_verified_required')
            if drain.get('eviction_budget_ok') is not True:
                failures.append('cluster_eviction_budget_required')
            if drain.get('data_loss_risk') not in ('none', 'low'):
                failures.append('cluster_drain_data_loss_risk_too_high')

        rollback_cluster = cluster.get('rollback')
        if not isinstance(rollback_cluster, dict):
            failures.append('cluster_rollback_checkpoint_required')
        else:
            checkpoint_hash = rollback_cluster.get('checkpoint_hash')
            if not isinstance(checkpoint_hash, str) or not checkpoint_hash.startswith('sha256:'):
                failures.append('cluster_rollback_checkpoint_hash_required')
            if rollback_cluster.get('tested') is not True:
                failures.append('cluster_rollback_tested_required')
            if 'checkpoint' in rollback_cluster or 'raw_checkpoint' in rollback_cluster:
                failures.append('cluster_rollback_checkpoint_must_be_redacted')

        observation = cluster.get('observation')
        if not isinstance(observation, dict):
            failures.append('cluster_observation_required')
        else:
            if observation.get('required') is not True:
                failures.append('cluster_observation_required')
            if observation.get('completed') is not True:
                failures.append('cluster_observation_completion_required')
            window_seconds = observation.get('window_seconds')
            if not isinstance(window_seconds, int) or window_seconds < 300 or window_seconds > 86400:
                failures.append('cluster_observation_window_required')
            health = observation.get('health')
            if not isinstance(health, dict):
                failures.append('cluster_observation_health_required')
            else:
                if health.get('status') != 'ok':
                    failures.append('cluster_observation_health_ok_required')
                if health.get('degraded_nodes') not in ([], None):
                    failures.append('cluster_observation_no_degraded_nodes_required')
            slo = observation.get('slo')
            if not isinstance(slo, dict):
                failures.append('cluster_observation_slo_required')
            else:
                error_budget = slo.get('error_budget_remaining_percent')
                if not isinstance(error_budget, int) or error_budget < 90:
                    failures.append('cluster_observation_error_budget_required')
                if slo.get('latency_regression') is not False:
                    failures.append('cluster_observation_latency_regression_denied')
                if slo.get('error_rate_regression') is not False:
                    failures.append('cluster_observation_error_rate_regression_denied')
            evidence_hash = observation.get('evidence_hash')
            if not isinstance(evidence_hash, str) or not evidence_hash.startswith('sha256:'):
                failures.append('cluster_observation_evidence_hash_required')
            if 'raw_evidence' in observation or 'probe_output' in observation or 'logs' in observation:
                failures.append('cluster_observation_raw_evidence_must_be_redacted')

        abort = cluster.get('abort_criteria')
        if not isinstance(abort, dict):
            failures.append('cluster_abort_criteria_required')
        else:
            if abort.get('defined') is not True:
                failures.append('cluster_abort_criteria_defined_required')
            if abort.get('auto_stop_on_breach') is not True:
                failures.append('cluster_abort_auto_stop_required')
            triggers = abort.get('triggers')
            if not isinstance(triggers, list) or not triggers:
                failures.append('cluster_abort_triggers_required')
            required_triggers = {'health_degraded', 'slo_regression', 'quorum_lost'}
            if isinstance(triggers, list) and not required_triggers.issubset(set(triggers)):
                failures.append('cluster_abort_required_triggers_missing')
            if abort.get('manual_override_allowed') is not False:
                failures.append('cluster_abort_manual_override_denied')
            if 'raw_policy' in abort or 'script' in abort:
                failures.append('cluster_abort_policy_must_be_redacted')
            policy_hash = abort.get('policy_hash')
            if not isinstance(policy_hash, str) or not policy_hash.startswith('sha256:'):
                failures.append('cluster_abort_policy_hash_required')

        incident = cluster.get('incident_response')
        if not isinstance(incident, dict):
            failures.append('cluster_incident_response_required')
        else:
            if incident.get('pager_ready') is not True:
                failures.append('cluster_incident_pager_ready_required')
            if incident.get('rollback_owner_ack') is not True:
                failures.append('cluster_incident_rollback_owner_ack_required')
            if incident.get('freeze_on_incident') is not True:
                failures.append('cluster_incident_freeze_on_incident_required')
            if incident.get('comms_channel_hash', '').startswith('sha256:') is not True:
                failures.append('cluster_incident_comms_channel_hash_required')
            if 'comms_channel' in incident or 'raw_contact' in incident:
                failures.append('cluster_incident_contacts_must_be_redacted')

        evidence_bundle = cluster.get('evidence_bundle')
        if not isinstance(evidence_bundle, dict):
            failures.append('cluster_evidence_bundle_required')
        else:
            if evidence_bundle.get('sealed') is not True:
                failures.append('cluster_evidence_bundle_seal_required')
            if evidence_bundle.get('tamper_evident') is not True:
                failures.append('cluster_evidence_bundle_tamper_evidence_required')
            bundle_hash = evidence_bundle.get('bundle_hash')
            if not isinstance(bundle_hash, str) or not bundle_hash.startswith('sha256:'):
                failures.append('cluster_evidence_bundle_hash_required')
            signature_hash = evidence_bundle.get('signature_hash')
            if not isinstance(signature_hash, str) or not signature_hash.startswith('sha256:'):
                failures.append('cluster_evidence_bundle_signature_hash_required')
            signer_hash = evidence_bundle.get('signer_hash')
            if not isinstance(signer_hash, str) or not signer_hash.startswith('sha256:'):
                failures.append('cluster_evidence_bundle_signer_hash_required')
            if evidence_bundle.get('signature_status') != 'verified':
                failures.append('cluster_evidence_bundle_signature_verified_required')
            retention_days = evidence_bundle.get('retention_days')
            if not isinstance(retention_days, int) or retention_days < 90:
                failures.append('cluster_evidence_bundle_retention_required')
            if evidence_bundle.get('immutable_storage') is not True:
                failures.append('cluster_evidence_bundle_immutable_storage_required')
            if 'raw_bundle' in evidence_bundle or 'signature' in evidence_bundle or 'signer' in evidence_bundle:
                failures.append('cluster_evidence_bundle_raw_material_must_be_redacted')

created_dt = parse_utc_z(created_at, 'created_at_must_be_utc_iso8601') if created_at else None
expires_dt = parse_utc_z(expires_at, 'expires_at_must_be_utc_iso8601') if expires_at else None
start_dt = parse_utc_z(window_start, 'maintenance_window_start_must_be_utc_iso8601') if window_start else None
end_dt = parse_utc_z(window_end, 'maintenance_window_end_must_be_after_start') if window_end else None
leader_lease_until = get(cluster if isinstance(cluster, dict) else {}, 'leader_lease', 'expires_at') if cluster_required else None
leader_lease_dt = parse_utc_z(leader_lease_until, 'cluster_leader_lease_expires_at_must_be_utc_iso8601') if leader_lease_until else None
if cluster_required and isinstance(cluster, dict) and cluster.get('scope') == 'cluster' and not leader_lease_until:
    failures.append('cluster_leader_lease_expiry_required')
if created_dt and expires_dt and expires_dt <= created_dt:
    failures.append('expires_at_must_be_after_created_at')
if start_dt and end_dt and end_dt <= start_dt:
    failures.append('maintenance_window_end_must_be_after_start')
if expires_dt and end_dt and expires_dt < end_dt:
    failures.append('evidence_must_not_expire_before_window_end')
if cluster_required and isinstance(cluster, dict) and cluster.get('scope') == 'cluster' and leader_lease_dt and end_dt and leader_lease_dt < end_dt:
    failures.append('cluster_leader_lease_must_cover_window')

cluster_checks = {
    'cluster_context_required': cluster_required,
    'cluster_context_present': isinstance(cluster, dict) and bool(cluster),
    'cluster_schema': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('schema') == 'queuebash.enterprise_maintenance_cluster_context.v1'),
    'cluster_node_targets_explicit': (not cluster_required) or (isinstance(cluster, dict) and isinstance(cluster.get('node_targets'), list) and bool(cluster.get('node_targets')) and not any(n in ('*', 'all', 'ALL') for n in cluster.get('node_targets', []))),
    'cluster_network_untouched': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('network_touched') is False),
    'cluster_wide_mutation_denied': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('cluster_wide_mutation_allowed') is False),
    'cluster_quorum': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (cluster.get('quorum_met') is True),
    'cluster_vote_approval': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (get(cluster, 'voting', 'required') is True and get(cluster, 'voting', 'approved') is True),
    'cluster_leader_lease': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (get(cluster, 'leader_lease', 'valid') is True and bool(leader_lease_until)),
    'cluster_leader_lease_covers_window': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or bool(leader_lease_dt and end_dt and leader_lease_dt >= end_dt),
    'cluster_membership_hash': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(get(cluster, 'membership', 'hash'), str) and get(cluster, 'membership', 'hash').startswith('sha256:')),
    'cluster_node_targets_in_membership': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('node_targets'), list) and isinstance(get(cluster, 'membership', 'members', default=[]), list) and bool(get(cluster, 'membership', 'members', default=[])) and all(n in get(cluster, 'membership', 'members', default=[]) for n in cluster.get('node_targets', []))),
    'cluster_quorum_count': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(get(cluster, 'quorum', 'required_count'), int) and get(cluster, 'quorum', 'required_count') > 0),
    'cluster_vote_nodes_cover_quorum': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(get(cluster, 'quorum', 'required_count'), int) and isinstance(get(cluster, 'voting', 'approver_nodes', default=[]), list) and len(set(get(cluster, 'voting', 'approver_nodes', default=[]))) >= get(cluster, 'quorum', 'required_count')),
    'cluster_fence_token_hash': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(get(cluster, 'fencing', 'token_hash'), str) and get(cluster, 'fencing', 'token_hash').startswith('sha256:')),
    'cluster_fence_token_redacted': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('fencing'), dict) and 'token' not in cluster.get('fencing', {}) and 'raw_token' not in cluster.get('fencing', {})),
    'cluster_split_brain_guard': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (cluster.get('split_brain_guard') is True),
    'cluster_blast_radius_limited': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('blast_radius'), dict) and isinstance(get(cluster, 'blast_radius', 'percentage'), int) and 0 < get(cluster, 'blast_radius', 'percentage') <= 50),
    'cluster_canary_completed': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('canary'), dict) and get(cluster, 'canary', 'required') is True and get(cluster, 'canary', 'completed') is True and get(cluster, 'canary', 'health_after') == 'ok'),
    'cluster_drain_verified': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('drain'), dict) and get(cluster, 'drain', 'required') is True and get(cluster, 'drain', 'verified') is True and get(cluster, 'drain', 'eviction_budget_ok') is True),
    'cluster_rollback_checkpoint_hash': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(get(cluster, 'rollback', 'checkpoint_hash'), str) and get(cluster, 'rollback', 'checkpoint_hash').startswith('sha256:')),
    'cluster_rollback_checkpoint_redacted': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('rollback'), dict) and 'checkpoint' not in cluster.get('rollback', {}) and 'raw_checkpoint' not in cluster.get('rollback', {})),
    'cluster_observation_completed': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('observation'), dict) and get(cluster, 'observation', 'required') is True and get(cluster, 'observation', 'completed') is True),
    'cluster_observation_health_ok': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(get(cluster, 'observation', 'health'), dict) and get(cluster, 'observation', 'health', 'status') == 'ok' and get(cluster, 'observation', 'health', 'degraded_nodes', default=[]) == []),
    'cluster_observation_slo_ok': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(get(cluster, 'observation', 'slo'), dict) and isinstance(get(cluster, 'observation', 'slo', 'error_budget_remaining_percent'), int) and get(cluster, 'observation', 'slo', 'error_budget_remaining_percent') >= 90 and get(cluster, 'observation', 'slo', 'latency_regression') is False and get(cluster, 'observation', 'slo', 'error_rate_regression') is False),
    'cluster_observation_evidence_redacted': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('observation'), dict) and isinstance(get(cluster, 'observation', 'evidence_hash'), str) and get(cluster, 'observation', 'evidence_hash').startswith('sha256:') and 'raw_evidence' not in cluster.get('observation', {}) and 'probe_output' not in cluster.get('observation', {}) and 'logs' not in cluster.get('observation', {})),
    'cluster_abort_criteria_ready': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('abort_criteria'), dict) and get(cluster, 'abort_criteria', 'defined') is True and get(cluster, 'abort_criteria', 'auto_stop_on_breach') is True and get(cluster, 'abort_criteria', 'manual_override_allowed') is False),
    'cluster_abort_policy_redacted': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('abort_criteria'), dict) and isinstance(get(cluster, 'abort_criteria', 'policy_hash'), str) and get(cluster, 'abort_criteria', 'policy_hash').startswith('sha256:') and 'raw_policy' not in cluster.get('abort_criteria', {}) and 'script' not in cluster.get('abort_criteria', {})),
    'cluster_incident_response_ready': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('incident_response'), dict) and get(cluster, 'incident_response', 'pager_ready') is True and get(cluster, 'incident_response', 'rollback_owner_ack') is True and get(cluster, 'incident_response', 'freeze_on_incident') is True),
    'cluster_incident_contacts_redacted': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('incident_response'), dict) and isinstance(get(cluster, 'incident_response', 'comms_channel_hash'), str) and get(cluster, 'incident_response', 'comms_channel_hash').startswith('sha256:') and 'comms_channel' not in cluster.get('incident_response', {}) and 'raw_contact' not in cluster.get('incident_response', {})),
    'cluster_evidence_bundle_sealed': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('evidence_bundle'), dict) and get(cluster, 'evidence_bundle', 'sealed') is True and get(cluster, 'evidence_bundle', 'tamper_evident') is True),
    'cluster_evidence_bundle_hashes': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('evidence_bundle'), dict) and isinstance(get(cluster, 'evidence_bundle', 'bundle_hash'), str) and get(cluster, 'evidence_bundle', 'bundle_hash').startswith('sha256:') and isinstance(get(cluster, 'evidence_bundle', 'signature_hash'), str) and get(cluster, 'evidence_bundle', 'signature_hash').startswith('sha256:') and isinstance(get(cluster, 'evidence_bundle', 'signer_hash'), str) and get(cluster, 'evidence_bundle', 'signer_hash').startswith('sha256:')),
    'cluster_evidence_bundle_signature_verified': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('evidence_bundle'), dict) and get(cluster, 'evidence_bundle', 'signature_status') == 'verified'),
    'cluster_evidence_bundle_retained': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('evidence_bundle'), dict) and isinstance(get(cluster, 'evidence_bundle', 'retention_days'), int) and get(cluster, 'evidence_bundle', 'retention_days') >= 90 and get(cluster, 'evidence_bundle', 'immutable_storage') is True),
    'cluster_evidence_bundle_redacted': (not cluster_required) or (isinstance(cluster, dict) and cluster.get('scope') != 'cluster') or (isinstance(cluster.get('evidence_bundle'), dict) and 'raw_bundle' not in cluster.get('evidence_bundle', {}) and 'signature' not in cluster.get('evidence_bundle', {}) and 'signer' not in cluster.get('evidence_bundle', {})),
}

checks = {
    'evidence_id_present': bool(evidence_id),
    'requester_present': bool(requester),
    'created_at_present': bool(created_at),
    'expires_at_present': bool(expires_at),
    'change_ticket': bool(obj.get('change_ticket')),
    'dual_control': get(obj, 'approval', 'dual_control') is True,
    'signed_approval': get(obj, 'approval', 'signed_approval') is True,
    'approver_independence': not (requester and isinstance(approvers, list) and requester in approvers),
    'rollback_evidence': rollback_ok,
    'audit_path': bool(get(obj, 'audit', 'audit_path')),
    'canonical_policy_root': get(obj, 'policy', 'policy_root') == '/etc/queuebash/policies.d',
    'secret_env_denied': get(obj, 'secrets', 'secret_env_allowed') is False,
    'secret_json_denied': get(obj, 'secrets', 'secret_value_json_allowed') is False,
    'external_ai_denied': get(obj, 'ai', 'external_provider_allowed') is False,
    'window_order_valid': bool(start_dt and end_dt and end_dt > start_dt),
    'expiry_covers_window': bool(expires_dt and end_dt and expires_dt >= end_dt),
}
checks.update(cluster_checks)
status = 'ok' if not failures else 'blocked'
decision = {
    'schema': 'queuebash.enterprise_maintenance_evidence_decision.v1',
    'status': status,
    'ok': status == 'ok',
    'profile': profile,
    'mode': 'fixture-only',
    'live_clearance_granted': False,
    'system_modified': False,
    'redacted': True,
    'secret_value_included': False,
    'evidence_id': evidence_id,
    'evidence_hash': 'sha256:' + hashlib.sha256(raw).hexdigest(),
    'requester_hash': hash_text(requester),
    'request_file': str(path),
    'checks': checks,
    'failures': failures,
}
if as_json:
    print(json.dumps(decision, sort_keys=True))
else:
    print(f"status\t{status}")
    print(f"profile\t{profile}")
    print(f"evidence_id\t{evidence_id}")
    for failure in failures:
        print(f"failure\t{failure}")
sys.exit(0 if status == 'ok' else 1)
PY
