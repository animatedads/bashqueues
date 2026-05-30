# Provider family consistency backfill

This document is the Bob2 consistency layer for accepted provider-family packs.
It does not introduce a new provider, live cloud integration, provisioning path,
or queue dispatcher behaviour. It records the minimum shape expected of provider
packs and makes the platform-parity status explicit.

## Status vocabulary

Provider/platform entries should use one of these statuses:

- `first_tier_contract`: coverage is broad enough to be treated as first-tier
  contract coverage, while still avoiding live mutation by default.
- `high_standard_reference`: existing provider material is strong enough to be a
  reference for future packs, but not necessarily complete first-tier parity.
- `fixture_first_provider_family`: docs, provider helper, policies, classes,
  fixtures, JSON contracts, explainability and tests exist; claims remain mapped
  pending validation and default tests are non-live.
- `mapped_pending_validation`: useful mapped material exists, but primary-source
  validation and/or parity gaps remain.

## Provider-pack minimum shape

For each Bob2 provider-family pack, the package should include:

- provider contracts documentation
- class criteria documentation
- explainability documentation
- legal/compliance documentation
- provider helper under `providers.d/<family>/`
- policy examples under `policies.d/<family>/`
- class templates under `classes/`
- fixtures under `tests/fixtures/<family>/`
- static, fixture-smoke, JSON-contract, and explainability tests where relevant
- explicit no-live/no-credential/no-provisioning default behaviour

## Current platform status

| Family | Status | Notes |
| --- | --- | --- |
| AWS | first_tier_contract | Bob10 first-tier contract coverage; no live mutation by default. |
| OCI | high_standard_reference | Strong OCI provider docs/classes/policies/fixtures/tests; still not a live integration by default. |
| IBM | high_standard_reference | Strong IBM governance/FinOps/class material; used as reference posture, not a completed first-tier parity claim. |
| GCP | fixture_first_provider_family | Bob2 provider pack accepted; mapped pending primary-source validation and cost/ITAR/resource parity. |
| Azure | fixture_first_provider_family | Bob2 backfill accepted; mapped pending first-tier parity. |
| EU sovereign | fixture_first_provider_family | OVHcloud, Scaleway, Hetzner, OTC mapped as fixture-first provider family. |
| APAC/China | fixture_first_provider_family | Alibaba, Tencent, Huawei mapped as fixture-first provider family. |
| GPU cloud | fixture_first_provider_family | CoreWeave, Lambda, DGX mapped; GPU quota/export/data protection gaps remain. |
| Edge cloud | fixture_first_provider_family | Cloudflare Workers, Fastly Compute@Edge, Fly.io mapped; edge locality/cache/log posture remains pending validation. |
| Hybrid/on-prem | fixture_first_provider_family | VMware/vCloud, OpenStack, OpenShift mapped; site/legal/identity posture remains pending validation. |

## Guardrails

Provider-family consistency checks must not become a back door for live cloud
work. A provider pack may describe future live behaviour, but default tests must
not require credentials, network access, provisioning, resource destruction, or
cloud mutation. `queuebash.sh` dispatch and job execution semantics remain out of
scope for Bob2 provider-family consistency work.

## 0.18.44 Bob2 provider explainability standardization

Provider-family packs must now follow the shared provider explainability
standard in `docs/PROVIDER_EXPLAINABILITY_STANDARD.md` and the machine-readable
policy in `policies.d/cloud-resource/provider-explainability-standard.json`.
This does not promote fixture-first packs to first-tier parity; it standardizes
how decisions, sources, fail-closed behaviour, remediation hints, and validation
status are documented and tested.

## Primary-source validation overlay

Provider-family consistency now includes a validation overlay. A provider pack can be structurally complete while still mapped/pending validation. First-tier or compliance-facing claims require primary-source evidence, explicit validation status, and Team Leader/Architect acceptance.

See `docs/PROVIDER_PRIMARY_SOURCE_VALIDATION.md` and `policies.d/cloud-resource/provider-primary-source-validation.json`.


## 0.18.52 Bob10 update

Azure and GCP are promoted from `fixture_first_provider_family` to `first_tier_contract` status. The promotion is still fixture-first and non-mutating, and legal/compliance mappings remain pending validation unless separately accepted.
