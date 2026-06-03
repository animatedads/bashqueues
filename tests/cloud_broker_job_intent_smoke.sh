#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

job="$(mktemp)"
plain="$(mktemp)"
trap 'rm -f "$job" "$plain"' EXIT
cat >"$job" <<'JOB'
JOB_ID=cloud-intent-smoke
JOB_NAME=cloud-intent-smoke
USES_CLOUD=1
CLOUD_PROFILE=gdpr-compute
CLOUD_CAPABILITY=vm
CLOUD_PROVIDER=aws
CLOUD_REGION=eu-west-2
CLOUD_SERVICE=compute
CLOUD_ESTIMATED_HOURLY_USD=0.50
CLOUD_MONTHLY_BUDGET_USD=750
CLOUD_POLICY_REFERENCES=policy://corporate/finops/cloud-budget-guardrails
JOB
cat >"$plain" <<'JOB'
JOB_ID=plain-intent-smoke
JOB_NAME=plain-intent-smoke
JOB

broker="$(providers.d/cloud_broker/cloud_broker_provider.sh job-intent --job-file "$job" --json)"
printf '%s\n' "$broker" | python3 -S -m json.tool >/dev/null
printf '%s\n' "$broker" | python3 -S -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cloud_broker.job_intent.v1"; assert o["uses_cloud"] is True; assert o["dispatch_binding"] is False; assert o["cloud_resource_claim"] is False; assert o["cloud_provision_call"] is False; assert o["cloud_infra_call"] is False; assert o["broker_explain"]["schema"]=="queuebash.cloud_broker.explain.v1"'

plain_json="$(providers.d/cloud_broker/cloud_broker_provider.sh job-intent --job-file "$plain" --json)"
printf '%s\n' "$plain_json" | python3 -S -c 'import json,sys; o=json.load(sys.stdin); assert o["schema"]=="queuebash.cloud_broker.job_intent.v1"; assert o["decision"]=="not_applicable"; assert o["uses_cloud"] is False'

echo "cloud broker job intent smoke: ok"
