# queue ask audit logging

Every ask operation should emit safe audit metadata. Full secrets and raw credentials are not logged.

```json
{
  "schema": "queuebash.ask_audit.v1",
  "operation": "ai.ask",
  "provider": "fixture",
  "live": false,
  "question_hash": "sha256:example",
  "context_bundle_ids": ["manual:queue-submit"],
  "policy_decision": "allowed",
  "status": "ok",
  "redactions": {
    "secrets_removed": 0
  }
}
```
