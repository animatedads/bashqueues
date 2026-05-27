# AI advisory audit logging

Every `queue ask` interaction must be auditable.

The audit trail records the advisory transaction and the context disclosure decision. It does not grant the AI authority to execute commands.

## Default paths

Single-user install:

```text
~/.queuebash/logs/ai-advisory.audit.jsonl
```

System install policy may redirect to:

```text
/var/log/queuebash/ai-advisory.audit.jsonl
journald
syslog
```

Use `QUEUEBASH_AI_AUDIT_LOG=/path/file.jsonl` to override the file target for tests or local policy.

## JSONL schema

```json
{
  "schema": "queuebash.ai_advisory.audit.v1",
  "timestamp": "2026-05-27T14:30:00Z",
  "subject": "alice",
  "operation": "ai.ask",
  "provider": "watson",
  "question_sha256": "...",
  "question_redacted": "How do I run a GDPR-safe overnight job?",
  "context_requested": "docs commands classes queue_status",
  "context_allowed": "docs commands classes",
  "context_denied": "queue_status",
  "policy_decision": "allow",
  "redactions_applied": true,
  "context_bundle_sha256": "...",
  "response_length": 0,
  "reason": "contract_only_no_live_provider_call",
  "result": "handoff"
}
```

## Logging rules

- Log subject, operation, provider, context requested, context allowed, and context denied.
- Log question hash by default.
- Log a redacted/truncated question excerpt by default.
- Do not log secrets or full sensitive outputs by default.
- Do not log full AI responses by default; log length/hash instead.
- Log denials and malformed provider output.
- Support log rotation for file mode.
- Prefer journald/syslog integration for managed system installs.

## Rotation

Package installs should provide logrotate or journald policy. Single-user installs may rotate by size in a future release.

A typical logrotate policy should rotate `/var/log/queuebash/ai-advisory.audit.jsonl`, compress old logs, and keep retention according to local compliance policy.
