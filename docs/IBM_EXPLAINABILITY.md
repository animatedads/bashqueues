# IBM Cloud provider explainability

## Human explain format

```text
Provider: IBM Cloud
Check: detect / identity / region / resource / network / finops / legal
Decision: allow / deny / unknown / available
Reason: short machine-readable reason string
Source: fixture / config / provider
Fail-closed: true / false
Next step: remediation hint
```

## JSON explain format

Schema: `queuebash.ibm.explain.v1`

```json
{
  "schema": "queuebash.ibm.explain.v1",
  "provider": "ibm",
  "check": "identity",
  "decision": "allow",
  "reason": "ibm_iam_token_valid",
  "source": "fixture",
  "fail_closed": true,
  "remediation_hint": "..."
}
```

## Reason vocabulary

| Reason | Meaning |
|--------|---------|
| `ibm_fixture_detected` | Detect succeeded from fixture |
| `ibm_iam_token_valid` | IAM token accepted |
| `ibm_cli_not_available` | `ibmcloud` CLI missing |
| `ibm_auth_required` | Auth gate failed, class requires IBM auth |
| `region_in_allowed_framework` | Region is in the framework allowlist |
| `region_not_in_framework` | Region is outside the required framework allowlist |
| `resource_instance_active` | Resource CRN is active |
| `resource_instance_inactive` | Resource CRN is not in active state |
| `vpc_network_posture_ok` | VPC / subnet / security group posture meets class |
| `budget_ok_no_anomaly` | FinOps cache shows budget headroom and no anomaly |
| `finops_cache_stale` | FinOps cache absent or older than max-age |
| `budget_exhausted` | Remaining budget below class minimum |
| `anomaly_detected` | FinOps health stream contains unacceptable anomaly |
| `legal_framework_mapped_pending_validation` | Framework mapped; primary-source not yet validated |
| `missing_fixture_*` | Required fixture file absent |

## Redaction requirements

The following must never appear in explain output, logs, or audit records:

- IAM tokens or refresh tokens
- API keys (`ibmcloud_api_key` or similar)
- Service ID credentials
- Resource CRNs beyond the instance under test
- VPC subnet CIDR ranges if considered sensitive
- FinOps raw invoice line items
- Legal hold identifiers beyond the record category

## Source values

| Source | Meaning |
|--------|---------|
| `fixture` | Data came from `QUEUEBASH_IBM_FIXTURE_DIR` |
| `config` | Data came from environment / policy file |
| `provider` | Data came from a live IBM Cloud call (future; not default) |
