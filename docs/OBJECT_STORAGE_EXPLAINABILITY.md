# Object Storage explainability notes

The object storage provider family is explainability-first. It should report what fixture evidence was used, which check was performed, and which limits apply.

Explanations must be redacted, deterministic in fixture mode, and suitable for operator review. They must not imply operational authority to mutate object storage state.

Key explanation fields:

- `schema`
- `provider_family`
- `check`
- `decision`
- `evidence`
- `fail_closed`
- `live_api_used`
- `credentials_required`
- `mutated`
- `provider_output_is_shell`

Operators should treat these facts as input to policy gates, not as executable plans.
