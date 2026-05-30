# Azure explainability

Human explain output should include:

```text
Provider: Azure
Check: identity / region / compute / storage / network / finops / legal
Decision: allow / deny / unknown / available
Reason: short machine-readable reason
Source: fixture / config / provider
Fail-closed: true / false
Next step: remediation hint
```

JSON explain output uses `queuebash.azure.explain.v1` and must avoid secrets.

Sensitive fields include service principal secrets, refresh tokens, access tokens, SAS tokens, signed URLs, storage account keys, customer-managed key material, and custom-script/user-data content.
