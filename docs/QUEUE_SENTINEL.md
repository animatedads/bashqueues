# Queue sentinel / scheduler

`queue sentinel` is the cheap daemon-mode control thread for bashqueues. It is intentionally separate from payload workers.

The sentinel does **not** launch payloads and does **not** run normal asset preflight. It only performs inexpensive control-plane work that should continue even when all payload workers are busy.

## Commands

```bash
queue sentinel --once
queue sentinel --interval 30
queue sentinel --interval 30 --detach
queue scheduler --interval 30 --detach
queue supervisor --interval 30 --detach
```

Aliases: `sentinel`, `scheduler`, `supervisor`, `supervise`.

## Responsibilities

The sentinel currently performs these cheap checks:

- removes dead detached-worker PID files;
- marks definitely stale `running` jobs as `interrupted`;
- applies the shared/admin class-statement policy gate to pending jobs;
- moves policy-contrary jobs to `pol_blocked` without claims, preflight, or payload launch;
- evaluates only `deadline:monitor` and `deadline:panic` control-plane assets for jobs that are schedule-due and dependency-ready.

## Non-responsibilities

The sentinel must not become a second worker. It must not run payload commands, expensive assets, network checks, filesystem probes, or anything with heavyweight side effects unless a future asset explicitly declares itself safe for sentinel evaluation.

Normal asset preflight still belongs to workers. Runtime caps still belong to workers and the launched process tree.

## Why it exists

Deadline escalation is ineffective if it is only evaluated when a worker becomes free. The sentinel allows deterministic deadline monitoring to boost priority or start a bounded extra worker while existing workers are still busy.

This makes the overall model:

```text
sentinel/scheduler:
  cheap control-plane checks
  policy block
  stale-worker cleanup
  stale-running repair
  deadline priority escalation
  bounded extra-worker start

worker:
  claims runnable jobs
  runs full preflight
  launches payloads
  enforces runtime caps
```
