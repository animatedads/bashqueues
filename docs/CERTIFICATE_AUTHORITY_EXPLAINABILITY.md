# Certificate Authority Explainability

Explainability records must state source fixture, confidence, freshness, fail-closed behaviour, and non-goals. The provider output is normalized JSON facts and must not be treated as command text.

## Safety contract

- Fixture-first by default.
- No live API calls in default tests.
- No credentials required for default tests.
- No provisioning or destructive operations.
- No queue dispatch refactor.
- Provider output is normalized JSON facts only.

## Non-goals

- certificate-issue
- certificate-renew
- certificate-revoke
- key-export
- trust-store-mutation
- provisioning
- queue-dispatch-refactor

