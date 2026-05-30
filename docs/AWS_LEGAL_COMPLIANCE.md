# AWS Legal, Data Protection, ITAR, and Cost Posture

AWS first-tier status in bashqueues means the package has explicit contract coverage for governance domains, not that the tool can make legal decisions by itself. Local policy remains authoritative.

## Data protection

AWS workloads involving personal/customer data should require a class that combines `aws:region_allowed`, `cloud_resource:available`, `aws:finops_budget_ok`, and legal/audit assets where local policy requires them. Technical region gating is not a data-transfer basis. Queue advisory output must distinguish region checks from lawful basis, retention/legal hold, data classification, and audit evidence.

## ITAR / export control

`CLOUD_AWS_ITAR.env` is a template for export-control posture. Operators must bind it to organisation-specific region, account, principal, network, encryption, logging, and access-control policy.

## Cost

The AWS cost rail in this package is deliberately local-policy based. It does not query or mutate AWS Billing. Production cost integration should remain provider-gated and auditable.
