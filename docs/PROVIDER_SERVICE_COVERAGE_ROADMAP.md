# Provider service-coverage roadmap

This is Bob14's fixture-first service-coverage roadmap. It is not a live API,
not a provisioning layer, and not a queue scheduling rewrite.

## Scope

Service-coverage providers should expose normalized JSON facts that queuebash can
use for advisory, explainability, policy, class, and asset reasoning. They must
not return shell commands, mutate cloud resources by default, require live
credentials in tests, or bypass Bob10/Bob11/Bob13 lane ownership.

## Priority order

1. Model registry discovery — implemented as fixture-first Bob14 contract in 0.18.89
2. Container registry discovery — implemented as fixture-first Bob14 contract in 0.18.89
3. Vector database discovery
4. Data lake / object analytics discovery
5. GPU marketplace discovery
6. Distributed framework discovery

## Candidate contract shape

Each candidate provider family should include:

- `schema` string and normalized JSON output
- fixture files under `tests/fixtures/<service-family>/`
- provider helper under `providers.d/<service-family>/`
- policy examples under `policies.d/<service-family>/`
- docs explaining facts, evidence, validation status, fail-closed behaviour, and remediation hints
- static test, fixture smoke test, JSON contract test, and explainability test where relevant
- explicit no-live/no-credential/no-provisioning default posture
- no queue dispatcher or scheduler refactor

## Model registry candidate

Purpose: expose model catalogue facts such as provider, model identifier,
capabilities, locality hints, data-residency posture, cost tier, endpoint class,
context window facts, and validation status.

Non-goals: calling AI inference APIs, managing model deployments, storing API
keys, or altering `queue ask` runtime/provider selection. Bob11 owns ask-provider
runtime.

## Container registry candidate

Purpose: expose image/tag metadata facts such as registry, repository, digest,
architecture, signature/provenance status, vulnerability summary fixture,
retention posture, region/replication hints, and validation status.

Non-goals: pulling images, pushing images, deleting tags, creating repositories,
or changing job execution/sandbox behaviour.

## Implemented fixture-first candidates

- `providers.d/model_registry/model_registry_provider.sh`
- `providers.d/container_registry/container_registry_provider.sh`
- `policies.d/service-coverage/provider-service-coverage.json`

These candidates provide normalized JSON facts only. They do not perform live API
calls, inference, image pulls, repository mutation, provisioning, or scheduler
control.

## Later candidates

Vector database, data lake, GPU marketplace, and distributed-framework discovery
should follow the same normalized-fact provider pattern. They may inform class
selection, policy review, explainability, and governance, but they must not
become live provisioning or scheduler-control pathways.
