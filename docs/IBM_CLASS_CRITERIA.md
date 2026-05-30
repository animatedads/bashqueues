# IBM Cloud class criteria

A class may claim IBM Cloud posture only when all of the following are satisfied.
Claiming compliance solely because these files exist is incorrect — contracts,
fixtures, JSON schemas, explainability, and tests must all align.

## Required for any IBM Cloud class

- `QUEUEBASH_CLOUD_PROVIDER=ibm` is set.
- `queue_class_shared_asset ibm_identity auth_active _` gates every job.
- `queue_class_shared_asset ibm_identity target_region_allowed FRAMEWORK` is set
  with the appropriate framework label (GDPR, FINREG, LEGAL, UK_DPA).
- `CLASS_DEFAULT_RUNTIME_CAPS` includes `no-spawn-shell`.
- `CLASS_DEFAULT_SANDBOX_LEVEL` is set (at minimum `permissive`; high-assurance
  classes must use `strict`).

## Identity and auth posture

- Auth method must be documented: `iam_token`, `service_id`, or `trusted_profile`.
- Trusted profiles are preferred for platform workloads; service IDs require
  API key rotation policy documentation.
- No hardcoded API keys in class files or policy examples.

## Region and sovereignty

- Allowed regions must be listed in `policies.d/ibm/regions.tsv`.
- Classes asserting GDPR posture must restrict to: `eu-de`, `eu-gb`, `eu-es`.
- Classes asserting UK DPA posture must restrict to: `eu-gb`.
- Financial-services posture (FINREG) may use the IBM Financial Services validated
  regions: `us-south`, `us-east`, `ca-tor`, `eu-de`, `eu-gb`, `eu-es`, `au-syd`,
  `jp-tok`, `jp-osa`, `br-sao`.

## Resource posture

- High-assurance classes must assert `private_endpoint_only: true`.
- Resource CRNs must not appear in class files; use environment references.

## FinOps posture

- `ibm_finops:cost_cache_fresh` must gate regulated workloads.
- Budget and anomaly gates must be present for FINREG-class jobs.
- Cache max-age must be documented and appropriate (≤86400s for regulated).

## Legal and retention

- FINREG classes must gate on `legal retention_respected` and
  `legal jurisdiction_allowed`.
- `integrity manifest_verified` is required for FINREG and LEGAL_COMPLIANCE.
- `QUEUEBASH_LEGAL_EFFECT` must be set: `readonly` or `destructive`.
- Validation status `mapped_pending_validation` means primary-source evidence
  has not been accepted. Do not mark jobs as legally compliant until validation
  is complete.

## Audit posture

- High-assurance and FINREG classes should document the audit log path
  expected (IBM Activity Tracker with LogDNA or IBM Cloud Logs).
- LEGAL_READONLY classes must not permit write operations; enforce with
  `no-network-tools` or equivalent caps where applicable.
