#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
PROVIDER="providers.d/cloud_provision/cloud_provision.sh"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
for t in aws-ec2-gdpr oci-vm-gdpr azure-vm-gdpr gcp-compute-gdpr ibm-vpc-gdpr; do
  out="$($PROVIDER lifecycle-plan "$t" --json)"
  echo "$out" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_provision.lifecycle_plan.v1"; assert d["decision"]=="dry_run"; assert d["live"] is False; assert d["mutated"] is False; assert d["cloud_infra_action"]["schema"]=="queuebash.cloud_infra.action.v1"; assert d["cloud_infra_action"]["mutated"] is False; assert d["cloud_infra_action"]["live"] is False; assert d["resource_record_preview"]["schema"]=="queuebash.cloud_resource.v1"'
  prev="$($PROVIDER registry-preview "$t" --json)"
  echo "$prev" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["schema"]=="queuebash.cloud_provision.registry_preview.v1"; assert d["registry_write"] is False; assert d["mutated"] is False; assert d["resource_record"]["schema"]=="queuebash.cloud_resource.v1"; assert d["resource_record"]["lifecycle_state"]=="planned"; assert d["resource_record"]["provenance"]["handoff_mode"]=="preview-only"'
done
QUEUEBASH_CLOUD_INFRA_LIVE=1 $PROVIDER lifecycle-plan aws-ec2-gdpr --json | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["mutated"] is False and d["live"] is False and d["cloud_infra_action"]["mutated"] is False'
echo '[PASS] cloud provision lifecycle dry-run smoke checks pass'
