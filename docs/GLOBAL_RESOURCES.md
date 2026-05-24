# Global shared resource slots

`bashqueues 0.17.x` adds explicit cross-user global resource claims.

Per-user queue roots still own their job records:

```text
/home/hc3/.queuebash
/home/testu/.queuebash
/root/.queuebash
```

Global claims live in a separate root/admin coordination area:

```text
/var/lib/bashqueues/global
```

Override it with:

```bash
export QUEUEBASH_GLOBAL_ROOT=/some/path
```

## Policy

Global claims are opt-in. Existing class records remain per-queue-root only.

```bash
queue_class_shared_asset ...
queue_class_exclusive_asset ...
queue_class_exclusive_claim ...
```

To coordinate across user queues, use explicit global records:

```bash
queue_class_global_exclusive_claim "github:publish"
queue_class_global_shared_claim "gpu:cuda" slots=2

queue_class_global_exclusive_asset net allowance "wwan0" allowance_bytes=10G

queue_class_global_shared_asset net allowance "wwan0" \
  slots=1 \
  allowance_bytes=10G \
  direction=rx_tx
```

## Claim storage

The global root contains:

```text
claims/        claim env records
slots/         future slot metadata
.lock/         flock lock files
events.jsonl   global audit events
```

Claim files are keyed by `sha256(claim-key)`, but the raw claim key is stored inside the env file for audit and explain output.

## Commands

```bash
queue global root
queue global claims
queue global claim CLAIM
queue global cleanup --dryrun
queue global cleanup
queue global release CLAIM QID --force
queue global health
```

## Manager panel

The QueueManager has a `Global Resources` panel. It lists active global claims, slot usage, and holders. Use typed commands from F2:

```text
global claims
global claim github:publish
global cleanup --dryrun
global health
```

## Exceptions

Exception overlays can bypass a global claim only when explicit:

```bash
queue exception add QID global:claim:github:publish "Emergency override"
```

or, more broadly:

```bash
queue exception add QID global:claim "Administrative window"
```

These should be rare; they are mainly for false-positive stale claims or controlled administrative windows.

## Security model

Phase 1 is intended for root/operator coordination. The global root should normally be root/admin owned.

User queue records remain user-owned. Global claim state is data-only and must not require sourcing user-owned code as root.
