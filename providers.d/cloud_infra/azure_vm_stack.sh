#!/usr/bin/env bash
set -euo pipefail
action="${1:-help}"
service_id="${2:-}"
lookup_json="${3:-}"
python="${QUEUEBASH_PYTHON:-/usr/bin/python3}"
helper_name="$(basename "$0" .sh)"
"$python" - "$helper_name" "$action" "$service_id" "$lookup_json" <<'PY'
import json, sys
helper, action, sid, lookup_s = sys.argv[1:5]
provider = helper.split('_', 1)[0]
lookup = json.loads(lookup_s) if lookup_s else {}
svc = lookup.get('service', {})
if action.startswith('plan-'):
    decision = 'dry_run'
    reason = 'placeholder_lifecycle_plan_no_live_mutation'
    fail_closed = False
    code = 0
else:
    decision = 'deny'
    reason = 'platform_helper_contract_placeholder_only'
    fail_closed = True
    code = 4
print(json.dumps({
  "schema":"queuebash.cloud_infra.action.v1",
  "provider": provider,
  "helper": helper,
  "service_id": svc.get('id', sid),
  "action": action,
  "decision": decision,
  "reason": reason,
  "registry_checked": bool(lookup.get('registry_checked')),
  "live": False,
  "mutated": False,
  "planned_only": action.startswith('plan-'),
  "fail_closed": fail_closed,
  "commands": ["provider-specific lifecycle helper contract placeholder", "no live cloud mutation in default path"],
  "remediation_hint":"Implement a provider-specific live helper behind policy gates before enabling mutation."
}, sort_keys=True))
sys.exit(code)
PY
