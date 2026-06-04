# Identity Provider provider contracts

Bob14 service coverage contract for `identity_provider`.

Purpose: advisory identity-provider discovery for directories, authentication methods, federation posture, and group metadata.

Default rules:

- Fixture-first by default.
- No live provider calls in tests.
- No credentials required for default tests.
- Normalized JSON facts only.
- Provider output is not shell and must not be executed.
- No provisioning, mutation, scheduling, or queue-dispatch refactor.

Helper:

```text
providers.d/identity_provider/identity_provider_provider.sh
```

Commands:

- `detect` -> `queuebash.identity_provider.detect.v1`
- `directory explain` -> `queuebash.identity_provider.directory.v1`
- `authentication explain` -> `queuebash.identity_provider.authentication.v1`
- `federation explain` -> `queuebash.identity_provider.federation.v1`
- `group explain` -> `queuebash.identity_provider.group.v1`


Non-goals:

- login
- password-check
- token-mint
- user-create
- group-update
- access-grant
- directory-sync
- queue-dispatch-refactor

Acceptance posture: this is advisory service discovery. It does not assert first-tier provider parity, live support, or compliance acceptance.
