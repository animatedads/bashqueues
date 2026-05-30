# OCI Class Criteria

This file records example class criteria for OCI-governed workloads. It is deliberately documentation-first: no core queue parser changes are required by this package.

## Example class families

```text
CLOUD_OCI_DEFAULT
CLOUD_OCI_HIGH_ASSURANCE
CLOUD_OCI_ARTIFACT_RUNNER
CLOUD_OCI_LEGAL_COMPLIANCE
```

## Criteria

A class that claims OCI governance should document:

- required identity mode, preferably Instance Principals
- metadata source, preferably IMDSv2 with `Authorization: Bearer Oracle`
- expected region and legal/sovereignty mapping
- object-storage artifact handoff requirements
- PAR redaction and expiry requirements
- network context requirements, including VCN/subnet/NSG/Security List expectations
- audit/log retention requirements
- whether live OCI checks are allowed, and under what explicit gate

## Example policy intent

```bash
queue_class_shared_asset oci identity instance-principal required=1
queue_class_shared_asset oci metadata imds-v2 required=1
queue_class_shared_asset oci network nsg-required=1 egress=restricted
queue_class_shared_asset oci object-storage artifacts required=1 par_expiry_required=1
queue_class_shared_asset legal sovereignty provider=oci region="${OCI_REGION:-unknown}"
queue_class_shared_asset integrity manifest verified=1
queue_class_shared_asset secaudit logging required=1
```

If the `oci` facility is not yet a runtime asset, treat these as class examples and static criteria only.

## Compliance mapping

For legal/compliance workloads, class criteria should explain:

- where data may be processed
- where logs and artifacts may be stored
- retention expiry expectations
- who or what is allowed to access object-storage artifacts
- whether PAR handoff is permitted
- what must be redacted from logs
- what audit evidence must be retained
