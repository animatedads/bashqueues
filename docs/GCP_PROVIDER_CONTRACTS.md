# GCP provider contracts

This package adds a contract-first Google Cloud Platform provider pack for bashqueues.

It is deliberately fixture-first and non-mutating. It does not call live Google APIs by default, does not require `gcloud`, does not require service-account keys, and does not change `queuebash.sh` or core queue dispatch.

## Scope

GCP provider support in this package means normalized, constrained JSON for:

- environment detection
- identity/auth posture
- region and sovereignty posture
- Compute Engine resource inventory posture
- Cloud Storage artifact/logging posture
- VPC/network posture
- FinOps/cost label posture
- legal/compliance posture
- explainability

## Provider boundary

The bashqueues core consumes normalized JSON. The provider layer answers GCP-specific questions and must not return shell code, policy code, credentials, or unbounded metadata.

```text
queuebash core / assets / classes
  consume normalized provider decisions

providers.d/gcp/gcp_provider.sh
  reads fixtures or future gated providers
  emits queuebash.gcp.*.v1 JSON
  fails closed when required facts are missing
```

## Default mode

Default mode is fixture-only:

```bash
QUEUEBASH_GCP_FIXTURE_DIR=tests/fixtures/gcp \
  providers.d/gcp/gcp_provider.sh detect
```

Live checks are out of scope for this package. A later package may add live-gated checks behind an explicit variable such as `QUEUEBASH_GCP_LIVE_CHECKS=1`, but default tests must remain credential-free.

## Schemas

The package defines these normalized schema names:

```text
queuebash.gcp.detect.v1
queuebash.gcp.identity.v1
queuebash.gcp.region.v1
queuebash.gcp.compute.v1
queuebash.gcp.storage.v1
queuebash.gcp.network.v1
queuebash.gcp.finops.v1
queuebash.gcp.legal.v1
queuebash.gcp.explain.v1
```

## Security requirements

Hard rules:

```text
No service-account private keys in job files.
No OAuth refresh tokens in registry files or logs.
No signed URLs in normal logs unless redacted.
No live API calls in default tests.
No provisioning or destruction.
No shell/policy code returned from provider helpers.
Fail closed for classes that declare required GCP constraints.
```

## Validation status

This is a provider-contract pack. Any compliance or provider-specific detail must be treated as mapped/proposed/pending validation until checked against primary Google and legal sources and accepted by Team Leader/Architect.
