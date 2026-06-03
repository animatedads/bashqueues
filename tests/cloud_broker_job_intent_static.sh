#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

grep -q 'queue cloud broker job-intent JOB|--job-file FILE' queuebash.sh
grep -q 'job-intent|intent' providers.d/cloud_broker/cloud_broker_provider.sh
grep -q 'queuebash.cloud_broker.job_intent.v1' providers.d/cloud_broker/cloud_broker_provider.sh
grep -q 'cloud_resource_claim.*False\|cloud_resource_claim.*false' providers.d/cloud_broker/cloud_broker_provider.sh
grep -q 'cloud_provision_call.*False\|cloud_provision_call.*false' providers.d/cloud_broker/cloud_broker_provider.sh
grep -q 'cloud_infra_call.*False\|cloud_infra_call.*false' providers.d/cloud_broker/cloud_broker_provider.sh

echo "cloud broker job intent static: ok"
