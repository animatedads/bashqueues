# Mail Service provider contracts

Bob29 adds `mail_service` as a fixture-first provider family for mail delivery/provider posture for estate discovery and policy explanation only.

## Commands

- `providers.d/mail_service/mail_service_provider.sh detect`
- `providers.d/mail_service/mail_service_provider.sh domain explain`
- `providers.d/mail_service/mail_service_provider.sh sender explain`
- `providers.d/mail_service/mail_service_provider.sh delivery explain`
- `providers.d/mail_service/mail_service_provider.sh policy explain`

## Boundary

The helper returns normalized JSON facts only. It does not send mail, read mailboxes, create/delete domains, alter MX/SPF/DKIM/DMARC records, change suppression lists, mutate identities, provision services, or queue dispatch.

## Fixtures

Fixtures live under `tests/fixtures/mail_service` and are intentionally safe for offline contract tests.
