# Search Service provider contracts

Bob29 adds `search_service` as a fixture-first provider family for estate discovery and policy explanation only.

## Commands

- `providers.d/search_service/search_service_provider.sh detect`
- `providers.d/search_service/search_service_provider.sh domain explain`
- `providers.d/search_service/search_service_provider.sh index explain`
- `providers.d/search_service/search_service_provider.sh policy explain`
- `providers.d/search_service/search_service_provider.sh query explain`

## Boundary

The helper returns normalized JSON facts only. It does not call live search service APIs by default, does not perform mutations (domain-create, domain-delete, index-create, index-delete, document-index, document-delete, query-execute, snapshot-restore, queue-dispatch-refactor), and does not change queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/search_service` and are intentionally safe for offline contract tests.
