# Cloud infrastructure helpers

`providers.d/cloud_infra/` contains provider-specific helper scripts for starting,
stopping, and inspecting cloud infrastructure used by bashqueues development and
remote-service workers.

This layer is deliberately outside `queuebash.sh`. It does not refactor queue
submission, job resolution, worker execution, or the remote-service dispatcher.

## Purpose

The helpers provide a boring, auditable interface:

```text
registry -> provider helper -> normalized JSON decision/output
```

A helper must check the cloud infrastructure registry before attempting a cloud
mutation. The registry is the authority for whether a named service may be
started, stopped, created, or destroyed.

## Commands

Generic wrapper:

```bash
providers.d/cloud_infra/cloud_infra.sh list
providers.d/cloud_infra/cloud_infra.sh explain SERVICE
providers.d/cloud_infra/cloud_infra.sh plan SERVICE start
providers.d/cloud_infra/cloud_infra.sh start SERVICE
providers.d/cloud_infra/cloud_infra.sh stop SERVICE
providers.d/cloud_infra/cloud_infra.sh status SERVICE
```

OCI Free concrete helper:

```bash
providers.d/cloud_infra/oci_free_stack.sh plan SERVICE start
providers.d/cloud_infra/oci_free_stack.sh start SERVICE
providers.d/cloud_infra/oci_free_stack.sh stop SERVICE
providers.d/cloud_infra/oci_free_stack.sh status SERVICE
```

Default mode is dry-run. Live cloud mutation requires:

```bash
QUEUEBASH_CLOUD_INFRA_LIVE=1
```

The live gate is intentionally separate from provider credentials. Having OCI,
IBM, AWS, Azure, or GCP credentials on the host is not enough to mutate cloud
infrastructure by accident.

## Registry

Default path:

```text
policies.d/cloud-infra/registry.json
```

Override:

```bash
QUEUEBASH_CLOUD_INFRA_REGISTRY=/path/to/registry.json
```

Example registry:

```json
{
  "schema": "queuebash.cloud_infra.registry.v1",
  "services": [
    {
      "id": "oci-free-london",
      "provider": "oci",
      "helper": "oci_free",
      "enabled": true,
      "allowed_actions": ["plan", "status", "start", "stop"],
      "region": "uk-london-1",
      "compartment_source": "oci_config",
      "ssh_public_key_source": "first_pub_in_oci_dir",
      "shape": "VM.Standard.E2.1.Micro",
      "os": "Oracle Linux",
      "os_version": "8",
      "prefix": "lon-free",
      "vcn_cidr": "10.0.0.0/16",
      "subnet_cidr": "10.0.0.0/24",
      "allow_create": true,
      "allow_destroy": false,
      "legal": {
        "sovereignty": "uk",
        "retention_policy": "dev-artifacts-only",
        "classification": "dev-test"
      }
    }
  ]
}
```

## Normalized output

All helper outputs must use JSON and include:

```json
{
  "schema": "queuebash.cloud_infra.action.v1",
  "provider": "oci",
  "service_id": "oci-free-london",
  "action": "start",
  "decision": "dry_run",
  "reason": "live_gate_not_enabled",
  "registry_checked": true,
  "live": false,
  "mutated": false,
  "commands": []
}
```

## OCI Free helper

The OCI Free helper is based on the Architect's local `deploy-oci-free.sh`
pattern: it discovers an OCI compartment from `~/.oci/config`, discovers a public
SSH key from `~/.oci/*.pub`, creates a small public VCN/subnet/Internet Gateway
stack, launches an Always Free-compatible instance, and can start/stop an
existing registered instance.

Live create/start/stop uses OCI CLI commands only when
`QUEUEBASH_CLOUD_INFRA_LIVE=1` is set. Default tests use dry-run and fixtures.

## Safety rules

Hard rules:

```text
Do not run live cloud mutation by default.
Do not store cloud secrets in the registry.
Do not store SSH private keys, OCI private keys, API tokens, PAR URLs, or cloud
provider session credentials in the registry or logs.
Do not use the helpers as generic shell execution endpoints.
Do not bypass the registry action allowlist.
Do not destroy infrastructure unless the registry explicitly allows it and a
future destroy command has its own live gate.
```

## Platform helper contract

A platform helper may be concrete or a safe placeholder. Concrete helpers must
implement registry-aware `plan`, `status`, `start`, and `stop`. Placeholder
helpers must fail closed with stable JSON explaining that the platform is not yet
implemented.

Initial helpers:

```text
oci_free_stack.sh     concrete OCI Always Free / free-tier style helper
ibm_vpc_stack.sh      placeholder contract, fail-closed
aws_ec2_stack.sh      placeholder contract, fail-closed
azure_vm_stack.sh     placeholder contract, fail-closed
gcp_compute_stack.sh  placeholder contract, fail-closed
```

## Reference example

`examples/cloud-infra/deploy-oci-free.architect-local-example.sh` preserves the
Architect's local OCI Always Free deployment sketch as reference material. It is
not called by the generic helper wrapper and is not used by tests. The production
helper path remains registry-gated and dry-run by default.

## 0.18.55 EU sovereign and APAC/China helper parity

`cloud_infra` now includes dry-run/status helper rails for OVHcloud, Scaleway, Hetzner Cloud, Open Telekom Cloud, Alibaba Cloud, Tencent Cloud, and Huawei Cloud. These helpers expose normalized `queuebash.cloud_infra.action.v1` evidence and remain fixture-first: no live API calls, no credentials required, no provisioning/destruction, and no queue dispatch refactor.

