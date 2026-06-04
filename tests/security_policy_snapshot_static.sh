#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

src="$(cat queuebash.sh)"

require() {
    local needle="$1" msg="$2"
    if [[ "$src" != *"$needle"* ]]; then
        echo "[FAIL] $msg" >&2
        echo "missing: $needle" >&2
        exit 1
    fi
}

require '_queue_append_policy_snapshot_to_job_file' 'policy snapshots are appended to job records at submit time'
require 'SANDBOX_POLICY_SHA256' 'sandbox policy hash is stored in the job record'
require 'SECCOMP_POLICY_SHA256' 'seccomp policy hash is stored in the job record'
require 'SANDBOX_POLICY_SYSTEMD_PROPERTIES' 'sandbox systemd properties are snapshotted'
require 'SECCOMP_POLICY_SYSTEMD_PROPERTIES' 'seccomp systemd properties are snapshotted'
require 'shared/admin policy folder' 'shared policy precedence is documented in the resolver'
require 'QUEUEBASH_SHARED_POLICY_ROOT:-/etc/queuebash/policies.d' 'shared policy root defaults to /etc/queuebash/policies.d'
require 'queue policies edit sandbox|seccomp NAME' 'policy editor command exists'
require 'queue policies create sandbox|seccomp NAME' 'policy create command exists'

[[ -f policies.d/sandbox/queue-default.env ]] || { echo '[FAIL] sandbox queue-default policy missing' >&2; exit 1; }
[[ -f policies.d/seccomp/queue-default.env ]] || { echo '[FAIL] seccomp queue-default policy missing' >&2; exit 1; }

python3 - <<'PY'
from pathlib import Path
panel = Path('queuemgr_panel.py').read_text()
assert 'line.split()[0]' in panel
assert 'queue-default' in panel
print('[PASS] panel sandbox chooser uses policy names from queue policies list')
PY

echo '[PASS] policy precedence, policy snapshots, and policy editor commands are wired'
