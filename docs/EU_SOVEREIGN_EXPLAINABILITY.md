# EU sovereign cloud explainability

Human explain output should include:

- Provider family: EU sovereign
- Provider: OVHcloud / Scaleway / Hetzner / Open Telekom Cloud
- Check: identity / region / compute / storage / network / finops / legal
- Decision: allow / deny / unknown / available
- Reason
- Source: fixture / config / provider-cache / future-live-provider
- Fail-closed
- Remediation hint

JSON explain schema pattern:

```json
{
  "schema": "queuebash.eu_sovereign.explain.v1",
  "provider_family": "eu_sovereign",
  "provider": "ovhcloud",
  "check": "legal",
  "decision": "deny",
  "reason": "region_not_in_allowlist",
  "source": "fixture",
  "fail_closed": true,
  "remediation_hint": "Choose an approved EU region or a different class."
}
```

No provider access tokens, API secrets, private keys, signed URLs, or console-session URLs should appear in normal explain output.
