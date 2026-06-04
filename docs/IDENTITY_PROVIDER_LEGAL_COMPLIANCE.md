# Identity Provider legal and compliance notes

The `identity_provider` provider family is fixture-first advisory metadata.

Compliance boundaries:

- No live API calls in default tests.
- No credentials, secret values, identity assertions, recipient payloads, or personal data in fixtures.
- No creation, deletion, sync, message send, access grant, or provider mutation.
- Provider-family presence is not first-tier compliance acceptance.
- Region, tenant, privacy, audit, retention, and export-control checks remain external policy concerns until a later reviewed package promotes a provider.

Tests should reject secret-like JSON keys and must keep sample records redacted.
