# API Gateway provider contracts

Bob29 adds `api_gateway` as a fixture-first provider family for estate discovery and policy explanation only.

## Commands

- `providers.d/api_gateway/api_gateway_provider.sh detect`
- `providers.d/api_gateway/api_gateway_provider.sh gateway explain`
- `providers.d/api_gateway/api_gateway_provider.sh route explain`
- `providers.d/api_gateway/api_gateway_provider.sh auth explain`
- `providers.d/api_gateway/api_gateway_provider.sh policy explain`

## Boundary

The helper returns normalized JSON facts only. It does not call live provider APIs by default, does not create or delete resources, does not change routing, repositories, authentication, retention, policy, deployments, signatures, secrets, or queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/api_gateway` and are intentionally safe for offline contract tests.
