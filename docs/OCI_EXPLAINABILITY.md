# OCI Explainability

Every OCI provider decision should be explainable in human and JSON forms.

## Human explain format

```text
Provider: OCI
Check: identity / metadata / object-storage / network / resource-shape / region
Decision: allow / deny / unknown
Reason: short machine-readable reason
Source: fixture / config / IMDSv2 / OCI CLI
Fail-closed: true / false
Compliance: sovereignty / retention / audit / redaction notes where relevant
Next step: remediation hint
```

## JSON explain schema

```json
{
  "schema": "queuebash.oci.explain.v1",
  "provider": "oci",
  "check": "identity",
  "decision": "deny",
  "reason": "instance_principal_required_but_unavailable",
  "source": "fixture",
  "fail_closed": true,
  "remediation_hint": "Enable OCI instance principals for this worker or use a non-OCI class."
}
```

## Fail-closed expectation

If an OCI class requires a fact and the provider cannot prove it, the explanation should say `deny` or `unknown` with `fail_closed=true`. Missing provider fixtures must not become allow decisions.
