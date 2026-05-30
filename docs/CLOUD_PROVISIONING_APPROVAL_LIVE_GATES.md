# Cloud Provisioning Approval and Live Gate Contract

Version: 0.18.49 BOB10

This document defines the contract-only approval and live-gate layer for cloud provisioning.
It deliberately does **not** implement live provisioning. It records the checks that must
be satisfied before a later package may consider a live apply operation.

## Boundary

`cloud_provision` owns named templates, plan/validate/explain/dry-run evidence,
approval-gate decisions, and live-gate readiness checks.

`cloud_resource` owns inventory, resource records, claims, releases, heartbeat,
reconcile, provenance, and policy-consumable facts.

`cloud_infra` owns gated lifecycle helper rails such as start/stop/status planning.

Queue dispatch must not call provider lifecycle operations and must not create servers
during ordinary submit/dispatch.

## New commands

```bash
providers.d/cloud_provision/cloud_provision.sh approval-request TEMPLATE \
  --change-ticket CHG-12345 \
  --reason "approved customer migration window" \
  --authority data-owner \
  --audit-sink jsonl \
  --data-protection-review \
  --json
```

Output schema:

```text
queuebash.cloud_provision.approval_gate.v1
```

The approval gate checks:

```text
plan decision
change-ticket presence
reason presence
authority allowlist
audit sink
customer-data data-protection review
export-control review where applicable
cost approval where required
non-mutating behaviour
```

```bash
providers.d/cloud_provision/cloud_provision.sh live-gate TEMPLATE \
  --approval approval.json \
  --live-enabled \
  --json
```

Output schema:

```text
queuebash.cloud_provision.live_gate.v1
```

The live gate checks:

```text
explicit live-enabled flag
plan is not denied
approval decision is allow
template live allowlist policy, when enabled
provider credentials are not authority
queue dispatch isolation
contract-only status
```

## Contract-only live gate

In 0.18.49 the live gate is intentionally a readiness contract. Even when the
approval is valid and `--live-enabled` is supplied, the default policy contains:

```json
{
  "contract_only": true,
  "live_apply_implemented": false
}
```

Therefore the live gate returns `review` with reason:

```text
contract_only_no_live_apply_implemented
```

This is intentional. It prevents the existence of a live gate command from being
mistaken for permission or capability to mutate cloud resources.

## Security rules

Provider credentials alone are never authority. A later live package must still
require explicit live enablement, provider policy, template allowlist,
authority/change-ticket or reason, cost approval, legal/data-protection/export
review, audit evidence, and bounded provider helper semantics.

The 0.18.49 commands must always report:

```json
{
  "live": false,
  "mutated": false,
  "cloud_mutation": false
}
```
