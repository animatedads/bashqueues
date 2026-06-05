# Configuration Database provider contracts

Status: fixture-first provider-family contract.

Purpose: expose normalized JSON facts about configuration database availability and policy posture for governed bashqueues decisions.

Default behaviour:

- Fixture-only tests by default.
- No live credentials required.
- No live API calls in default tests.
- Provider output is JSON facts only, never shell.
- Provider facts are advisory and must not mutate external systems.

Helper:

```text
providers.d/configuration_database/configuration_database_provider.sh detect
providers.d/configuration_database/configuration_database_provider.sh ci explain
providers.d/configuration_database/configuration_database_provider.sh relationship explain
providers.d/configuration_database/configuration_database_provider.sh change_window explain
providers.d/configuration_database/configuration_database_provider.sh policy explain
```

Non-goals:

- ci-create
- ci-update
- ci-delete
- relationship-mutation
- change-window-mutation
- cmdb-write
- provisioning
- queue-dispatch-refactor

Acceptance:

- Static contract test confirms docs, policies, helper, and non-mutating surface.
- Smoke test reads local fixtures and validates JSON syntax.
- JSON contract test confirms `live_api_used=false`, `credentials_required=false`, `mutated=false`, `provider_output_is_shell=false`, and no secret-bearing top-level keys.
