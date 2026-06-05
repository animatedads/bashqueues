# Cache Service provider contracts

Bob29 adds `cache_service` as a fixture-first provider family for estate discovery and policy explanation only.

## Commands

- `providers.d/cache_service/cache_service_provider.sh detect`
- `providers.d/cache_service/cache_service_provider.sh cluster explain`
- `providers.d/cache_service/cache_service_provider.sh endpoint explain`
- `providers.d/cache_service/cache_service_provider.sh policy explain`
- `providers.d/cache_service/cache_service_provider.sh metrics explain`

## Boundary

The helper returns normalized JSON facts only. It does not call live cache service APIs by default, does not create/delete clusters, scale nodes, flush caches, mutate endpoints/parameters, trigger failover, or queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/cache_service` and are intentionally safe for offline contract tests.
