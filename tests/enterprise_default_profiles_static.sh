#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
has_any(){ local file="$1"; shift; local pat; for pat in "$@"; do grep -q "$pat" "$file" && return 0; done; return 1; }

profiles=(
  small-team-dev-default
  government-project-test-default
  hospital-live-readonly-default
  hospital-live-approved-maintenance-default
)
for profile in "${profiles[@]}"; do
  file="policies.d/enterprise/${profile}.env.example"
  [[ -f "$file" ]] || fail "missing enterprise profile $file"
  grep -q 'QUEUEBASH_ALLOWED_ACTIONS=' "$file" || fail "$profile missing allowed actions"
  grep -q 'QUEUEBASH_BLOCKED_ACTIONS=' "$file" || fail "$profile missing blocked actions"
  grep -q 'QUEUEBASH_APPROVAL_REQUIRED_ACTIONS=' "$file" || fail "$profile missing approval-required actions"
  has_any "$file" 'QUEUEBASH_LOG_LOCATION=' 'QUEUEBASH_LOG_ROOT=' || fail "$profile missing log location/root"
  has_any "$file" 'QUEUEBASH_SECRET_LOCATION=' 'QUEUEBASH_SECRET_ROOT=' || fail "$profile missing secret location/root"
  grep -q 'QUEUEBASH_VERIFICATION_COMMAND=' "$file" || fail "$profile missing verification command"
done

[[ -f docs/REGULATED_SERVICE_RUNBOOK.md ]] || fail 'regulated service runbook missing'
grep -q 'not accepted for general live execution' docs/REGULATED_SERVICE_RUNBOOK.md || fail 'runbook missing live non-clearance language'
grep -q '/etc/queuebash/policies.d' docs/REGULATED_SERVICE_RUNBOOK.md || fail 'runbook missing canonical policy root'
grep -q 'Emergency break-glass' docs/REGULATED_SERVICE_RUNBOOK.md || fail 'runbook missing emergency break-glass section'
grep -q 'Staged rollout' docs/REGULATED_SERVICE_RUNBOOK.md || fail 'runbook missing staged rollout section'

echo '[PASS] enterprise default profiles and regulated-service runbook are present'
