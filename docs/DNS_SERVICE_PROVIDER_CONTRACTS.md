# DNS Service provider contracts

Bob29 adds `dns_service` as a fixture-first provider family for estate discovery and policy explanation only.

## Commands

- `providers.d/dns_service/dns_service_provider.sh detect`
- `providers.d/dns_service/dns_service_provider.sh zone explain`
- `providers.d/dns_service/dns_service_provider.sh record explain`
- `providers.d/dns_service/dns_service_provider.sh resolver explain`
- `providers.d/dns_service/dns_service_provider.sh policy explain`

## Boundary

The helper returns normalized JSON facts only. It does not call live dns service APIs by default, does not create/delete zones, add/remove records, change delegation, alter resolver rules, mutate DNSSEC keys, shift traffic, or queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/dns_service` and are intentionally safe for offline contract tests.
