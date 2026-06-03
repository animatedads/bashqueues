# Remote Job Dependencies

Remote job dependencies are a contract-first extension point for jobs that must wait for a trusted status result from another bashqueues service before they become runnable.

The first package is deliberately narrow. It defines the dependency token, fixture resolver, policy examples, schemas, and validation tests. It does not turn bashqueues into a DAG orchestrator, does not add live remote mutation, and does not add worker-side polling.

## User-facing shape

```bash
queue submit local_after_remote \
  --depends-remote service=oracle-prod job=nightly_export state=done \
  --remote-fail-policy block \
  -- bash ./import_result.sh
```

A future submit parser may store this as a structured dependency record, but the contract record is already defined as JSON:

```json
{
  "schema": "queuebash.remote_dependency.request.v1",
  "local_qid": "20260603_170000_local_after_remote",
  "remote": {
    "service": "oracle-prod",
    "job": "nightly_export",
    "required_state": "done"
  },
  "policy": {
    "freshness_seconds": 300,
    "timeout_seconds": 3600,
    "failure_policy": "block"
  }
}
```

## Pre-dispatch gate

A remote dependency is a pre-dispatch gate. The local job remains waiting until the resolver returns a satisfied result. The worker must not run a shell loop that polls a remote host.

Before the local job becomes runnable, the resolver must establish:

- the configured remote service is reachable through the remote queue service/provider contract;
- the remote service identity is trusted;
- the local client is ACL-authorised to read status for the remote job;
- the remote job id or exact job name resolves unambiguously;
- the observed remote state matches the required state;
- the remote status evidence is fresh enough;
- signature/evidence checks pass.

Unknown, stale, ambiguous, denied, unsigned, unreachable, or malformed status must fail closed.

## States

The preferred local state is `waiting_remote`. If an older queue state is reused, the structured reason must still carry the remote dependency schema.

Resolver output uses `queuebash.remote_dependency.v1`:

```json
{
  "schema": "queuebash.remote_dependency.v1",
  "status": "waiting",
  "decision": "block",
  "remote": {
    "service": "oracle-prod",
    "job": "nightly_export",
    "required_state": "done",
    "observed_state": "running",
    "last_checked": "2026-06-04T23:05:00Z"
  },
  "checks": {
    "acl": "allow",
    "signature": "valid",
    "freshness": "fresh",
    "ambiguity": "unique"
  },
  "policy": {
    "failure_policy": "block",
    "freshness_seconds": 300,
    "timeout_seconds": 3600
  },
  "next_action": "retry_later"
}
```

## Queue explain contract

`queue explain` for a waiting local job should show:

- remote dependency status;
- remote service/client;
- remote job identifier;
- required and observed state;
- last check time and freshness result;
- ACL decision;
- signature/evidence decision;
- ambiguity result;
- retry/timeout/failure policy;
- whether the dependency is blocking or satisfied.

JSON output must include the `queuebash.remote_dependency.v1` evidence record rather than parsing human display text.

## Non-goals

This package does not implement:

- DAG scheduling;
- remote shell execution;
- SSH polling;
- unauthenticated HTTP polling;
- live remote mutation;
- cloud scheduling or cloud provisioning.

The default provider helper is fixture-only and read-only.
