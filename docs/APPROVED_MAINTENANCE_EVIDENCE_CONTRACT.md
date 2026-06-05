# Approved-maintenance evidence contract

This Bob17 contract extends the Rupert enterprise pilot lane for hospital-style regulated-service environments. It does **not** clear broad live execution. It defines the fixture evidence a tightly approved maintenance pilot must carry before any future runtime/router package may consider it eligible.

## Scope

The contract applies only to the `hospital-live-approved-maintenance-default` profile. It is fixture-first and evidence-only:

```text
mode: fixture-only
live_clearance_granted: false
system_modified: false
```

The verifier does not execute commands, source policy files, deliver secrets, contact providers, mutate system state, or grant production clearance.

## Required evidence

A maintenance evidence request uses schema `queuebash.enterprise_maintenance_evidence_request.v1` and must include:

```text
profile = hospital-live-approved-maintenance-default
change_ticket
evidence_id
requester
created_at
expires_at
maintenance_class
purpose
maintenance_window.start
maintenance_window.end
requested_actions
approval.dual_control = true
approval.signed_approval = true
approval.approvers with at least two entries
approval.approvers must not include requester
rollback.procedure or rollback.command
audit.audit_path
policy.policy_root = /etc/queuebash/policies.d
secrets.secret_env_allowed = false
secrets.secret_value_json_allowed = false
ai.external_provider_allowed = false
live_clearance_requested = false
```

## Retention and expiry hardening

The verifier treats approved-maintenance evidence as a short-lived authorisation envelope. It must include stable, redacted metadata sufficient for audit correlation without disclosing regulated data or secret values:

```text
evidence_id
requester
created_at
expires_at
maintenance_window.start
maintenance_window.end
```

The fixture verifier validates only deterministic evidence structure. It does not consult wall-clock time, contact an authority, or grant live runtime clearance. It does verify that:

```text
created_at, expires_at, maintenance_window.start, and maintenance_window.end are UTC ISO-8601 timestamps
expires_at is after created_at
maintenance_window.end is after maintenance_window.start
expires_at is not before maintenance_window.end
approval approvers are independent from requester
requester is present but redacted from decision output through requester_hash
evidence_id is present but secret-free
decision output contains evidence_hash and redacted=true
```

The `evidence_hash` is a SHA-256 hash of the request fixture bytes. It is audit correlation evidence, not a signature and not a production authorisation token.

## Block conditions

The fixture verifier must fail closed if the request:

```text
claims broad live clearance
uses the readonly profile for maintenance execution
omits the change ticket
omits evidence_id, requester, created_at, or expires_at
uses malformed or inconsistent timestamps
has evidence expiry before the maintenance window ends
omits dual-control or signed approval
has fewer than two approvers
lists requester as an approver
omits rollback evidence
omits audit path
uses /etc/bashqueues/policies.d as the active policy root (legacy path; should be rejected or migrated to /etc/queuebash/policies.d)
allows secret values in environment variables
allows secret values in JSON
allows external AI provider use by default
```

## JSON output

The verifier emits `queuebash.enterprise_maintenance_evidence_decision.v1`:

```json
{
  "schema": "queuebash.enterprise_maintenance_evidence_decision.v1",
  "status": "ok",
  "ok": true,
  "mode": "fixture-only",
  "live_clearance_granted": false,
  "system_modified": false,
  "profile": "hospital-live-approved-maintenance-default",
  "evidence_id": "maint-CHG-12345-001",
  "evidence_hash": "sha256:...",
  "requester_hash": "sha256:...",
  "redacted": true,
  "secret_value_included": false,
  "failures": []
}
```

Blocked decisions must include redacted failure reasons only. They must not include secret values, command output, provider tokens, regulated payload data, raw requester identity, raw approver identity, or raw purpose text.

## Relationship to the hospital runbook

`docs/REGULATED_SERVICE_RUNBOOK.md` remains the operator-facing runbook. This contract supplies machine-checkable fixture evidence for the approved-maintenance part of that runbook. A future command surface may wrap the fixture provider, but passing this check alone must not be described as broad hospital live clearance.

## Cluster-aware maintenance evidence

