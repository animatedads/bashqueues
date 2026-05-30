# Cloud resource reconcile enhancement

`0.18.50 BOB10 cloud resource reconcile enhancement` extends the file-backed
`cloud_resource` provider reconcile path. It remains a local registry operation:
it does not call provider APIs, does not require credentials, does not provision
or destroy resources, and does not participate in queue dispatch.

## Purpose

The reconcile step is the boring warehouse-ledger repair pass for cloud resource
records. It makes local registry state safer by:

- expiring leases whose `lease_until_epoch` has passed;
- importing a provider observation fixture or inventory export;
- adding or updating local resource records from that observation file;
- marking resources stale when they are absent from an observation set;
- marking active claims suspect when their resource is missing or stale;
- preserving explainable JSON evidence for automation.

## Command

```bash
providers.d/cloud_resource/cloud_resource_provider.sh reconcile \
  --registry /tmp/qb-cloud-resources \
  --observations observed-resources.json \
  --mark-missing-stale \
  --stale-after-seconds 86400 \
  --json
```

The observation file may be either a single `queuebash.cloud_resource.v1` object,
a list of resource objects, or an object with a `resources` list.

## Output contract

The command continues to emit `queuebash.cloud_resource_reconcile.v1` for
backward compatibility and adds these fields:

```json
{
  "expired_claims": [],
  "suspect_claims": [],
  "stale_resources": [],
  "observed_resources": [],
  "added_resources": [],
  "updated_resources": [],
  "missing_resources": [],
  "registry_mutation": "local_only",
  "live": false,
  "cloud_mutation": false
}
```

## Safety boundary

Reconcile is not provisioning and not scheduling. It only updates the local
file-backed cloud resource registry. Queue dispatch may later consume
`cloud_resource` availability/claim facts through assets/classes, but dispatch
must not directly call cloud provider lifecycle operations.

## Missing-resource rule

When `--mark-missing-stale` is used with an observation file, only resources
from providers represented in that observation file are marked stale. For
example, an AWS observation export must not make OCI or IBM resources stale.

Active claims on missing or stale resources are marked suspect instead of being
silently treated as healthy. This prevents ambiguous capacity from being reused
without an explicit operator or future policy decision.
