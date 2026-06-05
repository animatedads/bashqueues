# Edge CDN provider contracts

Bob29 adds `edge_cdn` as a fixture-first provider family for estate discovery and policy explanation only.

## Commands

- `providers.d/edge_cdn/edge_cdn_provider.sh detect`
- `providers.d/edge_cdn/edge_cdn_provider.sh distribution explain`
- `providers.d/edge_cdn/edge_cdn_provider.sh origin explain`
- `providers.d/edge_cdn/edge_cdn_provider.sh cache explain`
- `providers.d/edge_cdn/edge_cdn_provider.sh policy explain`

## Boundary

The helper returns normalized JSON facts only. It does not call live CDN APIs by default, does not create or delete distributions, does not mutate origins, certificates, WAF rules, cache policy, invalidations, DNS/routing, or queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/edge_cdn` and are intentionally safe for offline contract tests.