When an approved-maintenance request includes cluster-affecting actions, such as an action whose name contains `cluster`, the request must carry explicit cluster governance evidence. This remains fixture-only evidence. Passing the check must not be treated as permission to contact a live cluster, mutate nodes, start an election, cast a vote, or extend a leader lease.

Cluster context uses schema `queuebash.enterprise_maintenance_cluster_context.v1` and must include:

```text
cluster.scope = standalone | single-node | cluster
cluster.node_targets as explicit node names, never `*` or `all`
cluster.network_touched = false
cluster.cluster_wide_mutation_allowed = false
cluster.timing.skew_budget_seconds between 0 and 5
```

For `cluster.scope = cluster`, the verifier also requires:

```text
cluster.cluster_enabled = true
cluster.quorum_met = true
cluster.voting.required = true
cluster.voting.approved = true
cluster.leader_lease.valid = true
cluster.leader_lease.expires_at is UTC ISO-8601
cluster.leader_lease.expires_at covers the maintenance window end
```

Blocked cluster maintenance evidence includes redacted failure reasons such as:

```text
cluster_quorum_required
cluster_vote_approval_required
cluster_leader_lease_required
cluster_leader_lease_must_cover_window
cluster_node_targets_must_be_explicit
cluster_fixture_must_not_touch_network
cluster_wide_mutation_not_allowed
cluster_skew_budget_required
```

The cluster checks are intentionally evidence checks only. The fixture verifier does not read local cluster state, touch the network, renew leases, evaluate real quorum, or write any cluster policy.


## Cluster split-brain and fencing hardening

Cluster-scoped approved maintenance must also prove that the request is bound to a stable, redacted cluster governance snapshot. The fixture verifier still does not contact a cluster or renew any lease. It only checks the supplied evidence envelope.

For `cluster.scope = cluster`, the cluster context must include:

```text
cluster.membership.members as explicit node names
cluster.membership.hash as sha256:... redacted membership evidence
cluster.quorum.required_count as a positive integer not exceeding membership size
cluster.voting.approver_nodes as explicit member node names meeting quorum
cluster.fencing.enabled = true
cluster.fencing.token_hash = sha256:...
cluster.fencing.token and cluster.fencing.raw_token absent
cluster.split_brain_guard = true
cluster.node_targets must be a subset of cluster.membership.members
cluster.leader_lease.leader_id must be a member when supplied
```

Additional blocked cluster maintenance evidence includes redacted failure reasons such as:

```text
cluster_membership_hash_required
cluster_node_targets_must_be_in_membership
cluster_quorum_count_required
cluster_quorum_count_exceeds_membership
cluster_vote_nodes_required
cluster_vote_nodes_below_quorum
cluster_vote_nodes_must_be_in_membership
cluster_fencing_required
cluster_fence_token_hash_required
cluster_fence_token_must_be_redacted
cluster_split_brain_guard_required
cluster_leader_must_be_in_membership
```

This guards the fixture contract against split-brain style evidence where a request claims a quorum or leader lease but does not bind the vote to a redacted membership snapshot, explicit voter nodes, and a redacted fencing token hash.

## Cluster blast-radius, canary, drain, and rollback hardening

Cluster-scoped approved maintenance must also prove that the proposed change is bounded and reversible before any future runtime gate considers it eligible. This remains fixture evidence only. The verifier does not drain nodes, run health probes, create checkpoints, execute rollback, or contact the cluster.

For `cluster.scope = cluster`, the cluster context must include:

```text
cluster.blast_radius.max_nodes as a positive integer
cluster.blast_radius.per_batch as a positive integer not exceeding targeted nodes
cluster.blast_radius.percentage as an integer between 1 and 50
cluster.canary.required = true
cluster.canary.completed = true
cluster.canary.nodes as explicit targeted nodes
cluster.canary.health_after = ok
cluster.drain.required = true
cluster.drain.verified = true
cluster.drain.eviction_budget_ok = true
cluster.drain.data_loss_risk = none | low
cluster.rollback.checkpoint_hash = sha256:...
cluster.rollback.tested = true
cluster.rollback.checkpoint and cluster.rollback.raw_checkpoint absent
```

Additional blocked cluster maintenance evidence includes redacted failure reasons such as:

