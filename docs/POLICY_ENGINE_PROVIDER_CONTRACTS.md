# Policy Engine provider contracts

This fixture-first provider family publishes normalized JSON facts for advisory policy catalogue, decision-shape, obligation, and audit facts for external policy engines without granting authority.

## Commands

```text
providers.d/policy_engine/policy_engine_provider.sh detect
providers.d/policy_engine/policy_engine_provider.sh policy explain
providers.d/policy_engine/policy_engine_provider.sh decision explain
providers.d/policy_engine/policy_engine_provider.sh obligation explain
providers.d/policy_engine/policy_engine_provider.sh audit explain
```

## Safety contract

- Fixture-first by default.
- No live credentials for tests.
- No provider output is shell.
- No provisioning, mutation, or queue dispatch refactor.
- JSON facts are advisory evidence only.

## Non-goals

- live-policy-decision-authority
- policy-mutation
- access-grant
- secret-read
- job-runtime-mutation
