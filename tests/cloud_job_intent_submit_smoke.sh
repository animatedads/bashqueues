#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_ROOT
QUEUEBASH_ROOT="$(mktemp -d)"
cleanup(){ rm -rf "$QUEUEBASH_ROOT"; }
trap cleanup EXIT
source ./queuebash.sh
out="$(queue --dryrun submit cloudjob --uses-cloud --cloud-profile gdpr-compute --cloud-capability vm --cloud-provider aws --cloud-region eu-west-2 --cloud-service compute -- /bin/echo ok)"
[[ "$out" == *"uses-cloud: yes"* ]] || { echo "missing dryrun uses-cloud output" >&2; exit 1; }
[[ "$out" == *"cloud-profile: gdpr-compute"* ]] || { echo "missing dryrun cloud profile" >&2; exit 1; }
queue submit cloudjob --uses-cloud --cloud-profile gdpr-compute --cloud-capability vm --cloud-provider aws --cloud-region eu-west-2 --cloud-service compute --cloud-estimated-hourly-usd 0.50 --cloud-budget-usd 750 --cloud-policy-ref policy://corporate/finops -- /bin/echo ok >/tmp/qb-cloud-intent-submit.out
job="$(find "$QUEUEBASH_ROOT/pending" -name '*.job' | head -1)"
[[ -n "$job" && -f "$job" ]] || { echo "job file missing" >&2; exit 1; }
grep -q '^USES_CLOUD=1$' "$job" || { echo "USES_CLOUD missing" >&2; exit 1; }
grep -q '^CLOUD_PROFILE=gdpr-compute$' "$job" || { echo "CLOUD_PROFILE missing" >&2; exit 1; }
grep -q '^CLOUD_CAPABILITY=vm$' "$job" || { echo "CLOUD_CAPABILITY missing" >&2; exit 1; }
grep -q '^CLOUD_PROVIDER=aws$' "$job" || { echo "CLOUD_PROVIDER missing" >&2; exit 1; }
grep -q '^CLOUD_BROKER_DECISION=advisory-only$' "$job" || { echo "advisory decision missing" >&2; exit 1; }
grep -q '^CLOUD_BROKER_BINDING=not-bound-to-dispatch$' "$job" || { echo "binding guard missing" >&2; exit 1; }
echo PASS
