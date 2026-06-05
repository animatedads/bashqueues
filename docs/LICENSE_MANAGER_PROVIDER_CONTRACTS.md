# License Manager provider contracts

Status: fixture-first provider-family contract.

Purpose: expose normalized JSON facts about license manager availability and policy posture for governed bashqueues decisions.

Default behaviour:

- Fixture-only tests by default.
- No live credentials required.
- No live API calls in default tests.
- Provider output is JSON facts only, never shell.
- Provider facts are advisory and must not mutate external systems.

Helper:

```text
providers.d/license_manager/license_manager_provider.sh detect
providers.d/license_manager/license_manager_provider.sh entitlement explain
providers.d/license_manager/license_manager_provider.sh pool explain
providers.d/license_manager/license_manager_provider.sh usage explain
providers.d/license_manager/license_manager_provider.sh policy explain
```

Non-goals:

- license-assign
- license-revoke
- license-purchase
- entitlement-mutation
- billing-change
- provisioning
- queue-dispatch-refactor

Acceptance:

- Static contract test confirms docs, policies, helper, and non-mutating surface.
- Smoke test reads local fixtures and validates JSON syntax.
- JSON contract test confirms `live_api_used=false`, `credentials_required=false`, `mutated=false`, `provider_output_is_shell=false`, and no secret-bearing top-level keys.
