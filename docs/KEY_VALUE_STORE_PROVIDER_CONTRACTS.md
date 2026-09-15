# Key Value Store provider contracts

Bob29 adds `key_value_store` as a fixture-first provider family for estate discovery and policy explanation only.

## Commands

- `providers.d/key_value_store/key_value_store_provider.sh detect`
- `providers.d/key_value_store/key_value_store_provider.sh table explain`
- `providers.d/key_value_store/key_value_store_provider.sh capacity explain`
- `providers.d/key_value_store/key_value_store_provider.sh policy explain`
- `providers.d/key_value_store/key_value_store_provider.sh backup explain`

## Boundary

The helper returns normalized JSON facts only. It does not call live key value store APIs by default, does not perform mutations (table-create, table-delete, item-put, item-delete, capacity-mutation, backup-restore, stream-enable, queue-dispatch-refactor), and does not change queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/key_value_store` and are intentionally safe for offline contract tests.
