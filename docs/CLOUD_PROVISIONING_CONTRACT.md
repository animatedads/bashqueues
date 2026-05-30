# Cloud provisioning contract

`cloud_provision` is the controlled work-order layer between the provider-neutral
`cloud_resource` booking desk and the `cloud_infra` lifecycle helper layer.

This package is **contract/dry-run only**. It does not create, start, stop,
retire, or destroy cloud resources. It does not require provider credentials,
does not call live provider APIs, and does not refactor queue dispatch.

## Layer split

```text
cloud_resource
  inventory, resource records, availability, claims, releases, heartbeat,
  reconcile, provenance, and policy-consumable facts

cloud_infra
  gated start/stop/status helper rails for named services
  dry-run by default, mutation only in future explicitly gated packages

cloud_provision
  named templates, plan/validate/explain/dry-run workflow, policy gates,
  dry-run evidence, and future registry handoff plans
```

Queue dispatch may consume `cloud_resource` availability through assets/classes.
Queue dispatch must not directly call cloud provider lifecycle operations.

## Provider script

```bash
providers.d/cloud_provision/cloud_provision.sh templates --json
providers.d/cloud_provision/cloud_provision.sh plan aws-ec2-gdpr --json
providers.d/cloud_provision/cloud_provision.sh explain aws-ec2-gdpr --json
providers.d/cloud_provision/cloud_provision.sh dry-run aws-ec2-gdpr --json
```

The script emits stable JSON. The primary plan schema is:

```text
queuebash.cloud_provision.plan.v1
```

A plan includes:

```text
plan_id
provider
operation
resource_type
region
class
workload
data_protection
export_control
cost_estimate
policy_gates
resource_record_preview
live_mutation=false
mutated=false
```

The `resource_record_preview` is intentionally a preview of a future
`queuebash.cloud_resource.v1` record. In this package it is not inserted into a
registry and is not claimable.

## Mandatory policy gates

The contract checks these gate classes:

```text
provider allowed
region allowed
legal framework / data-protection basis present
classification present
ITAR / export-control marker allowed where requested
cost ceiling
live mutation denied in this package
audit evidence available through normalized plan JSON
```

A denied gate produces a fail-closed plan. A review gate may still produce a
plan, but it is not acceptance to perform live work.

## Current provider coverage

The first dry-run templates cover:

```text
OCI
AWS
Azure
GCP
IBM
```

Additional provider families already present in the source tree, such as EU
sovereign, APAC/China, and GPU cloud providers, can be added to the provisioning
template set once their provider-specific lifecycle/helper and governance facts
are ready.

## Non-goals in this package

```text
no live provisioning
no deprovisioning
no provider credentials
no cloud billing calls
no Terraform state import
no Kubernetes provider
no queue dispatch refactor
no worker execution semantic change
no job state transition change
```
