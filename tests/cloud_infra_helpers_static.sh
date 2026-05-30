#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

require_file(){ [[ -f "$1" ]] || { echo "missing $1" >&2; exit 1; }; }
require_grep(){ grep -R "$1" "$2" >/dev/null || { echo "missing pattern $1 in $2" >&2; exit 1; }; }
require_absent(){ [[ ! -e "$1" ]] || { echo "unexpected $1" >&2; exit 1; }; }

require_file docs/CLOUD_INFRASTRUCTURE_HELPERS.md
require_file providers.d/cloud_infra/cloud_infra.sh
require_file providers.d/cloud_infra/oci_free_stack.sh
require_file providers.d/cloud_infra/ibm_vpc_stack.sh
require_file providers.d/cloud_infra/aws_ec2_stack.sh
require_file providers.d/cloud_infra/azure_vm_stack.sh
require_file providers.d/cloud_infra/gcp_compute_stack.sh
require_file policies.d/cloud-infra/registry.example.json
require_file tests/fixtures/cloud_infra/registry.json
require_file tests/fixtures/cloud_infra/registry_with_instance.json

require_grep 'queuebash.cloud_infra.registry.v1' docs/CLOUD_INFRASTRUCTURE_HELPERS.md
require_grep 'queuebash.cloud_infra.action.v1' docs/CLOUD_INFRASTRUCTURE_HELPERS.md
require_grep 'QUEUEBASH_CLOUD_INFRA_LIVE=1' docs/CLOUD_INFRASTRUCTURE_HELPERS.md
require_grep 'registry -> provider helper -> normalized JSON decision/output' docs/CLOUD_INFRASTRUCTURE_HELPERS.md
require_grep 'Do not run live cloud mutation by default' docs/CLOUD_INFRASTRUCTURE_HELPERS.md
require_grep 'Do not store cloud secrets' docs/CLOUD_INFRASTRUCTURE_HELPERS.md
require_grep 'OCI Always Free' docs/CLOUD_INFRASTRUCTURE_HELPERS.md
require_grep 'deploy-oci-free.sh' docs/CLOUD_INFRASTRUCTURE_HELPERS.md
require_grep 'VM.Standard.E2.1.Micro' providers.d/cloud_infra/oci_free_stack.sh
require_grep 'compute instance action --action START' providers.d/cloud_infra/oci_free_stack.sh
require_grep 'compute instance action --action STOP' providers.d/cloud_infra/oci_free_stack.sh
require_grep 'network vcn create' providers.d/cloud_infra/oci_free_stack.sh
require_grep 'first_pub_in_oci_dir' policies.d/cloud-infra/registry.example.json
require_grep 'sovereignty' policies.d/cloud-infra/registry.example.json
require_grep 'retention_policy' policies.d/cloud-infra/registry.example.json

if grep -R 'queue cloud-infra\|queue cloud-resources\|_queue_cloud' queuebash.sh providers.d/cloud_infra docs/CLOUD_INFRASTRUCTURE_HELPERS.md >/dev/null; then
  echo 'cloud infra package must not wire a queue dispatcher yet' >&2
  exit 1
fi
require_absent assets.d/net_usage.sh
require_file caps.d/net_usage.sh

echo 'cloud_infra_helpers_static: PASS'
