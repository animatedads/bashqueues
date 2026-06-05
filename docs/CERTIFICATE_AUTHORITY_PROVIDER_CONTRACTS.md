# Certificate Authority Provider Contracts

The Certificate Authority provider family publishes fixture-first, provider-neutral facts. It is advisory only: advisory facts about certificate issuers, policy, inventory, and revocation status without issuing, renewing, or revoking certificates. Default tests require no credentials and no live service access.

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

