# Cloud provisioning registry handoff

`cloud_provision` is the signed work-order layer. `cloud_resource` is the
booking desk and inventory ledger. This package connects the two with a
controlled, local-only registry handoff.

The handoff writes a normalized `queuebash.cloud_resource.v1` record into the
file-backed cloud resource registry. It does **not** create, start, stop,
modify, or destroy any cloud resource. It does not call provider APIs and it is
not wired into queue dispatch.

## Command surface

```sh
providers.d/cloud_provision/cloud_provision.sh handoff-explain aws-ec2-gdpr --json
providers.d/cloud_provision/cloud_provision.sh registry-handoff aws-ec2-gdpr --registry /tmp/qb-cloud-reg --json
```

`handoff-explain` evaluates whether the plan can be handed to the registry and
explains the gates without writing anything.

`registry-handoff` writes a local resource record through
`providers.d/cloud_resource/cloud_resource_provider.sh add`.

## Handoff states

Supported states are:

```text
planned
approved
provisioning
observed
claimable
retired
failed
```

The default state is `planned`. Planned, approved, and provisioning records are
explicitly labelled `not-claimable` and are not matched by the current
`cloud_resource` claim logic.

`claimable` is intentionally explicit. A caller must request:

```sh
providers.d/cloud_provision/cloud_provision.sh registry-handoff aws-ec2-gdpr --state claimable --json
```

Only then does the record use `lifecycle_state=ready` and `status=available` so
that a later `cloud_resource claim-matching` operation can select it.

## Boundary

The boundary remains:

```text
cloud_provision:
  templates, plan/validate/explain/dry-run, lifecycle dry-run evidence,
  controlled registry handoff records

cloud_resource:
  inventory, resource records, claim/release/heartbeat/reconcile,
  policy-consumable resource facts

cloud_infra:
  gated lifecycle helper rails, dry-run by default

queue dispatch:
  unchanged
```

Provider credentials alone must never be sufficient for live provisioning. This
handoff package still has no live apply path.
