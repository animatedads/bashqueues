# queue ask security model

`queue ask` is advisory-only. It does not approve, submit, cancel, sign, override, patch, or execute jobs.

Security controls:

- fixture-first tests by default
- live mode explicitly gated
- context bundles are policy-filtered
- sensitive context is redacted before provider handoff
- provider output is never evaluated as shell
- audit records store hashes and metadata rather than secrets
- provider limits are bounded by policy

The provider socket is intentionally separate from cloud provisioning and queue dispatch.
