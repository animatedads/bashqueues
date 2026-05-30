# GPU cloud class criteria

GPU cloud classes are examples for workload governance. They are not automatic provisioning hooks.

## Common criteria

- GPU provider must be identified and approved.
- Accelerator family/model must match the class requirement.
- Region/sovereignty posture must be mapped.
- Export-control and sensitive workload rules must be evaluated.
- Artifact/model/data storage must redact signed URLs and credentials.
- Network posture must document public, private, VPN, direct-connect, or cluster-only access.
- FinOps posture must include quota/cost-capacity signals where available.
- Legal/compliance posture remains mapped pending validation unless primary-source validated.

## Example class families

```text
CLOUD_GPU_DEFAULT
CLOUD_GPU_HIGH_ASSURANCE
CLOUD_GPU_ARTIFACT_RUNNER
CLOUD_GPU_EXPORT_REVIEW
CLOUD_GPU_MODEL_TRAINING
```

Do not treat class examples as proof that a provider is first-tier or legally compliant.
