# Cloud job intent submit contract

`queue submit --uses-cloud` lets a job declare that it expects cloud capacity or
cloud-service brokerage without making dispatch provision, claim, or bind any
cloud resource.

This is an intent contract only. It records metadata in the job file so later
broker/reconcile work can reason about cloud requirements without changing the
ordinary submit/dispatch path.

## Submit example

```sh
queue submit deploy-db \
  --uses-cloud \
  --cloud-profile gdpr-compute \
  --cloud-capability vm \
  --cloud-provider aws \
  --cloud-region eu-west-2 \
  --cloud-service compute \
  --cloud-estimated-hourly-usd 0.50 \
  --cloud-budget-usd 750 \
  --cloud-policy-ref policy://corporate/finops/cloud-budget-guardrails \
  -- ./deploy.sh
```

## Recorded job metadata

The job file may contain:

```text
USES_CLOUD=1
CLOUD_PROFILE=gdpr-compute
CLOUD_CAPABILITY=vm
CLOUD_PROVIDER=aws
CLOUD_REGION=eu-west-2
CLOUD_SERVICE=compute
CLOUD_ESTIMATED_HOURLY_USD=0.50
CLOUD_MONTHLY_BUDGET_USD=750
CLOUD_POLICY_REFERENCES=policy://corporate/finops/cloud-budget-guardrails
CLOUD_BROKER_DECISION=advisory-only
CLOUD_BROKER_BINDING=not-bound-to-dispatch
```

## Non-goals

This contract does not:

- claim a `cloud_resource` lease;
- call `cloud_provision`;
- call `cloud_infra`;
- call a live cloud provider API;
- provision, start, stop, or destroy infrastructure;
- change dispatch or worker semantics.

The next layer can use this metadata to run broker checks, policy references,
and eventual explicit resource-claim binding.
