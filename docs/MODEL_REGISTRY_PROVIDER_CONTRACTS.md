# Model registry provider contracts

Bob14 owns this fixture-first service-coverage contract. It is provider-family
coverage, not Bob11 ask-provider runtime and not Bob10 provisioning.

## Purpose

The model registry provider exposes normalized JSON facts about model catalogues,
model capabilities, endpoint class, data-residency posture, cost tier, validation
status, and governance posture. These facts can support advisory, policy review,
class reasoning, and explainability.

## Helper

```bash
providers.d/model_registry/model_registry_provider.sh detect
providers.d/model_registry/model_registry_provider.sh catalog explain
providers.d/model_registry/model_registry_provider.sh model explain
providers.d/model_registry/model_registry_provider.sh governance explain
```

The default helper mode is fixture-only through
`QUEUEBASH_MODEL_REGISTRY_FIXTURE_DIR`.

## Schemas

- `queuebash.model_registry.detect.v1`
- `queuebash.model_registry.catalog.v1`
- `queuebash.model_registry.model.v1`
- `queuebash.model_registry.governance.v1`

## Boundary

This contract does not call inference APIs, manage deployments, store API keys,
choose `queue ask` providers, or change ask-provider runtime. It returns facts
only. Missing fixtures fail closed with a normalized JSON denial object.
