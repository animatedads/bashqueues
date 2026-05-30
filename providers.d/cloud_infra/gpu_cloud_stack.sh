#!/usr/bin/env bash
set -euo pipefail
action="${1:-help}"
service_id="${2:-}"
lookup_json="${3:-}"
python="${QUEUEBASH_PYTHON:-/usr/bin/python3}"
"$python" - "$action" "$service_id" "$lookup_json" <<'PYHELPER'
import json, sys
action, sid, lookup_s = sys.argv[1:4]
try:
    lookup = json.loads(lookup_s) if lookup_s else {}
except Exception:
    lookup = {}
svc = lookup.get('service', {})
plan = action.startswith('plan-')
status = action == 'status'
if plan or status:
    decision = 'dry_run'
    reason = 'gpu_lifecycle_helper_fixture_first_no_live_mutation'
    fail_closed = False
    code = 0
else:
    decision = 'deny'
    reason = 'live_gpu_mutation_not_implemented'
    fail_closed = True
    code = 4
out = {
  'schema': 'queuebash.cloud_infra.action.v1',
  'provider': svc.get('provider', 'gpu-cloud'),
  'provider_family': 'gpu-cloud',
  'helper': 'gpu_cloud',
  'service_id': svc.get('id', sid),
  'action': action,
  'decision': decision,
  'reason': reason,
  'registry_checked': bool(lookup.get('registry_checked')),
  'live': False,
  'mutated': False,
  'planned_only': plan,
  'fail_closed': fail_closed,
  'region': svc.get('region'),
  'queue_class': svc.get('queue_class'),
  'accelerator': svc.get('accelerator', {}),
  'legal': svc.get('legal', {}),
  'cost': svc.get('cost', {}),
  'commands': [
    'gpu provider lifecycle helper contract placeholder',
    'dry-run/status evidence only',
    'no live GPU cloud or Kubernetes mutation in default path'
  ],
  'remediation_hint': 'Add audited provider-specific live GPU implementation behind approval/live gates before enabling mutation.'
}
print(json.dumps(out, sort_keys=True))
sys.exit(code)
PYHELPER
