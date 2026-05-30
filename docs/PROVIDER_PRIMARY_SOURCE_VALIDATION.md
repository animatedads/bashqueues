# Provider primary-source validation framework

This Bob2 backfill defines how bashqueues turns provider-family research, advisory imports, fixtures, and policy examples into accepted engineering criteria.

Provider-family packs are useful only if their status is honest. A fixture-first provider pack may map a provider's expected identity, region, storage, logging, network, legal, and FinOps posture, but that does not make the platform first-tier, compliant, production-ready, or legally safe. Those claims require primary-source validation and explicit acceptance.

## Status vocabulary

Use these statuses in provider docs, parity docs, and machine-readable policy:

| Status | Meaning |
| --- | --- |
| `advisory_import` | Research or external-AI input. Useful for backlog only. Not accepted criteria. |
| `mapped_pending_validation` | Represented in docs/fixtures/tests but not validated against primary sources. |
| `primary_source_validated` | Checked against current official provider, regulator, standards, or legal source material. |
| `accepted_project_criterion` | Validated point explicitly accepted by Team Leader/Architect into bashqueues criteria. |
| `stale_validation` | Previously validated but old enough or source-dependent enough to require recheck. |
| `rejected_or_superseded` | Do not use for design/acceptance claims. |

Default provider-family packs must stay at `mapped_pending_validation` unless a package explicitly includes validation evidence and acceptance notes.

## Primary sources

Acceptable primary-source families include:

- provider official documentation for identity, region, metadata, storage, logging, pricing, quotas, support boundaries, and network behaviour;
- regulator or standards-body material for legal/compliance controls;
- official government guidance for export-control, sovereignty, public-sector, or data-protection claims;
- project-owned live probes or reproducible test evidence when the package scope allows them.

External AI, blogs, marketing pages, copied examples, and old scratchpad claims are not primary-source validation by themselves.

## Region-table warnings

Region tables in `policies.d/<provider>/regions.tsv` and provider-family docs are not production legal advice. They are starter maps for fixtures and class criteria.

Every region mapping should carry or imply:

- provider family;
- region code/name;
- country or jurisdiction hint;
- legal framework hint;
- validation status;
- source reference or evidence id when validated;
- last-validated date when applicable.

A region entry without primary-source evidence is only `mapped_pending_validation`.

## Export-control and ITAR normalisation

Provider packs must not treat export-control language as provider-specific folklore. Normalise it into project criteria such as:

- `export_control_required`;
- `itar_review_required`;
- `restricted_country_review_required`;
- `gpu_or_accelerator_export_review_required`;
- `sensitive_model_training_review_required`;
- `customer_data_transfer_review_required`.

Class examples may demonstrate these gates, but they must not claim legal compliance unless validated and accepted.

## Evidence hygiene

Do not store secrets or sensitive artefacts as validation evidence. Do not store provider tokens, private keys, signed URLs, PAR URLs, kubeconfigs, OpenStack RC secrets, service-account keys, or full logs with customer data. Store redacted source references, evidence hashes, bounded excerpts, and pointers.

## Acceptance rule

A provider-family claim becomes an accepted project criterion only when the package includes:

1. primary-source reference or project-owned reproducible evidence;
2. validation status update;
3. tests or docs proving how the criterion is consumed;
4. Team Leader or Architect acceptance note in the scratchpad;
5. no downgrade of fail-closed or fixture-first default behaviour.
