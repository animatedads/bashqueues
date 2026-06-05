# Service Mesh provider contracts

Status: fixture-first provider-family contract.

Purpose: expose normalized JSON facts about service mesh presence, routing posture, workload identity posture, and advisory policy gates for governed bashqueues decisions.

Default behaviour:

- Fixture-only tests by default.
- No live credentials required.
- No live API calls in default tests.
- Provider output is JSON facts only, never shell.
- Provider facts are advisory and must not mutate external systems.

Helper:

```text
  providers.d/service_mesh/service_mesh_provider.sh detect
  providers.d/service_mesh/service_mesh_provider.sh mesh explain
  providers.d/service_mesh/service_mesh_provider.sh route explain
  providers.d/service_mesh/service_mesh_provider.sh identity explain
  providers.d/service_mesh/service_mesh_provider.sh policy explain
```

Non-goals:

- mesh-create
- mesh-delete
- route-mutate
- traffic-shift
- certificate-issue
- sidecar-inject
- provisioning
- queue-dispatch-refactor

Acceptance:

- Static contract test confirms docs, policies, helper, and non-mutating surface.
- Smoke test reads local fixtures and validates JSON syntax.
- JSON contract test confirms `live_api_used=false`, `credentials_required=false`, `mutated=false`, `provider_output_is_shell=false`, and no secret-bearing top-level keys.
