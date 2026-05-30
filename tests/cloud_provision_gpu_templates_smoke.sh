#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m json.tool policies.d/cloud-provision/templates.example.json >/dev/null
out="$(providers.d/cloud_provision/cloud_provision.sh plan gpu-coreweave-a100-training --json)"
printf '%s\n' "$out" | grep -q '"schema": "queuebash.cloud_provision.plan.v1"'
printf '%s\n' "$out" | grep -q '"decision": "allow"'
printf '%s\n' "$out" | grep -q '"provider": "gpu-cloud"'
life="$(providers.d/cloud_provision/cloud_provision.sh lifecycle-plan gpu-coreweave-a100-training --json)"
printf '%s\n' "$life" | grep -q '"schema": "queuebash.cloud_provision.lifecycle_plan.v1"'
printf '%s\n' "$life" | grep -q '"decision": "dry_run"'
printf '%s\n' "$life" | grep -q '"mutated": false'
prev="$(providers.d/cloud_provision/cloud_provision.sh registry-preview gpu-lambda-h100-training --json)"
printf '%s\n' "$prev" | grep -q 'queuebash.cloud_provision.registry_preview.v1'
printf '%s\n' "$prev" | grep -q 'gpu-lambda-h100-training'
if providers.d/cloud_provision/cloud_provision.sh plan bad-gpu-cost-breach --json >/tmp/qb_gpu_bad.json; then
  true
fi
grep -q '"decision": "deny"' /tmp/qb_gpu_bad.json
grep -q 'cost_ceiling_breach' /tmp/qb_gpu_bad.json
