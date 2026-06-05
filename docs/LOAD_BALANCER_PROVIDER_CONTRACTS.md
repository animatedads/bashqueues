# Load Balancer provider contracts

Bob29 adds `load_balancer` as a fixture-first provider family for estate discovery and policy explanation only.

## Commands

- `providers.d/load_balancer/load_balancer_provider.sh detect`
- `providers.d/load_balancer/load_balancer_provider.sh balancer explain`
- `providers.d/load_balancer/load_balancer_provider.sh listener explain`
- `providers.d/load_balancer/load_balancer_provider.sh target explain`
- `providers.d/load_balancer/load_balancer_provider.sh health explain`

## Boundary

The helper returns normalized JSON facts only. It does not call live load-balancer APIs by default, does not create or delete balancers/listeners, register targets, shift traffic, mutate health checks, certificates, firewall rules, or queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/load_balancer` and are intentionally safe for offline contract tests.
