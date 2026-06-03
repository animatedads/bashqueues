#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

require_file(){ [[ -f "$1" ]] || { echo "missing $1" >&2; exit 1; }; }
require_grep(){ grep -R "$1" "$2" >/dev/null || { echo "missing pattern $1 in $2" >&2; exit 1; }; }

require_file docs/CLOUD_INFRASTRUCTURE_HELPER_PARITY_EU_APAC.md
require_file providers.d/cloud_infra/ovh_vm_stack.sh
require_file providers.d/cloud_infra/scaleway_instance_stack.sh
require_file providers.d/cloud_infra/hetzner_cloud_stack.sh
require_file providers.d/cloud_infra/otc_ecs_stack.sh
require_file providers.d/cloud_infra/alibaba_ecs_stack.sh
require_file providers.d/cloud_infra/tencent_cvm_stack.sh
require_file providers.d/cloud_infra/huawei_ecs_stack.sh

require_grep 'ovh_vm)' providers.d/cloud_infra/cloud_infra.sh
require_grep 'scaleway_instance)' providers.d/cloud_infra/cloud_infra.sh
require_grep 'hetzner_cloud)' providers.d/cloud_infra/cloud_infra.sh
require_grep 'otc_ecs)' providers.d/cloud_infra/cloud_infra.sh
require_grep 'alibaba_ecs)' providers.d/cloud_infra/cloud_infra.sh
require_grep 'tencent_cvm)' providers.d/cloud_infra/cloud_infra.sh
require_grep 'huawei_ecs)' providers.d/cloud_infra/cloud_infra.sh

require_grep 'ovh-gdpr-vm' policies.d/cloud-infra/registry.example.json
require_grep 'scaleway-gdpr-instance' policies.d/cloud-infra/registry.example.json
require_grep 'hetzner-gdpr-cloud' policies.d/cloud-infra/registry.example.json
require_grep 'otc-gdpr-ecs' policies.d/cloud-infra/registry.example.json
require_grep 'alibaba-export-review-ecs' policies.d/cloud-infra/registry.example.json
require_grep 'tencent-export-review-cvm' policies.d/cloud-infra/registry.example.json
require_grep 'huawei-export-review-ecs' policies.d/cloud-infra/registry.example.json

if grep -R 'queue cloud-infra\|queue cloud-resources\|_queue_cloud' queuebash.sh providers.d/cloud_infra docs/CLOUD_INFRASTRUCTURE_HELPER_PARITY_EU_APAC.md >/dev/null; then
  echo 'cloud infra parity must not wire a queue dispatcher' >&2
  exit 1
fi

echo 'cloud_infra_eu_apac_helper_parity_static: PASS'
