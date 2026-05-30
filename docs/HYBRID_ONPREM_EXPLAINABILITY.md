# Hybrid/on-prem explainability

Every hybrid/on-prem decision should be explainable in human and JSON form.

Human output should include:

- Provider family: Hybrid/on-prem
- Provider: VMware / OpenStack / OpenShift
- Check: identity, region, virtualization/platform, storage, network, FinOps, legal
- Decision: allow, available, deny, or unknown
- Source: fixture, config, or future provider cache
- Fail-closed state
- Remediation hint

JSON explain schema:

```json
{
  "schema": "queuebash.hybrid_onprem.explain.v1",
  "provider_family": "hybrid_onprem",
  "provider": "openstack",
  "check": "identity",
  "decision": "deny",
  "reason": "tenant_required_but_missing",
  "source": "fixture",
  "fail_closed": true,
  "remediation_hint": "Provide validated tenant/project identity mapping before using this class."
}
```

Secrets must be redacted. Kubeconfigs, vCenter credentials, OpenStack application credentials, RC files, bearer tokens, SSH keys, and certificates must not appear in normal logs, scratchpad entries, fixtures, or package examples.
