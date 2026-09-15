# queue plan handoff contract

Bob24 continuation for `queue plan` after the big 0.18.138 merge.

`queue plan handoff PATH [--json]` packages the supplied-file plan/status material into one advisory operator packet. It combines the existing Bob24 views:

- source contracts
- runtime/status source facts
- evidence bundle counts
- Plan-vs-Job reconcile summary
- policy requirements
- approval gates
- unsupported/unsafe blockers
- no-live attestations

The handoff command exists because the plan lane now has enough independent review surfaces that an operator, RTO lane, policy lane, or future collector lane needs a single reportable boundary object.

## Schema

```text
queue.plan.handoff.v1
```

The handoff packet is not an apply plan. It is not a live collector. It is not a reconciler executor. It is a supplied-evidence handoff bundle for review and policy gating.

## Command

```bash
queue plan handoff PATH [--json]
```

## JSON shape

Important fields:

```json
{
  "schema": "queue.plan.handoff.v1",
  "status": "review_required",
  "handoff": {
    "packet_kind": "supplied_evidence_policy_handoff",
    "evidence_counts": {},
    "reconcile_summary": {},
    "source_contract_count": 0,
    "status_source_count": 0,
    "policy_requirement_count": 0,
    "approval_gate_count": 0,
    "blocker_count": 0,
    "safe_to_stage": true,
    "safe_to_apply": false
  },
  "policy_requirements": [],
  "approval_gates": [],
  "blockers": [],
  "source_contracts": [],
  "status_sources": [],
  "correlations": [],
  "unmatched_plan_definitions": [],
  "orphan_runtime_job_status": [],
  "next_actions": [],
  "attestations": []
}
```

## Boundary

`queue plan handoff` must not:

- make no SDK/API/CLI calls
- open WinRM, SMB, RPC, REST, GraphQL or Kubernetes API connections
- load credentials
- read secrets
- tail logs
- poll live job state
- submit jobs
- mutate providers
- execute or source input files
- create no parallel cron scheduler

It only consumes files that have already been supplied to it.

## Cron boundary

Cron remains a special existing bashqueues surface. Handoff may describe cron-like schedule evidence, but it must preserve the current bashqueues cron/schedule machinery and must not introduce a replacement scheduler.

## RTO / policy handoff note

RTO and policy lanes may use the handoff output as review evidence, especially when cloud workflow or DGX/GPU policy hooks are present. The handoff packet is advisory: live details must come from separate policy-gated collectors that export inert evidence files for `queue plan` to consume.
