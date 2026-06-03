# Remote Dependency Security Model

Remote dependency resolution must be treated as a trusted-read security boundary. A local job may become runnable only because a remote status provider produced evidence that policy allows the local queue to trust.

## Required properties

Remote dependency providers must be:

- read-only for status resolution;
- provider-neutral;
- ACL-gated;
- signature/evidence-aware;
- freshness checked;
- fail-closed;
- auditable;
- free of arbitrary shell execution.

## Forbidden default paths

The default implementation must not use:

- SSH loops;
- `curl` against unauthenticated endpoints;
- arbitrary shell commands from provider output;
- worker-side polling loops;
- live remote mutation calls;
- cloud scheduler side effects.

Providers may call a future remote queue service client only through a typed contract. They must not turn remote job identifiers into command lines.

## Fail-closed cases

The resolver must block or fail closed when:

- the service is unknown or unreachable;
- ACL status is denied or missing;
- the status response is unsigned when a signature is required;
- signature verification fails;
- the status evidence is stale;
- a remote job name is ambiguous;
- required state does not match observed state;
- the response schema is unknown or malformed.

## Evidence and audit

Resolver output must be redacted status evidence. It may include service name, job id/name, observed state, check decisions, timestamps, and audit ids. It must not include credentials, signing keys, bearer tokens, raw HTTP headers, or provider secret material.

Recommended audit event:

```json
{
  "schema": "queuebash.remote_dependency.audit.v1",
  "local_qid": "20260603_170000_local_after_remote",
  "provider": "fixture",
  "service": "oracle-prod",
  "remote_job": "nightly_export",
  "decision": "block",
  "reason": "observed_state_mismatch",
  "redacted": true
}
```

## Policy defaults

The example policy defaults are conservative:

```text
QUEUEBASH_REMOTE_DEPENDENCY_ENABLED=0
QUEUEBASH_REMOTE_DEPENDENCY_PROVIDER=fixture
QUEUEBASH_REMOTE_DEPENDENCY_REQUIRE_SIGNATURE=1
QUEUEBASH_REMOTE_DEPENDENCY_MAX_FRESHNESS_SECONDS=300
QUEUEBASH_REMOTE_DEPENDENCY_DEFAULT_FAILURE_POLICY=block
QUEUEBASH_REMOTE_DEPENDENCY_ALLOW_SSH=0
QUEUEBASH_REMOTE_DEPENDENCY_ALLOW_UNAUTHENTICATED_HTTP=0
QUEUEBASH_REMOTE_DEPENDENCY_ALLOW_WORKER_POLLING=0
```

Live provider packages must be separately authorised. This package remains fixture-first.
