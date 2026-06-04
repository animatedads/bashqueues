#!/usr/bin/env bash
set -euo pipefail
usage(){ cat <<'USAGE'
Usage: providers.d/enterprise/maintenance_evidence_verify.sh --request FILE [--json]
       providers.d/enterprise/maintenance_evidence_verify.sh FILE [--json]

Fixture-only verifier for hospital approved-maintenance evidence. It reads a
bounded JSON fixture and emits redacted decision metadata only. It does not run
commands, source policy, deliver secrets, contact providers, modify systems, or
grant live clearance.
USAGE
}
request=""; json=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --request) request="${2:-}"; shift 2 ;;
    --json) json=1; shift ;;
    --help|-h) usage; exit 0 ;;
    --*) echo "maintenance_evidence_verify: unknown option: $1" >&2; exit 2 ;;
    *) if [[ -z "$request" ]]; then request="$1"; shift; else echo "maintenance_evidence_verify: extra argument: $1" >&2; exit 2; fi ;;
  esac
done
[[ -n "$request" ]] || { echo "maintenance_evidence_verify: request file required" >&2; exit 2; }
[[ -f "$request" ]] || { echo "maintenance_evidence_verify: request file missing: $request" >&2; exit 1; }
python3 - "$request" "$json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
as_json = sys.argv[2] == '1'
try:
    obj = json.loads(path.read_text())
except Exception as exc:
    print(f"maintenance_evidence_verify: invalid json: {exc}", file=sys.stderr)
    sys.exit(1)
failures = []
def get(d, *keys, default=None):
    cur = d
    for key in keys:
        if not isinstance(cur, dict) or key not in cur:
            return default
        cur = cur[key]
    return cur
schema = obj.get('schema')
profile = obj.get('profile', '')
if schema != 'queuebash.enterprise_maintenance_evidence_request.v1':
    failures.append('schema_mismatch')
if profile != 'hospital-live-approved-maintenance-default':
    failures.append('profile_not_approved_maintenance')
if not obj.get('change_ticket'):
    failures.append('missing_change_ticket')
if not obj.get('maintenance_class'):
    failures.append('missing_maintenance_class')
if not obj.get('purpose'):
    failures.append('missing_purpose')
if not get(obj, 'maintenance_window', 'start') or not get(obj, 'maintenance_window', 'end'):
    failures.append('missing_maintenance_window')
if not isinstance(obj.get('requested_actions'), list) or not obj.get('requested_actions'):
    failures.append('missing_requested_actions')
if get(obj, 'approval', 'dual_control') is not True:
    failures.append('dual_control_required')
if get(obj, 'approval', 'signed_approval') is not True:
    failures.append('signed_approval_required')
approvers = get(obj, 'approval', 'approvers', default=[])
if not isinstance(approvers, list) or len([a for a in approvers if a]) < 2:
    failures.append('two_approvers_required')
rollback_ok = bool(get(obj, 'rollback', 'procedure')) or bool(get(obj, 'rollback', 'command'))
if not rollback_ok:
    failures.append('rollback_evidence_required')
if not get(obj, 'audit', 'audit_path'):
    failures.append('audit_path_required')
if get(obj, 'policy', 'policy_root') != '/etc/queuebash/policies.d':
    failures.append('canonical_policy_root_required')
if get(obj, 'secrets', 'secret_env_allowed') is not False:
    failures.append('secret_env_must_be_denied')
if get(obj, 'secrets', 'secret_value_json_allowed') is not False:
    failures.append('secret_value_json_must_be_denied')
if get(obj, 'ai', 'external_provider_allowed') is not False:
    failures.append('external_ai_must_be_denied_by_default')
if obj.get('live_clearance_requested') is not False:
    failures.append('broad_live_clearance_not_allowed')
checks = {
    'change_ticket': bool(obj.get('change_ticket')),
    'dual_control': get(obj, 'approval', 'dual_control') is True,
    'signed_approval': get(obj, 'approval', 'signed_approval') is True,
    'rollback_evidence': rollback_ok,
    'audit_path': bool(get(obj, 'audit', 'audit_path')),
    'canonical_policy_root': get(obj, 'policy', 'policy_root') == '/etc/queuebash/policies.d',
    'secret_env_denied': get(obj, 'secrets', 'secret_env_allowed') is False,
    'secret_json_denied': get(obj, 'secrets', 'secret_value_json_allowed') is False,
    'external_ai_denied': get(obj, 'ai', 'external_provider_allowed') is False,
}
status = 'ok' if not failures else 'blocked'
decision = {
    'schema': 'queuebash.enterprise_maintenance_evidence_decision.v1',
    'status': status,
    'ok': status == 'ok',
    'profile': profile,
    'mode': 'fixture-only',
    'live_clearance_granted': False,
    'system_modified': False,
    'request_file': str(path),
    'checks': checks,
    'failures': failures,
}
if as_json:
    print(json.dumps(decision, sort_keys=True))
else:
    print(f"status\t{status}")
    print(f"profile\t{profile}")
    for failure in failures:
        print(f"failure\t{failure}")
sys.exit(0 if status == 'ok' else 1)
PY
