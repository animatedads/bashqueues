# Remote queue service provider contract

`0.18.28` defines a provider-neutral contract for exposing selected `queue` and `queue dev` operations on a remote machine through an authenticated, policy-gated service boundary. It builds on the accepted `0.18.27` remote dev runner bridge, but it is deliberately broader in design and narrower in authority: this document is a contract for a future governed service provider, not a live remote execution implementation.

The remote queue service provider is not a shell. It must expose named capabilities only. Authentication proves who is calling; policy decides which named operation they may invoke; queuebash executes only the approved operation through existing queue/dev mechanisms; audit records what was requested, what policy decided, what ran, and where bounded evidence can be found.

## Scope

The provider contract may cover these operation families:

- session lifecycle: create, renew when explicitly allowed, inspect, close, expire;
- queue submission and inspection: submit approved queue jobs, list/status/explain/tail selected jobs, retrieve bounded result metadata;
- development operations: `queue dev extract`, `queue dev symbols`, `queue dev flow`, `queue dev patch`, `queue dev splice`, and `queue dev test` when the caller is authorised for development scope;
- file transfer: upload/download artifacts inside a session workspace only;
- scoped process control: list or terminate only processes created by that provider session;
- audit and evidence retrieval: return bounded JSON and log tails, never unbounded raw logs.

The provider contract must not cover:

- arbitrary shell execution;
- generic `/run`, `/exec`, `/shell`, `/command`, or `/cmd` endpoints;
- host-wide `ps` or `kill`;
- kill-by-name;
- unrestricted filesystem read/write;
- implicit use of API keys, OCI config, SSH private keys, or tokens from the client payload;
- accepting remote provider output as shell.

## Canonical paths

A future implementation should use explicit provider configuration and state paths:

```text
/etc/queuebash/policy/providers.d/remote-queue.env
/usr/libexec/queuebash/providers/remote-queue/
/var/lib/queuebash/remote-queue/sessions/
/var/log/queuebash/remote-queue-audit.jsonl
```

The 0.18.27 development runner may still use a temporary `work_root` for short-lived dev sessions. A production remote queue service provider should use a configured state root with cleanup, expiry, quotas, and audit retention.

## Required trust chain

Every request must pass this chain:

```text
transport/authentication
  -> session lookup and expiry check
  -> identity and capability mapping
  -> policy gate for the requested named operation
  -> workspace/path scope check
  -> bounded execution through queue or queue dev primitives
  -> bounded result/log/evidence response
  -> audit event
```

Failure at any step is fail-closed. A missing provider, missing policy answer, malformed provider output, expired session, unknown operation, unsafe path, unknown process, or unparseable JSON result must deny the operation.

## Normalized JSON schema

Provider responses and audit-adjacent decisions should use `queuebash.remote_queue_service.v1`.

```json
{
  "schema": "queuebash.remote_queue_service.v1",
  "provider": "remote-queue",
  "operation": "queue.submit",
  "decision": "allow",
  "subject": "alice@example.invalid",
  "session_id": "BQSID_example",
  "capability": "queue.submit",
  "queue_command": ["queue", "submit", "nightly-report", "--", "./report.sh"],
  "workspace": "BQSID_example",
  "ttl_seconds": 1800,
  "audit_event_id": "RQ-20260529-example-0001"
}
```

A denial must be explicit and must not include secrets:

```json
{
  "schema": "queuebash.remote_queue_service.v1",
  "provider": "remote-queue",
  "operation": "dev.patch",
  "decision": "deny",
  "subject": "alice@example.invalid",
  "session_id": "BQSID_example",
  "reason_code": "capability_not_granted",
  "safe_message": "subject is not authorised for dev.patch on this target",
  "audit_event_id": "RQ-20260529-example-0002"
}
```

A bounded execution result must be structured:

```json
{
  "schema": "queuebash.remote_queue_service.v1",
  "provider": "remote-queue",
  "operation": "dev.test",
  "decision": "allow",
  "status": "ok",
  "exit_code": 0,
  "duration_ms": 7421,
  "stdout_tail": "PASS dev_remote_runner_static\n",
  "stderr_tail": "",
  "artifacts": [
    {
      "name": "dev-test-result.json",
      "kind": "json",
      "workspace_path": "artifacts/dev-test-result.json",
      "sha256": "example-not-a-real-hash"
    }
  ],
  "audit_event_id": "RQ-20260529-example-0003"
}
```


