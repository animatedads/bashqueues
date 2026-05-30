# Platform parity status

`CLOUD_PLATFORM_PARITY.md` is the human-facing parity matrix. The machine-readable
status for this consistency backfill lives in:

```text
policies.d/cloud-resource/provider-family-consistency.json
```

The current conclusion remains: platform coverage is not equal yet.

AWS, Azure, and GCP have first-tier contract coverage. OCI and IBM are high-standard references.
EU sovereign, APAC/China, GPU cloud, edge cloud, and hybrid/on-prem
are accepted fixture-first provider-family packs. They are useful engineering
coverage, but they are not first-tier or compliance-complete merely because they
have classes, docs, fixtures, and tests.

Provider parity requires primary-source validation, identity/auth modelling,
region/sovereignty posture, legal/compliance posture, FinOps/cost rail where
applicable, audit/evidence model, explainability, JSON contracts, and focused
regression tests.

## Explainability status

0.18.44 adds a provider explainability standard across Bob2 provider-family
packs. The standard requires clear decision/source/fail-closed/remediation
language and keeps provider-family status honest: mapped/pending-validation is
not first-tier parity.

## Validation status warning

The platform parity labels in this document are engineering status labels, not legal certifications. Region tables, legal framework hints, export-control notes, and compliance posture examples remain mapped/pending validation unless primary-source evidence and explicit acceptance are recorded.


## 0.18.52 update

Azure and GCP are now first-tier contract coverage entries. This is an engineering status: it confirms comparable docs, provider contracts, assets, classes, policies, fixtures, explainability, FinOps/cost posture, ITAR/export-control posture, and tests. It does not certify compliance, enable live APIs, permit provisioning, or change queue dispatch.
