#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

grep -q '^_queue_remote_admin_helper_path()' queuebash.sh
grep -q '^_queue_remote_admin_command()' queuebash.sh
grep -q 'remote-admin|remote_admin|remote-admin-policy)' queuebash.sh

test -x providers.d/remote_admin/remote_admin_policy.sh

grep -q 'providers\.d' install-system.sh
grep -q 'for dir in assets.d caps.d reporters.d classes envs.d policies.d docs bin systemd tests resources.d providers.d schemas fixtures contracts; do' install-system.sh
grep -q 'remote-admin provider helper' install-system.sh

bash -n queuebash.sh
bash -n install-system.sh
bash -n providers.d/remote_admin/remote_admin_policy.sh
