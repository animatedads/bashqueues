# Notification Service explainability notes

The `notification_service` provider family explains what fixture evidence exists and how a caller should interpret it.

Explainability requirements:

- JSON must include schema, provider_family, provider, check, decision, reason, evidence, fail_closed, mutated, and provider_output_is_shell.
- Evidence must state that live API calls and credential use are false for default fixtures.
- Any identity, recipient, membership, template, or endpoint detail that could identify a person, tenant, account, or confidential route must be redacted or replaced by policy metadata.
- A positive fixture decision means evidence was available, not that a live provider operation is safe or authorized.

The helper must never return executable commands, shell snippets, or provider-supplied runtime instructions.
