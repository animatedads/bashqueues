#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
helper="providers.d/enterprise/maintenance_evidence_verify.sh"
fixture_dir="tests/fixtures/enterprise/maintenance_evidence"
valid_out="$($helper --request "$fixture_dir/valid_approved_maintenance.json" --json)"
[[ "$valid_out" == *'"schema": "queuebash.enterprise_maintenance_evidence_decision.v1"'* ]] || { echo 'valid output missing schema' >&2; exit 1; }
[[ "$valid_out" == *'"status": "ok"'* ]] || { echo 'valid output not ok' >&2; exit 1; }
[[ "$valid_out" == *'"live_clearance_granted": false'* ]] || { echo 'valid output grants live clearance' >&2; exit 1; }
[[ "$valid_out" == *'"system_modified": false'* ]] || { echo 'valid output modifies system' >&2; exit 1; }
for f in missing_rollback.json secret_env_requested.json wrong_policy_root.json broad_live_clearance.json single_approver.json; do
  if out="$($helper --request "$fixture_dir/$f" --json 2>/tmp/qb_maint_err.$$)"; then
    echo "expected $f to block" >&2; rm -f /tmp/qb_maint_err.$$; exit 1
  fi
  [[ "$out" == *'"status": "blocked"'* ]] || { echo "$f did not report blocked" >&2; rm -f /tmp/qb_maint_err.$$; exit 1; }
  [[ "$out" == *'"ok": false'* ]] || { echo "$f did not report ok false" >&2; rm -f /tmp/qb_maint_err.$$; exit 1; }
  [[ "$out" == *'"live_clearance_granted": false'* ]] || { echo "$f grants live clearance" >&2; rm -f /tmp/qb_maint_err.$$; exit 1; }
  [[ "$out" == *'"system_modified": false'* ]] || { echo "$f modifies system" >&2; rm -f /tmp/qb_maint_err.$$; exit 1; }
  [[ "$out" == *'"failures": ['* ]] || { echo "$f missing failures" >&2; rm -f /tmp/qb_maint_err.$$; exit 1; }
  rm -f /tmp/qb_maint_err.$$
done
echo '[PASS] enterprise_maintenance_evidence_smoke'
