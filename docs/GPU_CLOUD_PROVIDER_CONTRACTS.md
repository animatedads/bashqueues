# GPU cloud provider contracts

This package defines fixture-first provider contracts for **CoreWeave**, **Lambda Cloud**, and **NVIDIA DGX Cloud**.

The contracts normalize provider facts into bashqueues-style JSON without making live provider calls by default. GPU providers are treated as capacity and governance surfaces, not queue dispatcher extensions.

## Scope

Included:

- provider detection fixtures
- identity/auth posture
- region/sovereignty mapping
- GPU accelerator/capacity shape facts
- object/artifact storage posture
- network/private-connectivity posture
- FinOps/cost/quota posture
- legal/compliance/export-control posture
- explainability for allow/deny/unknown decisions

Excluded:

- live CoreWeave, Lambda, or DGX API calls by default
- GPU node provisioning or shutdown
- Kubernetes cluster mutation
- credentials required for tests
- queuebash.sh dispatcher refactor
- compliance or platform-parity claims beyond mapped pending validation

## Schemas

CoreWeave examples use schema names such as:

```json
{"schema":"queuebash.gpu_cloud.coreweave.detect.v1"}
```

Lambda Cloud examples use schema names such as:

```json
{"schema":"queuebash.gpu_cloud.lambda.identity.v1"}
```

NVIDIA DGX Cloud examples use schema names such as:

```json
{"schema":"queuebash.gpu_cloud.dgx.accelerator.v1"}
```

Common checks:

```text
detect
identity explain
region explain
accelerator explain
storage explain
network explain
finops explain
legal explain
```

## Security rules

- Do not store provider API keys, Kubernetes kubeconfigs, cloud tokens, SSH private keys, model registry secrets, object-store signed URLs, or container registry credentials in queue job files.
- Do not log signed URLs, bearer tokens, registry credentials, or full sensitive metadata.
- Provider helper output must be constrained JSON only. It must not return shell code or policy code.
- Missing required fixture/provider facts must fail closed for GPU-constrained classes.
- Live checks belong in later opt-in packages only.

## Provider notes

CoreWeave, Lambda Cloud, and NVIDIA DGX Cloud have different operational models. Some may expose Kubernetes, GPU instances, private networking, managed GPU clusters, or provider-specific storage/artifact services. This package deliberately does not assume one universal GPU cloud API. It records normalized provider facts and governance posture only.
