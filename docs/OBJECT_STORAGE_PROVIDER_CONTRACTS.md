# Object Storage provider contracts

Status: fixture-first provider-family contract.

Purpose: expose normalized JSON facts about object storage availability, bucket posture, object metadata posture, retention posture, and advisory policy gates for governed bashqueues decisions.

Default behaviour:

- Fixture-only tests by default.
- No live credentials required.
- No live API calls in default tests.
- Provider output is JSON facts only, never shell.
- Provider facts are advisory and must not mutate external systems.

Helper:

```text
  providers.d/object_storage/object_storage_provider.sh detect
  providers.d/object_storage/object_storage_provider.sh bucket explain
  providers.d/object_storage/object_storage_provider.sh object explain
  providers.d/object_storage/object_storage_provider.sh retention explain
  providers.d/object_storage/object_storage_provider.sh policy explain
```

Non-goals:

- bucket-create
- bucket-delete
- object-upload
- object-download
- object-delete
- retention-mutation
- acl-mutation
- provisioning
- queue-dispatch-refactor

Acceptance:

- Static contract test confirms docs, policies, helper, and non-mutating surface.
- Smoke test reads local fixtures and validates JSON syntax.
- JSON contract test confirms `live_api_used=false`, `credentials_required=false`, `mutated=false`, `provider_output_is_shell=false`, and no secret-bearing top-level keys.
