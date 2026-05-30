#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -x providers.d/remote_admin/remote_admin_policy.sh ]]
[[ -x providers.d/remote_admin/remote_admin_policy.py ]]

grep -q '_queue_remote_admin_command' queuebash.sh
grep -q 'remote-admin|remote_admin|remote-admin-policy' queuebash.sh
grep -q 'remote-admin.acl.write' docs/REMOTE_ADMIN_POLICY_COMMANDS.md
grep -q 'No ACL pass means no read/write path' docs/REMOTE_ADMIN_POLICY_COMMANDS.md

grep -q 'remote-admin.acl.write' providers.d/remote_admin/remote_admin_policy.py
grep -q 'secret_fingerprint' providers.d/remote_admin/remote_admin_policy.py

echo "remote_admin_policy_commands_static: ok"
