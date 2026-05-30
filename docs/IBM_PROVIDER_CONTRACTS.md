# IBM Cloud provider contracts

The IBM Cloud provider is fixture-first. No live IBM Cloud API calls are made in
default tests. Live checks may be gated behind `QUEUEBASH_IBM_LIVE_CHECKS=1` in a
future release.

The provider returns normalised JSON only. No IAM tokens, API keys, resource CRNs
beyond the instance under test, or credentials of any kind appear in provider
output.

## Schemas

```text
queuebash.ibm.detect.v1
queuebash.ibm.identity.v1
queuebash.ibm.region.v1
queuebash.ibm.resource.v1
queuebash.ibm.network.v1
queuebash.ibm.finops.v1
queuebash.ibm.legal.v1
queuebash.ibm.explain.v1
```

## detect

Fields: `account_id`, `region`, `resource_group`, `detected`, `method`,
`decision`, `reason`, `fail_closed`.

`method` is `fixture` for default tests. A future live path would use
`ibmcloud` CLI or instance metadata service (`169.254.169.254`).

## identity

Fields: `auth_method`, `account_id`, `iam_id`, `subject`, `token_expiry_seconds`,
`decision`, `reason`, `fail_closed`.

`auth_method` is one of `iam_token`, `service_id`, `trusted_profile`. The provider
must not log or return the token value. Fail closed if IAM validation is
unavailable.

## region

Fields: `region`, `sovereignty_zone`, `legal_frameworks[]`, `data_residency_decision`,
`decision`, `reason`, `fail_closed`.

Region-to-framework mapping uses `policies.d/ibm/regions.tsv`. Fail closed when
a class requires a specific framework and the region is not in the allowlist.

## resource

Fields: `resource_id`, `resource_group`, `state`, `decision`, `reason`,
`fail_closed`.

`resource_id` is a CRN. `state` is `active`, `inactive`, or `provisioning`.
Fail closed if resource state is not `active` when the class requires it.

## network

Fields: `vpc_id`, `subnet_id`, `security_group_ids[]`, `private_endpoint_only`,
`decision`, `reason`, `fail_closed`.

`private_endpoint_only: true` means the resource is accessible only via VPC
private endpoint. Classes with high-assurance posture should assert this.

## finops

Fields: `account_id`, `current_spend`, `budget_limit`, `budget_remaining`,
`anomaly_detected`, `cache_age_seconds`, `decision`, `reason`, `fail_closed`.

FinOps data comes from the local IBM FinOps cache (see `assets.d/ibm_finops.sh`).
No live IBM billing API calls are made. Fail closed when cache is absent or stale.

## legal

Fields: `region`, `frameworks_applicable[]`, `retention_policy_applied`,
`deletion_evidence_available`, `cross_border_transfer`, `validation_status`,
`decision`, `reason`, `fail_closed`.

`validation_status` is `mapped_pending_validation` until primary-source evidence
is verified and accepted. Do not claim legal compliance solely because this field
is present.

## Hard rules

- No IAM tokens, API keys, or credentials in provider output or logs.
- No live IBM Cloud API calls in default test paths.
- No shell code in provider output.
- Fail closed when a required class fact is unavailable.
- `par_url`, `sas`, `access_key`, `secret_key` must not appear in any output field.
