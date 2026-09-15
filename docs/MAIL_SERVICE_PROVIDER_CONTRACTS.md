# Mail Service provider contracts

Bob29 adds `mail_service` as a fixture-first provider family for email sending platform posture, domain verification state, delivery policy, and reputation evidence without sending or reading mail.

## Commands

- `providers.d/mail_service/mail_service_provider.sh detect`
- `providers.d/mail_service/mail_service_provider.sh domain explain`
- `providers.d/mail_service/mail_service_provider.sh delivery explain`
- `providers.d/mail_service/mail_service_provider.sh reputation explain`
- `providers.d/mail_service/mail_service_provider.sh policy explain`

## Boundary

The helper returns normalized JSON facts only. It does not call live provider APIs by default, does not create, delete, send, rotate, scan live repositories, expose secret values, mutate provider policy, or change queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/mail_service` and are intentionally safe for offline contract tests.
