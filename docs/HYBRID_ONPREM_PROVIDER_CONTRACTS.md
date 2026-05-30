# Hybrid/on-prem provider contracts

Bob2 package: `0.18.39_hybrid_onprem_provider_contracts`.

This package defines fixture-first provider contracts for VMware/vCloud, OpenStack, and OpenShift. It is a provider-family coverage pack, not a live integration, scheduler, cloud provisioning layer, or dispatcher rewrite.

Providers covered:

- `vmware` / VMware vSphere and vCloud-style estates
- `openstack` / OpenStack private cloud estates
- `openshift` / Red Hat OpenShift platform estates

Default behaviour:

- no live provider API calls
- no credentials required by default
- no provisioning, deletion, migration, deployment, or cluster mutation
- no queue dispatcher refactor
- no compliance claims beyond mapped pending validation

Normalized schemas:

- `queuebash.hybrid_onprem.vmware.detect.v1`
- `queuebash.hybrid_onprem.vmware.identity.v1`
- `queuebash.hybrid_onprem.vmware.region.v1`
- `queuebash.hybrid_onprem.vmware.virtualization.v1`
- `queuebash.hybrid_onprem.vmware.storage.v1`
- `queuebash.hybrid_onprem.vmware.network.v1`
- `queuebash.hybrid_onprem.vmware.finops.v1`
- `queuebash.hybrid_onprem.vmware.legal.v1`

The same check names apply to `openstack` and `openshift`.

Provider helpers return constrained normalized JSON only. They must not return shell code, provider CLI fragments, kubeconfigs, vCenter credentials, OpenStack RC secrets, SSH keys, bearer tokens, certificates, VM console passwords, or sensitive inventory dumps.

Live mode is intentionally not implemented in this contract pack. Future live helpers, if accepted later, must be explicitly gated, audited, bounded, policy-controlled, and separated from ordinary queue dispatch.
