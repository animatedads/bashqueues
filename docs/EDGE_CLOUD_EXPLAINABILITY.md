# Edge cloud explainability

Human explain output should include:

```text
Provider family: edge_cloud
Provider: Cloudflare / Fastly / Fly.io
Check: identity / region / edge-runtime / storage / network / finops / legal
Decision: allow / deny / unknown / available
Source: fixture / config / provider-cache
Fail-closed: true / false
Reason:
Remediation hint:
```

JSON explain records use `queuebash.edge_cloud.<provider>.<check>.v1` today. Future command wrappers may map those into a shared `queuebash.edge_cloud.explain.v1` envelope.

Secrets, API tokens, TLS keys, signed URLs, and raw deployment environment variables must not be logged.
