# Cloud resource provider contract

Version: `queuebash.cloud_resource_provider_contract.v1`

This package defines Bob10's cloud resource booking desk. It is deliberately separate from Bob9's remote queue service work and from Bob2's lifecycle helper layer.

## Boundary

The cloud resource provider tracks inventory, claims, leases, heartbeats, reconciliation and explainable availability decisions. It does not schedule jobs, change queue state transitions, execute job payloads, or call live cloud APIs in the dispatch path.

```text
remote queue service: expose authorised queue/dev operations on a remote machine
cloud infrastructure helpers: gated start/stop/status for named cloud stacks
cloud resource provider: inventory/claim/release/heartbeat/reconcile compliant capacity
```

## Provider contract

The initial implementation is file-backed:

```text
providers.d/cloud_resource/cloud_resource_provider.sh
```

Default registry path:

```text
$QUEUEBASH_CLOUD_RESOURCE_REGISTRY
or
$QUEUEBASH_ROOT/cloud_resources
```

Registry files:

```text
resources.json  normalized resource records
claims.json     lease claims
events.jsonl    append-only redacted events
```

No cloud secret, API token, SSH private key, PAR URL, user-data script, job payload or full sensitive metadata belongs in this registry.

## JSON schemas

### `queuebash.cloud_resource.v1`

A resource record represents capacity that may be consumed by a class after policy checks.

Required or expected fields:

```json
{
  "schema": "queuebash.cloud_resource.v1",
  "resource_id": "oci-vm-001",
  "provider": "oci",
  "resource_type": "vm",
  "region": "uk-london-1",
  "zone": "AD-1",
  "lifecycle_state": "running",
  "status": "available",
  "capacity": {"cpu": 4, "memory_gb": 16},
  "labels": ["batch"],
  "compliance": ["gdpr", "uk-dpa"],
  "allowed_classes": ["CLOUD_RESOURCE_GDPR"],
  "cost": {"hourly_estimate": 0.12, "currency": "GBP"},
  "provenance": {"source": "file-provider"},
  "last_seen_epoch": 1770000000
}
```

### `queuebash.cloud_resource_claim.v1`

Claims are atomic, exclusive by default and lease-based:

```json
{
  "schema": "queuebash.cloud_resource_claim.v1",
  "claim_id": "claim-abc123",
  "resource_id": "oci-vm-001",
  "qid": "20260529_...",
  "class_name": "CLOUD_RESOURCE_GDPR",
  "exclusive": true,
  "claimed_at_epoch": 1770000000,
  "lease_until_epoch": 1770003600,
  "provenance": {"provider": "file"}
}
```

A second exclusive claim for the same unexpired resource must fail closed. Reconcile expires stale leases rather than silently reusing ambiguous resources.

### `queuebash.cloud_resource_decision.v1`

Availability and explain commands return an allow/deny decision:

```json
{
  "schema": "queuebash.cloud_resource_decision.v1",
  "decision": "allow",
  "reason": "matching_resource_available",
  "resource_id": "oci-vm-001",
  "fail_closed": false
}
```

## Commands

```bash
providers.d/cloud_resource/cloud_resource_provider.sh init --registry /tmp/qbr
providers.d/cloud_resource/cloud_resource_provider.sh add --file resource.json --registry /tmp/qbr
providers.d/cloud_resource/cloud_resource_provider.sh list --json --registry /tmp/qbr
providers.d/cloud_resource/cloud_resource_provider.sh check-matching --provider oci --resource-type vm --region uk-london-1 --compliance gdpr --min-cpu 4 --min-mem-gb 16 --json --registry /tmp/qbr
providers.d/cloud_resource/cloud_resource_provider.sh claim-matching --qid QID --class CLOUD_RESOURCE_GDPR --provider oci --resource-type vm --compliance gdpr --lease-seconds 600 --json --registry /tmp/qbr
providers.d/cloud_resource/cloud_resource_provider.sh heartbeat CLAIM_ID --lease-seconds 600 --json --registry /tmp/qbr
providers.d/cloud_resource/cloud_resource_provider.sh release CLAIM_ID --json --registry /tmp/qbr
providers.d/cloud_resource/cloud_resource_provider.sh reconcile --json --registry /tmp/qbr
```

## Asset/class integration

The `cloud_resource` asset is read-only in preflight. It checks availability, not claims:

```bash
queue_class_shared_asset cloud_resource available oci \
  type=vm \
  region=uk-london-1 \
  compliance=gdpr \
  class=CLOUD_RESOURCE_GDPR \
  min_cpu=4 \
  min_mem_gb=16
```

Claiming should be explicit provider work around dispatch orchestration, not a hidden side effect of asset metadata listing.

## Platform parity

The package includes `docs/CLOUD_PLATFORM_PARITY.md` and `policies.d/cloud-resource/platform-parity.json`. Tests intentionally fail if future docs claim equal platform coverage while the matrix still marks AWS/Azure/GCP gaps.
