# Backup Service Provider Contracts

The Backup Service provider family publishes fixture-first, provider-neutral facts. It is advisory only: advisory facts about backup repositories, schedules, policies, and recovery points without starting backup or restore operations. Default tests require no credentials and no live service access.

## Safety contract

- Fixture-first by default.
- No live API calls in default tests.
- No credentials required for default tests.
- No provisioning or destructive operations.
- No queue dispatch refactor.
- Provider output is normalized JSON facts only.

## Non-goals

- backup-start
- restore-start
- snapshot-create
- repository-delete
- policy-mutation
- provisioning
- queue-dispatch-refactor

