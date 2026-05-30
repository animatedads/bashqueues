#!/usr/bin/env bash
set -euo pipefail
action="${1:-help}"
service_id="${2:-}"
lookup_json="${3:-}"
python="${QUEUEBASH_PYTHON:-/usr/bin/python3}"
"$python" - "scaleway" "scaleway_instance" "eu_sovereign" "Scaleway Instance" "$action" "$service_id" "$lookup_json" <<'PYHELPER'
import json, sys
provider, helper, family, label, action, sid, lookup_s = sys.argv[1:8]
try:
    lookup = json.loads(lookup_s) if lookup_s else {}
except Exception:
    lookup = {}
svc = lookup.get('service', {})
plan = action.startswith('plan-')
status = action == 'status'
if plan or status:
    decision = 'dry_run'
    reason = 'lifecycle_helper_fixture_first_no_live_mutation'
    fail_closed = False
    code = 0
else:
    decision = 'deny'
    reason = 'live_mutation_not_implemented_for_provider_family'
    fail_closed = True
    code = 4
out = {
  'schema': 'queuebash.cloud_infra.action.v1',
  'provider': provider,
  'provider_family': family,
  'helper': helper,
  'service_id': svc.get('id', sid),
  'action': action,
  'decision': decision,
  'reason': reason,
  'registry_checked': bool(lookup.get('registry_checked')),
  'live': False,
  'mutated': False,
  'planned_only': plan,
  'fail_closed': fail_closed,
  'label': label,
  'region': svc.get('region'),
  'queue_class': svc.get('queue_class'),
  'legal': svc.get('legal', {}),
  'cost': svc.get('cost', {}),
  'commands': [
    'provider-family lifecycle helper contract placeholder',
    'dry-run/status evidence only',
    'no live cloud mutation in default path'
  ],
  'remediation_hint': 'Add audited provider-specific live implementation behind approval/live gates before enabling mutation.'
}
print(json.dumps(out, sort_keys=True))
sys.exit(code)
PYHELPER
