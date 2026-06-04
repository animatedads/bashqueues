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
maintenance_class
purpose
maintenance_window.start
maintenance_window.end
requested_actions
approval.dual_control = true
approval.signed_approval = true
approval.approvers with at least two entries
rollback.procedure or rollback.command
audit.audit_path
policy.policy_root = /etc/queuebash/policies.d
secrets.secret_env_allowed = false
secrets.secret_value_json_allowed = false
ai.external_provider_allowed = false
live_clearance_requested = false
```

## Block conditions

The fixture verifier must fail closed if the request:

```text
claims broad live clearance
uses the readonly profile for maintenance execution
omits the change ticket
omits dual-control or signed approval
has fewer than two approvers
omits rollback evidence
omits audit path
uses /etc/bashqueues/policies.d as the active policy root
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
  "failures": []
}
```

Blocked decisions must include redacted failure reasons only. They must not include secret values, command output, provider tokens, or regulated payload data.

## Relationship to the hospital runbook

`docs/REGULATED_SERVICE_RUNBOOK.md` remains the operator-facing runbook. This contract supplies machine-checkable fixture evidence for the approved-maintenance part of that runbook. A future command surface may wrap the fixture provider, but passing this check alone must not be described as broad hospital live clearance.