An audit retrieval response is bounded and references stored evidence rather than dumping full logs:

```json
{
  "schema": "queuebash.remote_queue_service.v1",
  "provider": "remote-queue",
  "operation": "audit.fetch",
  "decision": "allow",
  "status": "ok",
  "session_id": "BQSID_example",
  "events": [
    {
      "audit_event_id": "RQ-20260529-example-0003",
      "operation": "dev.test",
      "decision": "allow",
      "artifact_ref": "audit/RQ-20260529-example-0003.json"
    }
  ],
  "stdout_tail": "",
  "stderr_tail": ""
}
```

## Operation allowlist

A service implementation must maintain an explicit operation registry. The registry must distinguish queue operations from development operations and must provide a stable operation name for policy and audit.

Suggested v1 registry:

```text
healthz
session.create
session.close
workspace.upload
workspace.download
queue.submit
queue.status
queue.explain
queue.tail
queue.cancel
dev.extract
dev.symbols
dev.flow
dev.patch
dev.splice
dev.test
process.ps
process.kill
audit.fetch
```

Unknown operations must return `not_found` or `operation_not_allowed`. They must not be routed to a shell fallback.

## Policy gate contract

A provider implementation may resolve policy itself or call an external policy helper. The normalized policy helper contract is:

```text
queue-remote-policy-check --json
```

Input:

```json
{
  "schema": "queuebash.remote_queue_policy_request.v1",
  "subject": "alice@example.invalid",
  "session_id": "BQSID_example",
  "operation": "dev.patch",
  "target": "queuebash.sh",
  "workspace": "BQSID_example",
  "requested_args": ["--file", "queuebash.sh", "--function", "_queue_example"],
  "client_addr": "127.0.0.1"
}
```

Output:

```json
{
  "schema": "queuebash.remote_queue_policy_response.v1",
  "provider": "remote-queue",
  "decision": "allow",
  "operation": "dev.patch",
  "subject": "alice@example.invalid",
  "max_runtime_seconds": 120,
  "max_stdout_bytes": 65536,
  "max_stderr_bytes": 65536,
  "allowed_targets": ["queuebash.sh", "tests/"],
  "audit_class": "remote-dev"
}
```

Policy output is data. No returned value is evaluated as shell.

## Session and token rules

The service must use a short-lived session model. The accepted 0.18.27 console bootstrap pattern is one valid model for development sessions: the server operator presses Enter to mint a one-use bootstrap code, `POST /session/create` consumes it, and the client receives a `session_id` and `auth_code`.

A future production provider may integrate with SSH certificates, mTLS, SSO, Kerberos, LDAP, PAM, Active Directory, OCI identity, or another trust provider. Regardless of the source of identity, the service must still create a bounded session context and must not allow the client to self-mint authority.

Tokens must never be written to scratchpad, package zips, repository files, or normal logs. Visible-console logs should identify sessions and operations but redact or omit auth codes.

## Workspace and file rules

All file operations must resolve through a safe workspace join. Required protections:

- reject `..` traversal;
- reject absolute paths unless the operation explicitly supports a configured read-only source root;
- reject symlink escape;
- enforce upload size limits;
- enforce artifact download size limits;
- keep generated patches, logs, and result files inside the session workspace;
- close or expire sessions with cleanup or archival according to policy.

## Process control rules

`process.ps` and `process.kill` are allowed only as scoped service operations. The provider must maintain a session process registry.

`process.ps` may show only processes started for the authenticated session.

`process.kill` may terminate only process IDs or process groups proven to belong to the authenticated session registry. It must reject PID 1, host/global PIDs, process names, and any process not created by the current session.

## Audit contract

Every non-health request should produce an audit event with at least:

```text
schema
provider
operation
subject/session id
client address
policy decision
workspace
bounded command vector or operation args hash
start/end timestamps
exit status or rejection reason
audit event id
artifact ids or bounded log paths
```

Audit events must not contain secrets, full auth tokens, private keys, OCI config, API keys, or unbounded stdout/stderr.

## Relationship to 0.18.27

`0.18.27` is a temporary authenticated remote dev runner bridge. It is accepted as a development tool.

`0.18.28` is a contract package for a future remote queue service provider. It does not widen the 0.18.27 runner, does not add a generic shell, does not add new live remote provider execution, and does not change queue runtime behaviour. It documents the security boundary and acceptance criteria for the provider layer that can later wrap the runner model.

