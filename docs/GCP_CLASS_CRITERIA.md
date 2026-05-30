# GCP class criteria

GCP class files in this package are examples and contract templates. They demonstrate how a future asset family could express GCP requirements without making GCP a special case in `queuebash.sh`.

## Example coverage levels

```text
CLOUD_GCP_DEFAULT
  basic provider identity, region, compute and audit posture

CLOUD_GCP_GDPR
  region allowlist, data-protection posture, retention/deletion evidence

CLOUD_GCP_HIGH_ASSURANCE
  identity, VPC/network, audit, logging, legal, FinOps and artifact rails

CLOUD_GCP_ARTIFACT_RUNNER
  storage/artifact rail for large logs and handover files
```

## Candidate asset statements

These are documentation examples. Runtime enforcement belongs to a later asset/provider integration package.

```bash
queue_class_shared_asset gcp identity service-account required=1 no-key-files=1
queue_class_shared_asset gcp region allowed-policy=uk-eu required=1
queue_class_shared_asset gcp network vpc-required=1 egress=restricted
queue_class_shared_asset gcp storage artifacts required=1 signed_url_redaction=1
queue_class_shared_asset gcp audit cloud-logging required=1
queue_class_shared_asset gcp finops labels-required=1 cost-center-required=1
queue_class_shared_asset legal sovereignty provider=gcp region="${GCP_REGION:-unknown}"
```

## Not first-tier by mention alone

A GCP class file does not make GCP first-tier. First-tier status requires provider contracts, fixtures, JSON contract tests, explainability, policy examples, legal/compliance posture, FinOps posture, and validated primary-source mapping.
