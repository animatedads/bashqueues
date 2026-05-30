# GPU cloud provisioning templates

`0.18.57` adds Bob10 GPU cloud provisioning template parity for CoreWeave, Lambda Cloud, and NVIDIA DGX Cloud.

The goal is to let `cloud_provision` produce governed, dry-run GPU capacity plans using the same work-order model as OCI/AWS/Azure/GCP/IBM provisioning templates. GPU providers remain fixture-first and policy-gated.

## Scope

Included:

- named GPU provisioning templates
- GPU cloud-infra registry mappings
- dry-run lifecycle evidence for GPU service mappings
- policy gates for provider, region, legal framework, export review, and cost ceiling
- registry-preview compatibility with `cloud_resource`

Excluded:

- live CoreWeave, Lambda Cloud, or DGX Cloud API calls
- Kubernetes cluster creation or mutation
- GPU node provisioning or destruction
- provider credentials in tests
- queue dispatch refactor

## Templates

Initial template names:

```text
gpu-coreweave-a100-training
gpu-lambda-h100-training
gpu-dgx-export-review
```

The deliberately failing template `bad-gpu-cost-breach` is present so tests prove GPU cost ceilings are enforced.

## Boundary

`cloud_provision` owns the signed work-order plan. `cloud_infra` emits dry-run/status evidence. `gpu_cloud_provider` owns fixture-first GPU provider facts. `cloud_resource` remains the inventory/claim/reconcile authority. Queue dispatch must not create GPU resources.