```text
cluster_blast_radius_required
cluster_blast_radius_max_nodes_required
cluster_blast_radius_covers_targets_required
cluster_blast_radius_per_batch_required
cluster_blast_radius_per_batch_exceeds_targets
cluster_blast_radius_percentage_limited
cluster_canary_required
cluster_canary_completion_required
cluster_canary_nodes_required
cluster_canary_nodes_must_be_targeted
cluster_canary_health_ok_required
cluster_drain_evidence_required
cluster_drain_required
cluster_drain_verified_required
cluster_eviction_budget_required
cluster_drain_data_loss_risk_too_high
cluster_rollback_checkpoint_required
cluster_rollback_checkpoint_hash_required
cluster_rollback_tested_required
cluster_rollback_checkpoint_must_be_redacted
```

The `cluster.rollback.checkpoint_hash` is redacted correlation evidence only. It is not a secret, not a snapshot payload, and not proof that a live rollback has been performed by bashqueues.


## Cluster observation and SLO hardening

Cluster-scoped approved maintenance must include post-change observation evidence before a future runtime gate can consider the request complete enough for controlled pilot workflows. This remains fixture evidence only. The verifier does not run probes, contact monitoring systems, read logs, or alter a live cluster.

For `cluster.scope = cluster`, the cluster context must include:

```text
cluster.observation.required = true
cluster.observation.completed = true
cluster.observation.window_seconds between 300 and 86400
cluster.observation.health.status = ok
cluster.observation.health.degraded_nodes = []
cluster.observation.slo.error_budget_remaining_percent >= 90
cluster.observation.slo.latency_regression = false
cluster.observation.slo.error_rate_regression = false
cluster.observation.evidence_hash = sha256:...
cluster.observation.raw_evidence absent
cluster.observation.probe_output absent
cluster.observation.logs absent
```

Additional blocked cluster maintenance evidence includes redacted failure reasons such as:

```text
cluster_observation_required
cluster_observation_completion_required
cluster_observation_window_required
cluster_observation_health_required
cluster_observation_health_ok_required
cluster_observation_no_degraded_nodes_required
cluster_observation_slo_required
cluster_observation_error_budget_required
cluster_observation_latency_regression_denied
cluster_observation_error_rate_regression_denied
cluster_observation_evidence_hash_required
cluster_observation_raw_evidence_must_be_redacted
```

The observation evidence is a redacted attestation envelope, not monitoring output. It must not include raw logs, raw probe output, or sensitive service telemetry.

## Cluster abort criteria and incident-response evidence hardening

Cluster-scoped approved maintenance must include a redacted stop/abort plan and incident-response readiness evidence before a future runtime gate can consider the request complete enough for controlled pilot workflows. This remains fixture evidence only. The verifier does not run probes, page responders, freeze a cluster, execute rollback, contact monitoring, or alter live systems.

Required fixture fields:

```text
cluster.abort_criteria.defined = true
cluster.abort_criteria.auto_stop_on_breach = true
cluster.abort_criteria.triggers includes health_degraded, slo_regression, quorum_lost
cluster.abort_criteria.manual_override_allowed = false
cluster.abort_criteria.policy_hash = sha256:...
cluster.incident_response.pager_ready = true
cluster.incident_response.rollback_owner_ack = true
cluster.incident_response.freeze_on_incident = true
cluster.incident_response.comms_channel_hash = sha256:...
```

Forbidden fixture fields:

```text
cluster.abort_criteria.raw_policy
cluster.abort_criteria.script
cluster.incident_response.comms_channel
cluster.incident_response.raw_contact
```

Fail-closed cases include missing abort criteria, missing incident response, manual override allowed, raw abort policy/script, missing policy hash, missing required triggers, raw comms channel/contact, pager not ready, rollback owner not acknowledged, or incident freeze not enabled.

## 0.18.125 evidence bundle retention hardening carry-forward

Required redacted evidence paths include `cluster.evidence_bundle.bundle_hash`, `cluster.evidence_bundle.retention_days >= 90`, and `cluster.observation.evidence_hash`. These requirements preserve the cluster evidence bundle hash contract while avoiding raw secret or raw bundle material in queued maintenance evidence.
