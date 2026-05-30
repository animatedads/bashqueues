# OCI Legal and Compliance Criteria

This package does not make legal claims. It records the compliance data that a future OCI provider should expose so classes can be assessed and explained.

## Compliance rails

### Sovereignty and region

Record OCI region and map it to an approved sovereignty/legal framework table. Example policy files:

```text
policies.d/oci/regions.tsv
policies.d/oci/legal-frameworks.example.tsv
```

### Retention and deletion

Object Storage artifact handling should support explicit retention periods, deletion responsibility, and evidence pointers. Over-retention should be visible in explain output.

### Auditability

OCI explain outputs should identify source, provider, decision, fail-closed reason, config source, and remediation hint. Large logs should be stored as bounded artifacts/pointers, not embedded in scratchpad or normal command logs.

### Sensitive URLs and credentials

PAR URLs, security tokens, private keys, and config secrets must be treated as sensitive. Normal logs should contain redacted values only.

### shared responsibility

bashqueues should distinguish provider assurances from tenant responsibilities:

- provider/context facts: region, tenancy, VCN/subnet/NSG, metadata, shape
- tenant controls: identity, workload hardening, logging, retention, legal allowlist, artifact handoff rules

### primary-source validation

Cloud legal/compliance criteria imported from AI, notes, or advisers must remain advisory until validated against primary sources and explicitly accepted into the scratchpad or documentation.
