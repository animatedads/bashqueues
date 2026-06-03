# Feature Store provider contracts

## Scope

The `feature_store` provider family supplies fixture-first advisory facts for bashqueues service-coverage planning. It does not materialize online or offline feature values, does not perform live service calls by default, does not provision resources, and does not alter queue scheduling or execution.

## Commands

`providers.d/feature_store/feature_store_provider.sh detect` returns service-family detection metadata.

`providers.d/feature_store/feature_store_provider.sh entity explain` returns `queuebash.feature_store.entity.v1`.
`providers.d/feature_store/feature_store_provider.sh feature-view explain` returns `queuebash.feature_store.feature_view.v1`.
`providers.d/feature_store/feature_store_provider.sh training-set explain` returns `queuebash.feature_store.training_set.v1`.
`providers.d/feature_store/feature_store_provider.sh lineage explain` returns `queuebash.feature_store.lineage.v1`.

## Safety contract

- fixture-first by default
- normalized JSON only
- no secrets or protected values in docs, fixtures, examples, or scratchpad
- no live API calls in default tests
- no provisioning, deletion, mutation, runtime injection, or job execution
- provider output is evidence/facts only, never shell

## Non-goals

- online-feature-read
- offline-training-export
- feature-materialization
- feature-delete
- job-runtime-mutation
