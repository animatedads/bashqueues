# Container registry provider contracts

Bob14 owns this fixture-first service-coverage contract. It is provider-family
coverage, not image runtime execution, not repository provisioning, and not queue
scheduler control.

## Purpose

The container registry provider exposes normalized JSON facts about images,
digests, architectures, provenance/signature posture, SBOM status, vulnerability
summary, retention posture, and replication hints.

## Helper

```bash
providers.d/container_registry/container_registry_provider.sh detect
providers.d/container_registry/container_registry_provider.sh image explain
providers.d/container_registry/container_registry_provider.sh provenance explain
providers.d/container_registry/container_registry_provider.sh vulnerability explain
providers.d/container_registry/container_registry_provider.sh retention explain
```

The default helper mode is fixture-only through
`QUEUEBASH_CONTAINER_REGISTRY_FIXTURE_DIR`.

## Schemas

- `queuebash.container_registry.detect.v1`
- `queuebash.container_registry.image.v1`
- `queuebash.container_registry.provenance.v1`
- `queuebash.container_registry.vulnerability.v1`
- `queuebash.container_registry.retention.v1`

## Boundary

This contract does not pull images, push images, delete tags, create
repositories, resolve live credentials, or alter job execution/sandbox behaviour.
Missing fixtures fail closed with a normalized JSON denial object.
