# Secrets Scanner provider contracts

Bob29 adds `secrets_scanner` as a fixture-first provider family for scanner coverage, signal classification, source scope, and redaction posture without scanning live repositories or exposing secret values.

## Commands

- `providers.d/secrets_scanner/secrets_scanner_provider.sh detect`
- `providers.d/secrets_scanner/secrets_scanner_provider.sh source explain`
- `providers.d/secrets_scanner/secrets_scanner_provider.sh signal explain`
- `providers.d/secrets_scanner/secrets_scanner_provider.sh redaction explain`
- `providers.d/secrets_scanner/secrets_scanner_provider.sh policy explain`

## Boundary

The helper returns normalized JSON facts only. It does not call live provider APIs by default, does not create, delete, send, rotate, scan live repositories, expose secret values, mutate provider policy, or change queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/secrets_scanner` and are intentionally safe for offline contract tests.
