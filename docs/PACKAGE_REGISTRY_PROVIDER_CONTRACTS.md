# Package Registry provider contracts

Bob29 adds `package_registry` as a fixture-first provider family for estate discovery and policy explanation only.

## Commands

- `providers.d/package_registry/package_registry_provider.sh detect`
- `providers.d/package_registry/package_registry_provider.sh repository explain`
- `providers.d/package_registry/package_registry_provider.sh package explain`
- `providers.d/package_registry/package_registry_provider.sh provenance explain`
- `providers.d/package_registry/package_registry_provider.sh policy explain`

## Boundary

The helper returns normalized JSON facts only. It does not call live provider APIs by default, does not create or delete resources, does not change routing, repositories, authentication, retention, policy, deployments, signatures, secrets, or queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/package_registry` and are intentionally safe for offline contract tests.
