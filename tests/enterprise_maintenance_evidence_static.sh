#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
[[ -f docs/APPROVED_MAINTENANCE_EVIDENCE_CONTRACT.md ]] || fail 'maintenance evidence contract doc missing'
[[ -x providers.d/enterprise/maintenance_evidence_verify.sh ]] || fail 'maintenance evidence verifier missing or not executable'
[[ -f schemas/enterprise/approved_maintenance_request.example.json ]] || fail 'request schema example missing'
[[ -f schemas/enterprise/approved_maintenance_decision.allowed.example.json ]] || fail 'allowed decision schema example missing'
[[ -f schemas/enterprise/approved_maintenance_decision.blocked.example.json ]] || fail 'blocked decision schema example missing'
grep -q 'queuebash.enterprise_maintenance_evidence_request.v1' docs/APPROVED_MAINTENANCE_EVIDENCE_CONTRACT.md || fail 'doc missing request schema'
grep -q 'queuebash.enterprise_maintenance_evidence_decision.v1' docs/APPROVED_MAINTENANCE_EVIDENCE_CONTRACT.md || fail 'doc missing decision schema'
grep -q 'live_clearance_granted: false' docs/APPROVED_MAINTENANCE_EVIDENCE_CONTRACT.md || fail 'doc must deny broad live clearance'
grep -q 'secret_env_allowed = false' docs/APPROVED_MAINTENANCE_EVIDENCE_CONTRACT.md || fail 'doc missing secret env denial'
grep -q '/etc/queuebash/policies.d' docs/APPROVED_MAINTENANCE_EVIDENCE_CONTRACT.md || fail 'doc missing canonical policy root'
grep -q 'does not execute commands' docs/APPROVED_MAINTENANCE_EVIDENCE_CONTRACT.md || fail 'doc missing no execution boundary'
grep -q 'does not run' providers.d/enterprise/maintenance_evidence_verify.sh || fail 'verifier missing fixture-only/no-run wording'
grep -q 'system_modified.*False' providers.d/enterprise/maintenance_evidence_verify.sh || fail 'verifier must report system_modified false'
grep -q 'live_clearance_granted.*False' providers.d/enterprise/maintenance_evidence_verify.sh || fail 'verifier must report live_clearance_granted false'
! grep -R "secret_value[[:space:]]*[:=]" docs/APPROVED_MAINTENANCE_EVIDENCE_CONTRACT.md schemas/enterprise/approved_maintenance_*.json tests/fixtures/enterprise/maintenance_evidence providers.d/enterprise/maintenance_evidence_verify.sh >/tmp/qb_maint_secret_grep.$$ || { cat /tmp/qb_maint_secret_grep.$$ >&2; rm -f /tmp/qb_maint_secret_grep.$$; fail 'raw secret_value field detected'; }
rm -f /tmp/qb_maint_secret_grep.$$
echo '[PASS] enterprise_maintenance_evidence_static'
