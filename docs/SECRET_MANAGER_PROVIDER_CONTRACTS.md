# Secret Manager provider contracts

## Scope

The `secret_manager` provider family supplies fixture-first advisory facts for bashqueues service-coverage planning. It does not read or disclose secret values, does not perform live service calls by default, does not provision resources, and does not alter queue scheduling or execution.

## Commands

`providers.d/secret_manager/secret_manager_provider.sh detect` returns service-family detection metadata.

`providers.d/secret_manager/secret_manager_provider.sh secret explain` returns `queuebash.secret_manager.secret.v1`.
`providers.d/secret_manager/secret_manager_provider.sh rotation explain` returns `queuebash.secret_manager.rotation.v1`.
`providers.d/secret_manager/secret_manager_provider.sh access-policy explain` returns `queuebash.secret_manager.access_policy.v1`.
`providers.d/secret_manager/secret_manager_provider.sh audit explain` returns `queuebash.secret_manager.audit.v1`.

## Safety contract

- fixture-first by default
- normalized JSON only
- no secrets or protected values in docs, fixtures, examples, or scratchpad
- no live API calls in default tests
- no provisioning, deletion, mutation, runtime injection, or job execution
- provider output is evidence/facts only, never shell

## Non-goals

- secret-read
- secret-write
- secret-delete
- credential-broker
- runtime-injection
- job-runtime-mutation
