# queue ask context bundles

Context bundles are normalized inputs for provider helpers. They should be small, policy-filtered, redacted, and traceable.

```json
{
  "schema": "queuebash.ask_context_bundle.v1",
  "question_sha256": "example",
  "context": [
    {
      "id": "manual:queue-submit",
      "kind": "manual",
      "redacted": true,
      "text": "queue submit usage"
    }
  ]
}
```

Allowed contexts are reported separately from denied contexts. Job payloads and stdout/stderr require explicit gated contexts and must not be included by default.
