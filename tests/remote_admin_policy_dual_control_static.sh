#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
helper=providers.d/remote_admin/remote_admin_policy.py
[[ -f "$helper" ]] || { echo "missing remote_admin_policy.py" >&2; exit 1; }
grep -q 'remote-admin.plan.approve' "$helper"
grep -q 'plan_requires_dual_control' "$helper"
grep -q 'plan_has_valid_dual_approval' "$helper"
grep -q 'plan_approve.v1' "$helper"
grep -q 'acl_write_plan_requires_distinct_remote_admin_plan_approve' "$helper"
grep -q 'distinct from the plan creator' "$helper"
grep -q 'plan approve PLAN_FILE' "$helper"
echo "remote_admin_policy_dual_control_static: ok"
