# Secrets Scanner provider contracts

Bob29 adds `secrets_scanner` as a fixture-first provider family for secrets-scanner/provider posture for fixture-only evidence mapping only.

## Commands

- `providers.d/secrets_scanner/secrets_scanner_provider.sh detect`
- `providers.d/secrets_scanner/secrets_scanner_provider.sh rule explain`
- `providers.d/secrets_scanner/secrets_scanner_provider.sh finding explain`
- `providers.d/secrets_scanner/secrets_scanner_provider.sh scope explain`
- `providers.d/secrets_scanner/secrets_scanner_provider.sh policy explain`

## Boundary

The helper returns normalized JSON facts only. It does not scan live repositories, reveal secret values, redact files, rotate/revoke credentials, write findings, mutate policies, provision services, or queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/secrets_scanner` and are intentionally safe for offline contract tests.
