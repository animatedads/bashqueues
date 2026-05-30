# AWS Provider Contracts

AWS is promoted to first-tier contract coverage in `0.18.31`. First-tier means bashqueues has a documented provider contract, read-only/fixture helper, asset preflight family, governance policy examples, GDPR/data-protection posture, ITAR/export-control posture, FinOps/cost guardrails, class templates, fixtures, and tests.

This is still not a live provisioning package. It does not run EC2 create or terminate operations, IAM mutation, Billing mutation, or any queue dispatch rewrite.

## Helper

```bash
providers.d/aws/aws_provider.sh detect
providers.d/aws/aws_provider.sh metadata
providers.d/aws/aws_provider.sh identity explain
providers.d/aws/aws_provider.sh region explain
providers.d/aws/aws_provider.sh data-protection explain
providers.d/aws/aws_provider.sh itar explain
providers.d/aws/aws_provider.sh finops explain
providers.d/aws/aws_provider.sh resource-shape explain
```

The default helper mode is fixture-only through `QUEUEBASH_AWS_FIXTURE_DIR`. Live AWS read checks are deferred. Mutation is out of scope.

## Schemas

- `queuebash.aws.detect.v1`
- `queuebash.aws.metadata.v1`
- `queuebash.aws.identity.v1`
- `queuebash.aws.region.v1`
- `queuebash.aws.data_protection.v1`
- `queuebash.aws.itar.v1`
- `queuebash.aws.finops.v1`
- `queuebash.aws.resource_shape.v1`

## Governance coverage

AWS first-tier coverage must include identity/auth context with account and principal provenance, region and sovereignty mapping, GDPR / UK DPA / data protection labels, ITAR / export-control labels, legal retention and jurisdiction policy references, audit/evidence posture, FinOps and cost ceiling policy examples, and provider-neutral `cloud_resource` records for capacity claims.

## Boundary

AWS provider contracts provide facts and fail-closed decisions. The cloud resource provider records inventory and claims. The cloud infrastructure helper may eventually start/stop named services under explicit gates. None of these rewrites queue dispatch.
