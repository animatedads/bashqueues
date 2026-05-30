# APAC/China explainability

Every provider decision should be explainable in human and JSON form.

Human output should include:

```text
Provider family: APAC/China
Provider: Alibaba Cloud / Tencent Cloud / Huawei Cloud
Check: identity / region / compute / storage / network / finops / legal
Decision: allow / deny / unknown / available
Source: fixture / config / future live provider
Fail-closed: true / false
Reason:
Remediation hint:
```

JSON output should use `queuebash.apac_china.<provider>.<check>.v1` for provider facts or `queuebash.apac_china.explain.v1` for an aggregate future command surface.

Sensitive values such as access keys, secret keys, signed URLs, STS/session tokens, console session links, and private keys must be redacted or omitted.
