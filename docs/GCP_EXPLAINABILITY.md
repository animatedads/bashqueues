# GCP explainability

Every provider decision should be explainable to a human and stable as JSON.

## Human fields

```text
Provider: GCP
Check: identity / region / compute / storage / network / finops / legal
Decision: allow / deny / unknown / available
Reason:
Source: fixture / config / future-live-provider
Fail-closed:
Next step:
```

## JSON example

```json
{
  "schema": "queuebash.gcp.explain.v1",
  "provider": "gcp",
  "check": "identity",
  "decision": "deny",
  "reason": "service_account_required_but_missing",
  "source": "fixture",
  "fail_closed": true,
  "remediation_hint": "Provide a validated fixture or configure a future gated GCP provider. Do not place service-account private keys in job files."
}
```

## Redaction

Explain output must not display service account private keys, OAuth refresh tokens, signed URLs, raw access tokens, or full sensitive metadata.
