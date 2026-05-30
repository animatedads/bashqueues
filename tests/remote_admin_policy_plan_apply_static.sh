#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

helper=providers.d/remote_admin/remote_admin_policy.py
[[ -f "$helper" ]] || { echo "missing remote_admin_policy.py" >&2; exit 1; }

grep -q 'remote-admin.plan.write' "$helper"
grep -q 'remote-admin.plan.apply' "$helper"
grep -q 'remote-admin.rollback.apply' "$helper"
grep -q 'plan.v1' "$helper"
grep -q 'def cmd_plan' "$helper"
grep -q 'def cmd_apply' "$helper"
grep -q 'def cmd_rollback' "$helper"
grep -q 'plan_operation_acl' "$helper"
grep -q 'remote-admin.acl.write' "$helper"

echo "remote_admin_policy_plan_apply_static: ok"
