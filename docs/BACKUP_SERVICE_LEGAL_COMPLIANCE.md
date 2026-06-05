# Backup Service Legal and Compliance

This provider family is not production clearance. It does not perform live operations, does not mutate regulated systems, and does not export sensitive data. Legal/compliance review is required before enabling live-read adapters.

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

