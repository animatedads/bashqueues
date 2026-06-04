# Access Review explainability

Status: fixture-first provider-family contract.

## Purpose

Access Review outputs are advisory evidence facts. Explain responses must show source=fixture, redacted=true where identities/evidence could identify people or regulated data, and provider_output_is_shell=false.

## Safety contract

- No live provider calls in default tests.
- No credentials required for fixture tests.
- Normalized JSON only.
- Provider output is data, never shell.
- No provisioning, destruction, mutation, approval, or queue dispatch refactor.
- Values that may identify people, secrets, regulated evidence, or operational topology must be redacted in fixtures and docs.

## Commands

```text
  providers.d/access_review/access_review_provider.sh detect
  providers.d/access_review/access_review_provider.sh scope explain
  providers.d/access_review/access_review_provider.sh entitlement explain
  providers.d/access_review/access_review_provider.sh reviewer explain
  providers.d/access_review/access_review_provider.sh exception explain
```

## Non-goals

- access-grant
- access-revoke
- review-approval
- review-closure
- identity-mutation
- queue-dispatch-refactor
