#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
provider="$root/providers.d/cloud_provision/cloud_provision.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Missing approval facts must fail closed.
if "$provider" approval-request aws-ec2-gdpr --json >"$tmp/missing.json" 2>/dev/null; then
  echo "approval-request without evidence unexpectedly succeeded" >&2
  exit 1
fi
python3 - "$tmp/missing.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['schema']=='queuebash.cloud_provision.approval_gate.v1'
assert p['decision']=='deny'
assert p['mutated'] is False and p['live'] is False and p['cloud_mutation'] is False
PY

# Complete customer-data approval should allow.
"$provider" approval-request aws-ec2-gdpr \
  --change-ticket CHG-12345 \
  --reason "approved customer database migration window" \
  --authority data-owner \
  --audit-sink jsonl \
  --data-protection-review \
  --json >"$tmp/approval.json"
python3 - "$tmp/approval.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['schema']=='queuebash.cloud_provision.approval_gate.v1'
assert p['decision']=='allow', p
assert p['mutated'] is False and p['live'] is False and p['cloud_mutation'] is False
PY

# Live gate without explicit live flag must deny even with approval.
if "$provider" live-gate aws-ec2-gdpr --approval "$tmp/approval.json" --json >"$tmp/live_missing.json" 2>/dev/null; then
  echo "live-gate without --live-enabled unexpectedly succeeded" >&2
  exit 1
fi
python3 - "$tmp/live_missing.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['schema']=='queuebash.cloud_provision.live_gate.v1'
assert p['decision']=='deny'
assert p['reason']=='missing_explicit_live_enabled_flag'
assert p['mutated'] is False and p['live'] is False and p['cloud_mutation'] is False
PY

# With live flag, this package still returns review because live apply is not implemented.
"$provider" live-gate aws-ec2-gdpr --approval "$tmp/approval.json" --live-enabled --json >"$tmp/live_gate.json"
python3 - "$tmp/live_gate.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['schema']=='queuebash.cloud_provision.live_gate.v1'
assert p['decision']=='review', p
assert p['reason']=='contract_only_no_live_apply_implemented'
assert p['live_apply_available'] is False
assert p['queue_dispatch_path'] is False
assert p['mutated'] is False and p['live'] is False and p['cloud_mutation'] is False
PY

echo PASS cloud_provision_approval_live_gate_smoke
