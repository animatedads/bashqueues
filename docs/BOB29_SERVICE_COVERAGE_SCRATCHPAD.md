# Bob29 service coverage scratchpad

Base inspected: 0.18.117 BOB27 plan ingestion DGX lifecycle JSON merge.

Verification notes:

- `license_manager` was already present in providers, fixtures, docs, policies, tests, and service-coverage registry.
- `configuration_database` was already present in providers, fixtures, docs, policies, tests, and service-coverage registry.
- No Bob14 wave12 rebase was required.

Bob29 additions:

- `service_mesh`: fixture-first normalized JSON facts for detect, mesh, route, identity, and policy checks.
- `object_storage`: fixture-first normalized JSON facts for detect, bucket, object metadata, retention, and policy checks.

Boundary preserved:

- No live calls in default tests.
- No credentials required.
- No provisioning/resource lifecycle.
- No routing, certificate, bucket, object, retention, ACL, or queue-dispatch mutation.
- Provider helpers return JSON facts only, never shell commands.

Focused validation run:

- `bash -n providers.d/service_mesh/service_mesh_provider.sh`
- `bash -n providers.d/object_storage/object_storage_provider.sh`
- `bash tests/service_mesh_provider_contracts_static.sh`
- `bash tests/service_mesh_provider_fixture_smoke.sh`
- `python3 tests/service_mesh_provider_json_contract_static.py`
- `bash tests/object_storage_provider_contracts_static.sh`
- `bash tests/object_storage_provider_fixture_smoke.sh`
- `python3 tests/object_storage_provider_json_contract_static.py`
- Existing wave12 spot checks also passed for `license_manager` and `configuration_database` static/smoke/JSON tests.

Queue dev AI notes:

- Session started with explicit Bob29/service coverage metadata.
- Some direct non-shell test entrypoints were rejected by the 0.18.117 queue-dev-ai allowlist; the tests were then run directly as focused bounded tests and the allowlist lesson was recorded.
