#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
provider="$root/providers.d/cloud_provision/cloud_provision.sh"
doc="$root/docs/CLOUD_PROVISIONING_APPROVAL_LIVE_GATES.md"
policy="$root/policies.d/cloud-provision/approval-policy.example.json"

[[ -x "$provider" || -f "$provider" ]]
grep -q 'approval-request' "$provider"
grep -q 'live-gate' "$provider"
grep -q 'queuebash.cloud_provision.approval_gate.v1' "$provider"
grep -q 'queuebash.cloud_provision.live_gate.v1' "$provider"
grep -q 'provider_credentials_are_not_authority' "$provider"
grep -q 'contract_only_no_live_apply_implemented' "$provider"

grep -q 'Cloud Provisioning Approval and Live Gate Contract' "$doc"
grep -q 'Provider credentials alone are never authority' "$doc"
grep -q 'contract_only_no_live_apply_implemented' "$doc"

grep -q '"approval"' "$policy"
grep -q '"live_gate"' "$policy"
grep -q '"provider_credentials_are_not_authority": true' "$policy"

echo PASS cloud_provision_approval_live_gate_static
