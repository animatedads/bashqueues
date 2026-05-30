# Azure and GCP first-tier platform parity

0.18.52 promotes Azure and GCP to **first-tier contract coverage** in the bashqueues cloud platform parity model.

This is an engineering-contract status, not a legal certification. Azure and GCP remain fixture-first and non-mutating by default. The package does not perform live cloud API calls, require credentials for default tests, provision resources, destroy resources, or refactor queue dispatch.

## What first-tier means here

A first-tier platform has the same minimum contract surface as AWS in this line:

```text
identity/auth posture
provider JSON contract
asset checks
policy examples
class templates
region/sovereignty model
GDPR/data-protection posture
ITAR/export-control posture
legal retention/jurisdiction notes
audit/evidence model
FinOps/cost posture
fixtures
static/smoke/JSON tests
explainability documentation
```

## Azure uplift

Azure already had provider contracts, assets, classes, fixtures, and tests. The 0.18.52 uplift makes the parity claim explicit by adding/standardising:

```text
policies.d/azure/cost-policy.example.json
policies.d/azure/export-control.example.json
CLOUD_AZURE_ITAR class presence checks
Azure FinOps fixture checks
Azure first-tier matrix assertions
```

Azure first-tier coverage remains bounded by these hard rules:

```text
no live Azure API calls by default
no az login required for default tests
no VM create/delete/start/stop in this package
no SAS/token/client-secret storage in package files
no queue dispatch refactor
mapped/pending-validation language for legal/compliance claims
```

## GCP uplift

GCP already had provider contracts, assets, classes, fixtures, and tests. The 0.18.52 uplift makes the parity claim explicit by adding/standardising:

```text
policies.d/gcp/cost-policy.example.json
policies.d/gcp/export-control.example.json
CLOUD_GCP_ITAR class presence checks
GCP FinOps fixture checks
GCP first-tier matrix assertions
```

GCP first-tier coverage remains bounded by these hard rules:

```text
no live Google API calls by default
no gcloud login required for default tests
no Compute Engine create/delete/start/stop in this package
no OAuth/service-account key/signed URL storage in package files
no queue dispatch refactor
mapped/pending-validation language for legal/compliance claims
```

## Still not equal overall

The overall platform verdict remains `not_equal_yet` because OCI, IBM, EU sovereign, APAC/China, GPU cloud, edge cloud, and hybrid/on-prem families still have different maturity levels and validation statuses.

Do not turn this package into provisioning or scheduling. Queue dispatch may consume resource facts through assets/classes, but provider parity does not grant permission to call cloud lifecycle operations.
