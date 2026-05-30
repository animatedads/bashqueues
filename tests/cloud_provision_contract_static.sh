#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
require_file(){ [[ -f "$1" ]] || fail "missing $1"; }
require_grep(){ grep -q "$1" "$2" || fail "missing pattern $1 in $2"; }

for f in \
  docs/CLOUD_PROVISIONING_CONTRACT.md \
  docs/CLOUD_PROVISIONING_SECURITY_MODEL.md \
  docs/CLOUD_PROVISIONING_WORKFLOWS.md \
  docs/CLOUD_PROVISIONING_LIFECYCLE_DRY_RUN.md \
  docs/CLOUD_PROVISIONING_REGISTRY_HANDOFF.md \
  providers.d/cloud_provision/cloud_provision.sh \
  policies.d/cloud-provision/default.env.example \
  policies.d/cloud-provision/approval-policy.example.json \
  policies.d/cloud-provision/templates.example.json \
  examples/cloud-provision/oci-vm-gdpr-plan.example.json \
  examples/cloud-provision/aws-ec2-gdpr-plan.example.json \
  examples/cloud-provision/azure-vm-gdpr-plan.example.json \
  examples/cloud-provision/gcp-compute-gdpr-plan.example.json \
  examples/cloud-provision/ibm-vpc-gdpr-plan.example.json; do
  require_file "$f"
done

bash -n providers.d/cloud_provision/cloud_provision.sh || fail 'cloud_provision bash -n failed'
require_grep 'queuebash.cloud_provision.plan.v1' providers.d/cloud_provision/cloud_provision.sh
require_grep 'contract/dry-run only' docs/CLOUD_PROVISIONING_CONTRACT.md
require_grep 'Provider credentials alone must never be sufficient' docs/CLOUD_PROVISIONING_SECURITY_MODEL.md
require_grep 'Queue dispatch must not directly call cloud provider lifecycle operations' docs/CLOUD_PROVISIONING_CONTRACT.md
require_grep 'QUEUEBASH_CLOUD_PROVISION_STORE_SECRETS=0' policies.d/cloud-provision/default.env.example
require_grep 'lifecycle-plan' providers.d/cloud_provision/cloud_provision.sh
require_grep 'registry-preview' providers.d/cloud_provision/cloud_provision.sh
require_grep 'queuebash.cloud_provision.lifecycle_plan.v1' providers.d/cloud_provision/cloud_provision.sh
require_grep 'queuebash.cloud_provision.registry_preview.v1' providers.d/cloud_provision/cloud_provision.sh

if grep -R 'run-instances\|oci compute instance launch\|az vm create\|gcloud compute instances create\|ibmcloud is instance-create' providers.d/cloud_provision >/dev/null 2>&1; then
  fail 'cloud_provision provider contains live create command text'
fi
if grep -R 'queue cloud-provision\|_queue_cloud_provision' queuebash.sh providers.d/cloud_provision >/dev/null 2>&1; then
  fail 'cloud_provision unexpectedly wired into queuebash dispatcher'
fi

echo '[PASS] cloud provision contract static checks pass'
