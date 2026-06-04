# Notification Service provider contracts

Bob14 service coverage contract for `notification_service`.

Purpose: advisory notification-service discovery for channels, routes, templates, and delivery policy metadata.

Default rules:

- Fixture-first by default.
- No live provider calls in tests.
- No credentials required for default tests.
- Normalized JSON facts only.
- Provider output is not shell and must not be executed.
- No provisioning, mutation, scheduling, or queue-dispatch refactor.

Helper:

```text
providers.d/notification_service/notification_service_provider.sh
```

Commands:

- `detect` -> `queuebash.notification_service.detect.v1`
- `channel explain` -> `queuebash.notification_service.channel.v1`
- `route explain` -> `queuebash.notification_service.route.v1`
- `template explain` -> `queuebash.notification_service.template.v1`
- `delivery explain` -> `queuebash.notification_service.delivery.v1`


Non-goals:

- send-message
- publish
- subscribe
- webhook-create
- topic-create
- template-update
- recipient-export
- queue-dispatch-refactor

Acceptance posture: this is advisory service discovery. It does not assert first-tier provider parity, live support, or compliance acceptance.
