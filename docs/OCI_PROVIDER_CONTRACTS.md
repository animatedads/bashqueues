# OCI Provider Contracts

Status: contract-first planning package. This document defines Oracle Cloud Infrastructure provider contracts for bashqueues without wiring OCI into the core queue dispatcher.

## Scope

This package advances OCI support as a provider surface only:

- identity contract
- metadata and resource-shape contract
- object-storage artifact contract
- network context contract
- region, sovereignty, and legal/compliance contract
- explainability and audit contract
- fixture-first tests

It deliberately does not refactor `queue()`, job resolution, queue-dev-test internals, or the remote runner. It also does not require live OCI access for normal tests.

## Provider model

bashqueues core should consume constrained normalized JSON. OCI-specific helpers may inspect OCI-specific sources, but they must not return shell code, inject policy code, or silently allow when required facts cannot be obtained.

Initial helper surface:

```text
providers.d/oci/oci_provider.sh detect
providers.d/oci/oci_provider.sh metadata
providers.d/oci/oci_provider.sh identity explain
providers.d/oci/oci_provider.sh region explain
providers.d/oci/oci_provider.sh object-storage explain
providers.d/oci/oci_provider.sh network explain
providers.d/oci/oci_provider.sh resource-shape explain
```

The helper is fixture-first. Live OCI checks are out of scope for default tests and must be explicitly enabled by future packages.

## Security rules

Hard rules:

```text
Do not store OCI PEM private keys in queue job files.
Do not put OCI private keys, config profiles, security tokens, or PAR URLs into normal logs.
Do not require live OCI calls for ordinary queue operation or default test runs.
Do not allow provider helper output to include shell code.
Do not let provider failure become silent allow.
Fail closed for classes that declare OCI requirements when required facts cannot be confirmed.
```

## Normalized schemas

### `queuebash.oci.detect.v1`

```json
{
  "schema": "queuebash.oci.detect.v1",
  "provider": "oci",
  "detected": true,
  "method": "fixture",
  "metadata_reachable": true,
  "auth_header_required": true,
  "region": "uk-london-1",
  "availability_domain": "example-ad-1",
  "compartment_id": "ocid1.compartment.example",
  "instance_id": "ocid1.instance.example",
  "fail_closed": false,
  "reason": "oci_fixture_detected"
}
```

OCI IMDSv2 metadata requires the request header:

```text
Authorization: Bearer Oracle
```

The contract therefore records `auth_header_required=true` even when tests are fixture-based.

### `queuebash.oci.identity.v1`

```json
{
  "schema": "queuebash.oci.identity.v1",
  "provider": "oci",
  "auth_mode": "instance_principal",
  "oci_cli_auth": "instance_principal",
  "principal_type": "instance",
  "decision": "allow",
  "reason": "instance_principal_fixture_available",
  "fail_closed": false
}
```

Workers should prefer Instance Principals for zero-credential operation. If an OCI class requires Instance Principals and they are unavailable, the decision must be deny/fail-closed.

### `queuebash.oci.resource_shape.v1`

```json
{
  "schema": "queuebash.oci.resource_shape.v1",
  "provider": "oci",
  "shape": "VM.Standard.E4.Flex",
  "ocpus": 4,
  "memory_gb": 32,
  "source": "fixture",
  "cpu_limit_supported": true,
  "memory_limit_supported": true,
  "reason": "fixture_shape_detected"
}
```

This is an explanation/provider-fact contract. It does not implement cgroup or systemd enforcement.

### `queuebash.oci.object_storage.v1`

```json
{
  "schema": "queuebash.oci.object_storage.v1",
  "provider": "oci",
  "mode": "instance_principal",
  "bucket": "queuebash-artifacts",
  "namespace": "example_namespace",
  "prefix": "queuebash/dev-test/",
  "par_supported": true,
  "par_expiry_required": true,
  "decision": "available",
  "reason": "fixture_object_storage_config_present"
}
```

PAR URLs are sensitive access-bearing URLs. Store redacted pointers and bounded evidence, not full URLs.

### `queuebash.oci.network.v1`

```json
{
  "schema": "queuebash.oci.network.v1",
  "provider": "oci",
  "vcn_id": "ocid1.vcn.example",
  "subnet_id": "ocid1.subnet.example",
  "nsg_ids": ["ocid1.networksecuritygroup.example"],
  "security_lists": ["ocid1.securitylist.example"],
  "egress_policy": "restricted",
  "ingress_policy": "ssh_restricted",
  "decision": "allow",
  "reason": "fixture_network_controls_present"
}
```

OCI has Security Lists and Network Security Groups. The provider contract records expected context and explains whether approved VCN/subnet/NSG information is present.

### `queuebash.oci.region.v1`

```json
{
  "schema": "queuebash.oci.region.v1",
  "provider": "oci",
  "region": "uk-london-1",
  "sovereignty_zone": "uk",
  "legal_frameworks": ["UK_DPA", "GDPR"],
  "data_residency_decision": "allow",
  "reason": "region_allowed_by_fixture_policy",
  "fail_closed": false
}
```

Region/sovereignty facts are compliance inputs. They do not replace legal review, but they let bashqueues explain why a class is allowed, denied, or unknown.

## Legal/compliance side

OCI support must carry the same governance rails as other cloud providers:

- sovereignty and allowed region mapping
- data classification and sensitivity level
- retention and deletion expectations
- auditability and immutable evidence pointers
- cross-border transfer caution
- shared-responsibility statement
- credential and PAR redaction
- primary-source validation for any legal claim

See `docs/OCI_LEGAL_COMPLIANCE.md` for the explicit compliance checklist.
