# GPU cloud explainability

Every GPU cloud provider decision should be explainable in human and JSON form.

Human output should include:

```text
Provider family: GPU cloud
Provider: CoreWeave / Lambda Cloud / NVIDIA DGX Cloud
Check: identity / region / accelerator / storage / network / finops / legal
Decision: allow / deny / unknown / available
Source: fixture / config / future-live-provider
Fail-closed: true / false
Reason:
Next step:
```

JSON examples use:

```json
{
  "schema": "queuebash.gpu_cloud.explain.v1",
  "provider_family": "gpu_cloud",
  "provider": "coreweave",
  "check": "accelerator",
  "decision": "deny",
  "reason": "required_gpu_family_unavailable",
  "source": "fixture",
  "fail_closed": true,
  "remediation_hint": "Select an approved GPU provider/region with required accelerator capacity or use a non-GPU class."
}
```

Explain output must never reveal API keys, kubeconfigs, signed URLs, registry secrets, bearer tokens, or private key material.
