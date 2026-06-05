# queue plan policy requirements

Bob24 continuation for 0.18.118 records plan-level policy requirements as first-class normalized facts.

`queue plan` still does not apply resources, submit jobs, read secrets, or call cloud/provider lifecycle APIs.  The policy view is a review surface over the same staged `queue.control_plan.v1` material.

## Command

```sh
queue plan policy PATH [--json]
```

The command reports `queue.plan.policy.v1` and lists policy hooks that must be reviewed before any future apply path.  It is intentionally read-only.

## DGX / cloud / workflow boundary

DGX/GPU plans often combine accelerator cost, model/data movement, cloud placement, workflow orchestration, identity delegation, object-storage artifacts and gateway exposure.  When a plan contains DGX/GPU hints, `queue plan` records:

- `DGX_CLOUD_WORKFLOW_POLICY_REVIEW`
- policy family `gpu-cloud`
- references to the existing `policies.d/gpu-cloud/*` policy fixtures
- lifecycle boundary: plan-only, no DGX/cloud lifecycle mutation from `queue plan`

When cloud-provider markers and workflow markers appear together, `queue plan` records:

- `CLOUD_WORKFLOW_POLICY_REVIEW`
- policy family `cloud-workflow`
- references to the existing cloud provisioning and lifecycle dry-run contracts
- lifecycle boundary: dry-run handoff only; live cloud lifecycle remains out of `queue plan`

## Design rule

Policy requirements belong in the normalized plan.  They must not be hidden in prose reports only.

Future apply implementations must consume `plan.policy_requirements` and `plan.approval_gates` before any class, gateway, schedule, lifecycle or job materialization occurs.
